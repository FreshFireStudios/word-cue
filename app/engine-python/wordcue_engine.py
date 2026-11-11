"""Word Cue detection engine - Python reference version.

This is the "answer key" for the Swift engine in
WordCueKit/Sources/WordCueKit/. Both read the SAME rule files
(books.json, numbers.json, rules.json, versification.json) and must pass the
SAME test cases (WordCueKit/Tests/WordCueKitTests/Resources/cases.json).

The Swift files mirror this one function-for-function, in the same order, so
a change here can be copied across by eye. Keep it that way.

Pipeline:  text -> tokens -> scan left to right -> Detection list
"""
import json
import os
import re

RESOURCES = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                         "..", "WordCueKit", "Sources", "WordCueKit", "Resources")

TOKEN_RE = re.compile(r"[0-9]+(?:st|nd|rd|th)?|[a-z]+(?:'[a-z]+)*|[:;,.\-–—]")
PUNCT = {":", ";", ",", ".", "-", "–", "—"}
ORDINAL_SUFFIXES = ("st", "nd", "rd", "th")


def tokenize(text):
    """Lower-cases and splits text into words, numbers and the few
    punctuation marks that matter (: ; , . and dashes)."""
    text = text.lower().replace("’", "'").replace("‘", "'")
    return TOKEN_RE.findall(text)


class Detection:
    def __init__(self, book, chapter, verse, end_verse, start, end, confidence, kind, flags, text):
        self.book = book            # book id, e.g. "ACT"
        self.chapter = chapter      # int
        self.verse = verse          # int or None (whole chapter)
        self.end_verse = end_verse  # int or None (single verse)
        self.start = start          # index of first token
        self.end = end              # index after last token
        self.confidence = confidence
        self.kind = kind            # "explicit" or "followOn"
        self.flags = flags          # list of strings explaining the score
        self.text = text            # the words that matched

    @property
    def key(self):
        s = "%s %d" % (self.book, self.chapter)
        if self.verse is not None:
            s += ":%d" % self.verse
            if self.end_verse is not None:
                s += "-%d" % self.end_verse
        return s

    def __repr__(self):
        return "<%s %.2f %s %r>" % (self.key, self.confidence, self.kind, self.text)


class Context:
    """The last reference heard, so "verse 4" or "the next verse" can be
    resolved. `pos` is the token index where that reference ended."""
    def __init__(self, book=None, chapter=None, verse=None, pos=0):
        self.book, self.chapter, self.verse, self.pos = book, chapter, verse, pos


class Engine:
    def __init__(self, resources=RESOURCES):
        load = lambda name: json.load(open(os.path.join(resources, name), encoding="utf-8"))
        self.books = load("books.json")
        self.numbers = load("numbers.json")
        self.rules = load("rules.json")
        self.verses = load("versification.json")
        self.by_id = {b["id"]: b for b in self.books}
        self.units = self.numbers["units"]
        self.tens = self.numbers["tens"]
        self.hundred = set(self.numbers["hundred"])
        self.zero = set(self.numbers["zero"])
        self.ordinals = self.numbers["ordinals"]
        self.book_ordinals = self.numbers["bookOrdinals"]
        r = self.rules
        self.chapter_words = set(r["chapterWords"])
        self.doc_chapter_words = set(r["docChapterWords"])
        self.verse_words = set(r["verseWords"])
        self.doc_verse_words = set(r["docVerseWords"])
        self.fillers = set(r["verseNumberFillers"])
        self.range_words = set(r["rangeWords"])
        self.range_symbols = set(r["rangeSymbols"])
        self.and_words = set(r["andWords"])
        self.of_words = set(r["ofWords"])
        self.intro_words = set(r["bookIntroWords"])
        self.next_words = set(r["nextWords"])
        self.short_ok = set(r["shortAbbrChapterOnly"])
        self.limits = r["limits"]
        self.conf = r["confidence"]
        self.quote_rules = r["quotes"]
        self.ignored_books = set()      # book ids the church never wants suggested (Settings > Filters)
        self.ignored_phrases = []       # token lists; a match touching one of these is dropped
        self._quote_index = None        # built the first time quoted-scripture matching is used
        # name index: first word -> list of (words, family, kind)
        # A "family" is the list of books sharing a name: "john" -> JHN, 1JN, 2JN, 3JN.
        families = {}
        for b in self.books:
            for kind, names in (("name", b["names"]), ("mishearing", b["mishearings"]), ("abbr", b["abbr"])):
                for n in names:
                    families.setdefault((kind, n), []).append(b["id"])
        self.name_index = {}
        for (kind, n), ids in families.items():
            words = n.split(" ")
            self.name_index.setdefault(words[0], []).append((words, ids, kind))
        for lst in self.name_index.values():
            lst.sort(key=lambda e: (-len(e[0]), e[2] != "name", e[2] != "mishearing"))

    # ---------------------------------------------------------------- numbers

    def number(self, t, i):
        """Reads a cardinal number starting at token i.
        Returns (value, next_index, digit_string_or_None) or None."""
        if i >= len(t):
            return None
        w = t[i]
        if w.isdigit():
            return (int(w), i + 1, w)
        if w in self.hundred:  # "hundred and nineteen"
            return self._after_hundred(t, 100, i + 1)
        if w in self.units:
            v = self.units[w]
            if v < 10 and i + 1 < len(t) and t[i + 1] in self.hundred:
                return self._after_hundred(t, v * 100, i + 2)
            if v < 10 and i + 2 < len(t) and t[i + 1] in self.zero and self.units.get(t[i + 2], 99) < 10:
                return (v * 100 + self.units[t[i + 2]], i + 3, None)  # "one oh five" -> 105
            return (v, i + 1, None)
        if w in self.tens:
            return self._tens(t, i)
        return None

    def _tens(self, t, i):
        v = self.tens[t[i]]
        j = i + 1
        if j < len(t) and t[j] == "-" and j + 1 < len(t) and self.units.get(t[j + 1], 99) < 10:
            j += 1
        if j < len(t) and self.units.get(t[j], 99) < 10:
            return (v + self.units[t[j]], j + 1, None)
        return (v, i + 1, None)

    def _after_hundred(self, t, base, j):
        k = j
        if k < len(t) and t[k] in self.and_words:
            k += 1
        sub = self._under_hundred(t, k)
        if sub:
            return (base + sub[0], sub[1], None)
        return (base, j, None)

    def _under_hundred(self, t, i):
        if i >= len(t):
            return None
        if t[i] in self.units:
            return (self.units[t[i]], i + 1, None)
        if t[i] in self.tens:
            return self._tens(t, i)
        return None

    def ordinal(self, t, i):
        """Reads an ordinal ("second", "23rd", "twenty third"). Returns (value, next) or None."""
        if i >= len(t):
            return None
        w = t[i]
        if w[0].isdigit() and w.endswith(ORDINAL_SUFFIXES):
            return (int(w[:-2]), i + 1)
        if w in self.ordinals:
            return (self.ordinals[w], i + 1)
        if w in self.tens:
            j = i + 1
            if j < len(t) and t[j] == "-":
                j += 1
            if j < len(t) and self.ordinals.get(t[j], 99) < 10:
                return (self.tens[w] + self.ordinals[t[j]], j + 1)
        return None

    # ------------------------------------------------------------------ books

    def book_at(self, t, i, mode, ctx):
        """Is there a book name starting at token i (including a leading
        "1"/"first"/"2nd")? Returns (book_id, next_index, flags) or None."""
        if t[i] in self.book_ordinals and i + 1 < len(t):
            m = self._name_at(t, i + 1, mode)
            if m:
                ids, end, kind = m
                want = self.book_ordinals[t[i]]
                for bid in ids:
                    if self.by_id[bid]["ordinal"] == want:
                        return (bid, end, ["mishearing"] if kind == "mishearing" else [])
        m = self._name_at(t, i, mode)
        if not m:
            return None
        ids, end, kind = m
        flags = ["mishearing"] if kind == "mishearing" else []
        if kind == "abbr":
            flags.append("abbr" if len(t[i]) >= 3 else "abbrShort")
        plain = [bid for bid in ids if self.by_id[bid]["ordinal"] is None]
        if plain:
            return (plain[0], end, flags)
        # "Samuel 2" with no "first"/"second": reuse the last one heard, else assume 1.
        if ctx.book in ids:
            return (ctx.book, end, flags + ["assumedOrdinal"])
        return (ids[0], end, flags + ["assumedOrdinal"])

    def _name_at(self, t, i, mode):
        for words, ids, kind in self.name_index.get(t[i], ()):
            if kind == "abbr" and mode != "document":
                continue
            if kind == "mishearing" and mode != "speech":
                continue
            if t[i:i + len(words)] == words:
                end = i + len(words)
                if kind == "abbr" and end < len(t) and t[end] == ".":
                    end += 1  # "Jn. 3:16"
                return (ids, end, kind)
        return None

    def _starts_numbered_book(self, t, i, mode):
        """True when token i is "1"/"first"... and a numbered book name follows
        ("...2 and 1 Corinthians 15"). Stops us reading that "1" as a verse."""
        if t[i] not in self.book_ordinals or i + 1 >= len(t):
            return False
        m = self._name_at(t, i + 1, mode)
        return bool(m) and any(self.by_id[b]["ordinal"] is not None for b in m[0])

    # ------------------------------------------------------------- validation

    def max_verse(self, book, chapter):
        counts = self.verses[book]
        return counts[chapter - 1] if 1 <= chapter <= len(counts) else 0

    def valid(self, book, chapter, verse=None):
        mv = self.max_verse(book, chapter)
        return mv > 0 and (verse is None or 1 <= verse <= mv)

    # ---------------------------------------------------------------- matching

    def _chapter_word(self, w, mode):
        return w in self.chapter_words or (mode == "document" and w in self.doc_chapter_words)

    def _verse_word(self, w, mode):
        return w in self.verse_words or (mode == "document" and w in self.doc_verse_words)

    def _verse_number(self, t, i):
        """After the word "verse": optional "number", then a number."""
        if i < len(t) and t[i] in self.fillers:
            i += 1
        if i < len(t) and t[i] == ".":
            i += 1  # "v. 5"
        return self.number(t, i)

    def tail(self, t, j, book, mode, flags, chapter=None):
        """Reads "[chapter] N [verse part] [range]" starting at token j, after a
        book name. If `chapter` is given (ordinal form) only the verse part is read.
        Returns (chapter, verse, end_verse, end_index, base_confidence, flags) or None."""
        n = len(t)
        b = self.by_id[book]
        flags = list(flags)
        has_kw = chapter is not None
        if chapter is None:
            if j < n and self._chapter_word(t[j], mode):
                j += 1
                has_kw = True
            num = self.number(t, j)
            if num is None and not has_kw and mode == "speech":
                # "the book of Acts. Amen. In the beginning of chapter two"
                k, words = j, 0
                while k < n and words <= self.limits["chapterGap"]:
                    w = t[k]
                    if self._chapter_word(w, mode):
                        num = self.number(t, k + 1)
                        if num:
                            has_kw = True
                            if words:
                                flags.append("gap")
                        break
                    if w not in PUNCT:
                        if self.number(t, k) or self.ordinal(t, k) or self._name_at(t, k, mode):
                            break
                        words += 1
                    k += 1
            if num is None:
                return None
            chapter, j, digits = num
            # "Psalm one nineteen" -> 119 (when 1:19 does not exist)
            if b["chapters"] >= 100 and chapter < 10 and j < n:
                nxt = self.number(t, j)
                if nxt and 10 <= nxt[0] <= 99 and not self.valid(book, chapter, nxt[0]) \
                        and self.valid(book, chapter * 100 + nxt[0]):
                    chapter, j, digits = chapter * 100 + nxt[0], nxt[1], None
            # One-chapter books: "Jude 3" means Jude 1:3
            if b["chapters"] == 1 and chapter > 1 and self.valid(book, 1, chapter):
                return (1, chapter, None, j, self.conf["impliedVerse"], flags)
            if not self.valid(book, chapter):
                # "Acts 238" -> Acts 2:38 (speech recognisers sometimes glue the digits)
                if digits and len(digits) >= 2:
                    for p in range(1, len(digits)):
                        c, v = int(digits[:p]), int(digits[p:])
                        if digits[p] != "0" and self.valid(book, c, v):
                            return (c, v, None, j, self.conf["impliedVerse"], flags + ["digitSplit"])
                return None

        verse = end_verse = None
        base = self.conf["chapterKeyword"] if has_kw else self.conf["chapterBare"]
        explicit = False       # verse marked by ":" or the word "verse"
        allow_and_range = False
        k = j
        got = None
        if k < n and t[k] == ":":
            got = self.number(t, k + 1)
            explicit = True
        else:
            m = k
            if m < n and t[m] == ",":
                m += 1
            if m < n and t[m] in self.and_words:
                m += 1
            if m < n and self._verse_word(t[m], mode):
                got = self._verse_number(t, m + 1)
                explicit = True
                allow_and_range = True
        if got is None and not explicit and mode == "speech":
            # "Luke 11 and 23", "Luke 11, 24", "John three sixteen"
            m = k
            sep = None
            if m < n and (t[m] == "," or t[m] in self.and_words):
                sep = t[m]
                m += 1
            if m < n and not self._starts_numbered_book(t, m, mode):
                cand = self.number(t, m)
                if cand and self.valid(book, chapter, cand[0]):
                    got = cand
                    allow_and_range = sep == ","
            if got is None:
                # "chapter two. And let us just read the verse 1"
                m, words = k, 0
                while m < n and words <= self.limits["verseGap"]:
                    w = t[m]
                    if self._verse_word(w, mode):
                        got = self._verse_number(t, m + 1)
                        if got:
                            explicit = True
                            allow_and_range = True
                            if words:
                                flags.append("gap")
                        break
                    if w not in PUNCT:
                        if self.number(t, m) or self.ordinal(t, m) or self._name_at(t, m, mode):
                            break
                        words += 1
                    m += 1
        if got is not None:
            if self.valid(book, chapter, got[0]):
                verse, k = got[0], got[1]
                base = self.conf["explicitVerse"] if explicit else self.conf["impliedVerse"]
            else:
                flags.append("verseDropped")  # heard a verse number that does not exist
        if verse is not None and k < n:
            # range: "55 through 58", "16-18", "verses 9 and 10"
            m = k
            is_range = t[m] in self.range_symbols or t[m] in self.range_words \
                or (allow_and_range and t[m] in self.and_words)
            if is_range:
                m += 1
                if m < n and self._verse_word(t[m], mode):
                    m += 1
                if m < n and not self._starts_numbered_book(t, m, mode):
                    cand = self.number(t, m)
                    if cand and cand[0] > verse and self.valid(book, chapter, cand[0]):
                        end_verse, k = cand[0], cand[1]
        return (chapter, verse, end_verse, k, base, flags)

    def score(self, book, base, verse, flags):
        c = self.conf
        s = base
        if "mishearing" in flags:
            s -= c["penaltyMishearing"]
        if "assumedOrdinal" in flags:
            s -= c["penaltyAssumedOrdinal"]
        if "gap" in flags:
            s -= c["penaltyGap"]
        if "digitSplit" in flags:
            s -= c["penaltyDigitSplit"]
        if "verseDropped" in flags:
            s -= c["penaltyVerseDropped"]
        if self.by_id[book]["risky"] and verse is None and base == c["chapterBare"] and "followOn" not in flags:
            s -= c["penaltyRiskyBare"]
            flags.append("riskyBare")
        return round(max(0.05, min(0.99, s)), 2)

    def explicit_at(self, t, i, mode, ctx):
        """A reference that names its book, starting at token i."""
        n = len(t)
        # 1. "Acts 2:38", "First Corinthians chapter 13 verse 4"
        bk = self.book_at(t, i, mode, ctx)
        if bk:
            book, j, flags = bk
            m = j
            if m < n and t[m] == "the":
                m += 1
            o = self.ordinal(t, m)   # "Acts the second chapter"
            if o and o[1] < n and self._chapter_word(t[o[1]], mode) and self.valid(book, o[0]):
                r = self.tail(t, o[1] + 1, book, mode, flags, chapter=o[0])
            else:
                r = self.tail(t, j, book, mode, flags)
            if r:
                if "abbrShort" in r[5] and r[1] is None and t[i] not in self.short_ok:
                    return None  # two-letter abbreviations need a verse: "is 5" is not Isaiah 5
                return (book,) + r
            return None
        # 2. "the second chapter of Acts", "chapter 2 of the book of Acts"
        ch = None
        o = self.ordinal(t, i)
        if o and o[1] < n and self._chapter_word(t[o[1]], mode):
            ch, j = o[0], o[1] + 1
        elif self._chapter_word(t[i], mode):
            num = self.number(t, i + 1)
            if num:
                ch, j = num[0], num[1]
        if ch is not None and j < n and t[j] in self.of_words:
            j += 1
            if j < n and t[j] == "the":
                j += 1
            if j + 1 < n and t[j] in self.intro_words and t[j + 1] in self.of_words:
                j += 2
            if j < n:
                bk = self.book_at(t, j, mode, ctx)
                if bk and self.valid(bk[0], ch):
                    return (bk[0],) + self.tail(t, bk[1], bk[0], mode, bk[2], chapter=ch)
        # 3. "the twenty third psalm"
        if o and o[1] < n and t[o[1]] == "psalm" and self.valid("PSA", o[0]):
            return ("PSA",) + self.tail(t, o[1] + 1, "PSA", mode, [], chapter=o[0])
        return None

    def follow_on_at(self, t, i, ctx):
        """A reference that leans on the last one: "verse 4", "chapter 3",
        "the first chapter", "the next verse". Speech mode only."""
        n = len(t)
        if ctx.book is None or i - ctx.pos > self.limits["contextTokens"]:
            return None
        book, w = ctx.book, t[i]
        base = self.conf["followOn"]
        if w in self.verse_words:
            got = self._verse_number(t, i + 1)
            if got and self.valid(book, ctx.chapter, got[0]):
                verse, k, end_verse = got[0], got[1], None
                if k < n and (t[k] in self.range_symbols or t[k] in self.range_words or t[k] in self.and_words):
                    cand = self.number(t, k + 1)
                    if cand and cand[0] > verse and self.valid(book, ctx.chapter, cand[0]):
                        end_verse, k = cand[0], cand[1]
                return (book, ctx.chapter, verse, end_verse, k, base, ["followOn"])
            return None
        if w == "chapter":
            num = self.number(t, i + 1)
            if num and self.valid(book, num[0]):
                r = self.tail(t, num[1], book, "speech", ["followOn"], chapter=num[0])
                return (book, r[0], r[1], r[2], r[3], base, r[5])
            return None
        o = self.ordinal(t, i)
        if o and o[1] < n and t[o[1]] == "chapter" and self.valid(book, o[0]):
            r = self.tail(t, o[1] + 1, book, "speech", ["followOn"], chapter=o[0])
            return (book, r[0], r[1], r[2], r[3], base, r[5])
        if w in self.next_words and i + 1 < n and t[i + 1] == "verse" and ctx.verse is not None:
            if self.valid(book, ctx.chapter, ctx.verse + 1):
                return (book, ctx.chapter, ctx.verse + 1, None, i + 2, base, ["followOn"])
        return None

    def set_filters(self, ignored_books=(), ignored_phrases=()):
        self.ignored_books = set(ignored_books)
        self.ignored_phrases = [tokenize(p) for p in ignored_phrases if tokenize(p)]

    def ignored_spans(self, t):
        """Token ranges covered by an ignored phrase."""
        spans = []
        for phrase in self.ignored_phrases:
            k = len(phrase)
            for i in range(0, len(t) - k + 1):
                if t[i] == phrase[0] and t[i:i + k] == phrase:
                    spans.append((i, i + k))
        return spans

    def detect_tokens(self, t, mode="speech", ctx=None, quotes=False):
        """Scans a token list. Returns (detections, final_context).
        quotes=True also matches spoken verse text with no reference (Beta)."""
        dets, ctx = self._detect_references(t, mode, ctx)
        if quotes and mode == "speech":
            dets = self.merge_quotes(dets, self.detect_quotes(t, dets))
        spans = self.ignored_spans(t) if self.ignored_phrases else []
        dets = [d for d in dets if d.book not in self.ignored_books
                and not any(d.start < e and s < d.end for s, e in spans)]
        return dets, ctx

    def _detect_references(self, t, mode="speech", ctx=None):
        ctx = ctx or Context()
        out = []
        recent = {}  # key -> token index where it was last emitted (for de-duplication)
        i, n = 0, len(t)
        while i < n:
            if t[i] in PUNCT:
                i += 1
                continue
            r = self.explicit_at(t, i, mode, ctx)
            kind = "explicit"
            if r is None and mode == "speech":
                r = self.follow_on_at(t, i, ctx)
                kind = "followOn"
            if r is None:
                i += 1
                continue
            book, chapter, verse, end_verse, end, base, flags = r
            flags = list(flags)
            conf = self.score(book, base, verse, flags)
            d = Detection(book, chapter, verse, end_verse, i, end, conf, kind, flags, join_tokens(t[i:end]))
            last = recent.get(d.key)
            if last is None or i - last > self.limits["dedupeTokens"]:
                out.append(d)
            recent[d.key] = i
            ctx = Context(book, chapter, end_verse or verse, end)
            # document lists: "Acts 2:38; 4:12" and "John 3:16, 5:24"
            while mode == "document" and end + 3 < n and t[end] in (";", ",") and t[end + 2] == ":":
                c = self.number(t, end + 1)
                if not c or not self.valid(book, c[0]):
                    break
                r2 = self.tail(t, end + 2, book, mode, [], chapter=c[0])
                if r2[1] is None:
                    break
                d = Detection(book, r2[0], r2[1], r2[2], end + 1, r2[3], self.score(book, r2[4], r2[1], []),
                              "explicit", [], join_tokens(t[end + 1:r2[3]]))
                out.append(d)
                ctx = Context(book, r2[0], r2[2] or r2[1], r2[3])
                end = r2[3]
            i = end
        return out, ctx

    def detect(self, text, mode="speech", quotes=False):
        return self.detect_tokens(tokenize(text), mode, quotes=quotes)[0]

    # ------------------------------------------------- quoted scripture (Beta)

    @staticmethod
    def gram_hash(words):
        """64-bit FNV-1a hash of the words joined by spaces. Same in Swift."""
        h = 0xcbf29ce484222325
        for b in " ".join(words).encode("utf-8"):
            h = ((h ^ b) * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF
        return h

    def quote_index(self):
        """Every run of 4 words in the KJV -> the verses containing it."""
        if self._quote_index is None:
            g = self.quote_rules["gram"]
            kjv = json.load(open(os.path.join(RESOURCES, "kjv.json"), encoding="utf-8"))
            index, refs = {}, []
            for b in self.books:
                for ci, chapter in enumerate(kjv[b["id"]]):
                    for vi, text in enumerate(chapter):
                        words = [w for w in tokenize(text) if w not in PUNCT]
                        n = len(refs)
                        refs.append((b["id"], ci + 1, vi + 1))
                        for i in range(len(words) - g + 1):
                            index.setdefault(self.gram_hash(words[i:i + g]), []).append(n)
            self._quote_index = (index, refs)
        return self._quote_index

    def detect_quotes(self, t, dets):
        """Finds verse text spoken with no reference: at least `minHits` different
        4-word runs from one verse inside a `window`-word stretch."""
        q = self.quote_rules
        g, window, need = q["gram"], q["window"], q["minHits"]
        index, refs = self.quote_index()
        pos = [i for i, w in enumerate(t) if w not in PUNCT]     # word positions (punctuation skipped)
        words = [t[i] for i in pos]
        hits = []                                                # (word index, set of verse numbers)
        for i in range(len(words) - g + 1):
            v = index.get(self.gram_hash(words[i:i + g]))
            if v:
                hits.append((i, set(v)))
        out, i, last_end = [], 0, {}
        while i < len(hits):
            start = hits[i][0]
            counts, j = {}, i
            while j < len(hits) and hits[j][0] - start < window:
                for v in hits[j][1]:
                    counts[v] = counts.get(v, 0) + 1
                j += 1
            best = max(counts.values())
            if best < need:
                i += 1
                continue
            top = sorted(v for v, c in counts.items() if c == best)
            # the reference heard most recently before this point, if any
            near = None
            for d in dets:
                if d.end <= pos[start]:
                    near = d
            in_ctx = [v for v in top if near and refs[v][0] == near.book and refs[v][1] == near.chapter]
            cands = in_ctx or top
            if len(cands) > 1:
                i += 1          # the same words are in several verses and nothing says which one
                continue
            v = cands[0]
            book, chapter, verse = refs[v]
            last_word = max(h[0] for h in hits[i:j] if v in h[1]) + g - 1
            s_tok, e_tok = pos[start], pos[last_word] + 1
            conf = self.conf["quoteInContext"] if in_ctx else self.conf["quote"]
            out.append(Detection(book, chapter, verse, None, s_tok, e_tok, conf, "quote", ["quote"], join_tokens(t[s_tok:e_tok])))
            # move past this verse's words
            while i < len(hits) and hits[i][0] <= last_word - g + 1:
                i += 1
        return out

    def merge_quotes(self, dets, quotes):
        """Adds quote matches that are not already covered by a spoken reference."""
        gap = self.quote_rules["dedupeTokens"]
        kept = list(dets)
        for qd in quotes:
            clash = False
            for d in kept:
                same = d.book == qd.book and d.chapter == qd.chapter and (
                    d.verse is None or d.verse <= qd.verse <= (d.end_verse or d.verse))
                overlap = qd.start < d.end and d.start < qd.end
                if overlap or (same and abs(qd.start - d.end) <= gap and d.kind != "quote") \
                        or (d.kind == "quote" and d.key == qd.key and qd.start - d.end <= gap):
                    clash = True
                    break
            if not clash:
                kept.append(qd)
        kept.sort(key=lambda d: d.start)
        return kept

    # ---------------------------------------------------------------- display

    def display(self, d):
        b = self.by_id[d.book]
        name = b.get("singular", b["name"])
        s = "%s %d" % (name, d.chapter)
        if d.verse is not None:
            s += ":%d" % d.verse
            if d.end_verse is not None:
                s += "–%d" % d.end_verse
        return s


def join_tokens(tokens):
    s = ""
    for w in tokens:
        if s and w not in PUNCT and not s.endswith(":") and not s.endswith("-"):
            s += " "
        s += w
    return s


class Session:
    """Live use: feed finalized transcript text as it arrives. Each call returns
    events - ("new", detection) the first time a reference shows up,
    ("update", detection) when more words refine it ("Acts 2" -> "Acts 2:38"),
    and ("remove", start_index) when a provisional one turns out to be a repeat
    of something just reported. Token indexes are absolute for the session."""

    MAX_TOKENS = 3000   # when the buffer grows past this...
    KEEP_TOKENS = 300   # ...keep roughly this many and remember the context

    def __init__(self, engine, mode="speech"):
        self.engine, self.mode = engine, mode
        self.tokens = []
        self.base = 0           # absolute index of tokens[0]
        self.ctx0 = Context()   # context at tokens[0] (positions relative to tokens[0])
        self.seen = {}          # absolute start index -> key last reported
        self.quotes = False     # set True to also match quoted scripture (Beta)

    def _scan(self, tokens):
        dets, _ = self.engine.detect_tokens(tokens, self.mode,
                                            Context(self.ctx0.book, self.ctx0.chapter, self.ctx0.verse, self.ctx0.pos),
                                            quotes=self.quotes)
        for d in dets:
            d.start += self.base
            d.end += self.base
        return dets

    def feed(self, text):
        self.tokens.extend(tokenize(text))
        events = []
        dets = self._scan(self.tokens)
        for d in dets:
            old = self.seen.get(d.start)
            if old is None:
                events.append(("new", d))
            elif old != d.key:
                events.append(("update", d))
            self.seen[d.start] = d.key
        live = set(d.start for d in dets)
        for start in [k for k in self.seen if k >= self.base and k not in live]:
            del self.seen[start]
            events.append(("remove", start))
        if len(self.tokens) > self.MAX_TOKENS:
            self._trim(dets)
        return events

    def preview(self, volatile_text):
        """Detections including not-yet-final words. Nothing is remembered."""
        return [d for d in self._scan(self.tokens + tokenize(volatile_text)) if d.start not in self.seen
                or self.seen[d.start] != d.key]

    def _trim(self, dets):
        cut = len(self.tokens) - self.KEEP_TOKENS + self.base   # absolute
        dedupe = self.engine.limits["dedupeTokens"]
        moved = True
        while moved:  # never cut through a detection or its de-duplication window
            moved = False
            for d in dets:
                if d.start < cut and (d.end > cut or cut - d.start <= dedupe):
                    cut = d.start
                    moved = True
        last = None
        for d in dets:
            if d.end <= cut:
                last = d
        if last is not None:
            self.ctx0 = Context(last.book, last.chapter, last.end_verse or last.verse, last.end - cut)
        else:
            self.ctx0 = Context(self.ctx0.book, self.ctx0.chapter, self.ctx0.verse, self.ctx0.pos - (cut - self.base))
        self.tokens = self.tokens[cut - self.base:]
        self.base = cut
        self.seen = {k: v for k, v in self.seen.items() if k >= cut}


class KJV:
    """Verse text lookup (King James Version, public domain)."""
    def __init__(self, resources=RESOURCES):
        self.text = json.load(open(os.path.join(resources, "kjv.json"), encoding="utf-8"))

    def verses(self, book, chapter, verse=None, end_verse=None):
        """Returns [(verse_number, text), ...]. A chapter-only reference returns the whole chapter."""
        ch = self.text[book][chapter - 1]
        first = verse or 1
        last = end_verse or (verse if verse else len(ch))
        return [(v, ch[v - 1]) for v in range(first, last + 1)]
