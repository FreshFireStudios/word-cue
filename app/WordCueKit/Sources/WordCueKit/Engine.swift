// UNTESTED: written without a Swift compiler. Verify with `swift test` on the Mac.
//
// This file mirrors engine-python/wordcue_engine.py function for function, in
// the same order. The Python version was run against the shared test cases
// and three sermon transcripts; this one must give the same answers.
// When a rule changes, change both.
import Foundation

public final class Engine: @unchecked Sendable {
    typealias Number = (value: Int, next: Int, digits: String?)
    typealias Tail = (chapter: Int, verse: Int?, endVerse: Int?, end: Int, base: Double, flags: [String])
    typealias Match = (book: String, chapter: Int, verse: Int?, endVerse: Int?, end: Int, base: Double, flags: [String])
    typealias NameEntry = (words: [String], ids: [String], kind: String)

    public let books: [Book]
    let byId: [String: Book]
    let verses: [String: [Int]]
    let units: [String: Int]
    let tens: [String: Int]
    let hundred: Set<String>
    let zero: Set<String>
    let ordinals: [String: Int]
    let bookOrdinals: [String: Int]
    let chapterWords: Set<String>
    let docChapterWords: Set<String>
    let verseWords: Set<String>
    let docVerseWords: Set<String>
    let fillers: Set<String>
    let rangeWords: Set<String>
    let rangeSymbols: Set<String>
    let andWords: Set<String>
    let ofWords: Set<String>
    let introWords: Set<String>
    let nextWords: Set<String>
    let shortOK: Set<String>
    let limits: [String: Int]
    let conf: [String: Double]
    var nameIndex: [String: [NameEntry]] = [:]

    public init() {
        books = Resources.load("books", as: [Book].self)
        let numbers = Resources.load("numbers", as: NumberRules.self)
        let r = Resources.load("rules", as: DetectionRules.self)
        verses = Resources.load("versification", as: [String: [Int]].self)
        byId = Dictionary(uniqueKeysWithValues: books.map { ($0.id, $0) })
        units = numbers.units
        tens = numbers.tens
        hundred = Set(numbers.hundred)
        zero = Set(numbers.zero)
        ordinals = numbers.ordinals
        bookOrdinals = numbers.bookOrdinals
        chapterWords = Set(r.chapterWords)
        docChapterWords = Set(r.docChapterWords)
        verseWords = Set(r.verseWords)
        docVerseWords = Set(r.docVerseWords)
        fillers = Set(r.verseNumberFillers)
        rangeWords = Set(r.rangeWords)
        rangeSymbols = Set(r.rangeSymbols)
        andWords = Set(r.andWords)
        ofWords = Set(r.ofWords)
        introWords = Set(r.bookIntroWords)
        nextWords = Set(r.nextWords)
        shortOK = Set(r.shortAbbrChapterOnly)
        limits = r.limits
        conf = r.confidence

        // Name index: first word -> entries. A "family" is the list of books
        // sharing a name: "john" -> JHN, 1JN, 2JN, 3JN.
        var families: [String: [String]] = [:]   // "kind|name" -> book ids, in Bible order
        var order: [String] = []
        for b in books {
            for (kind, names) in [("name", b.names), ("mishearing", b.mishearings), ("abbr", b.abbr)] {
                for name in names {
                    let k = kind + "|" + name
                    if families[k] == nil { order.append(k) }
                    families[k, default: []].append(b.id)
                }
            }
        }
        for k in order {
            let parts = k.split(separator: "|", maxSplits: 1).map(String.init)
            let words = parts[1].split(separator: " ").map(String.init)
            nameIndex[words[0], default: []].append((words, families[k]!, parts[0]))
        }
        let rank = ["name": 0, "mishearing": 1, "abbr": 2]
        for key in nameIndex.keys {
            nameIndex[key]!.sort { a, b in
                if a.words.count != b.words.count { return a.words.count > b.words.count }
                return rank[a.kind]! < rank[b.kind]!
            }
        }
    }

    // MARK: - Numbers

    /// Reads a cardinal number starting at token i.
    func number(_ t: [String], _ i: Int) -> Number? {
        guard i < t.count else { return nil }
        let w = t[i]
        if !w.isEmpty, w.allSatisfy({ $0 >= "0" && $0 <= "9" }), let v = Int(w) {
            return (v, i + 1, w)
        }
        if hundred.contains(w) {            // "hundred and nineteen"
            return afterHundred(t, 100, i + 1)
        }
        if let v = units[w] {
            if v < 10 && i + 1 < t.count && hundred.contains(t[i + 1]) {
                return afterHundred(t, v * 100, i + 2)
            }
            if v < 10 && i + 2 < t.count && zero.contains(t[i + 1]), let u = units[t[i + 2]], u < 10 {
                return (v * 100 + u, i + 3, nil)   // "one oh five" -> 105
            }
            return (v, i + 1, nil)
        }
        if tens[w] != nil {
            return tensNumber(t, i)
        }
        return nil
    }

    func tensNumber(_ t: [String], _ i: Int) -> Number {
        let v = tens[t[i]]!
        var j = i + 1
        if j < t.count && t[j] == "-" && j + 1 < t.count, let u = units[t[j + 1]], u < 10 {
            j += 1
        }
        if j < t.count, let u = units[t[j]], u < 10 {
            return (v + u, j + 1, nil)
        }
        return (v, i + 1, nil)
    }

    func afterHundred(_ t: [String], _ base: Int, _ j: Int) -> Number {
        var k = j
        if k < t.count && andWords.contains(t[k]) { k += 1 }
        if let sub = underHundred(t, k) {
            return (base + sub.value, sub.next, nil)
        }
        return (base, j, nil)
    }

    func underHundred(_ t: [String], _ i: Int) -> Number? {
        guard i < t.count else { return nil }
        if let u = units[t[i]] { return (u, i + 1, nil) }
        if tens[t[i]] != nil { return tensNumber(t, i) }
        return nil
    }

    /// Reads an ordinal ("second", "23rd", "twenty third").
    func ordinal(_ t: [String], _ i: Int) -> (value: Int, next: Int)? {
        guard i < t.count else { return nil }
        let w = t[i]
        if let first = w.first, first >= "0" && first <= "9",
           w.hasSuffix("st") || w.hasSuffix("nd") || w.hasSuffix("rd") || w.hasSuffix("th"),
           let v = Int(w.dropLast(2)) {
            return (v, i + 1)
        }
        if let v = ordinals[w] { return (v, i + 1) }
        if let ten = tens[w] {
            var j = i + 1
            if j < t.count && t[j] == "-" { j += 1 }
            if j < t.count, let o = ordinals[t[j]], o < 10 {
                return (ten + o, j + 1)
            }
        }
        return nil
    }

    // MARK: - Books

    /// Is there a book name starting at token i (including a leading
    /// "1"/"first"/"2nd")?
    func bookAt(_ t: [String], _ i: Int, _ mode: DetectionMode, _ ctx: Context) -> (book: String, next: Int, flags: [String])? {
        if let want = bookOrdinals[t[i]], i + 1 < t.count, let m = nameAt(t, i + 1, mode) {
            for id in m.ids where byId[id]!.ordinal == want {
                return (id, m.end, m.kind == "mishearing" ? ["mishearing"] : [])
            }
        }
        guard let m = nameAt(t, i, mode) else { return nil }
        var flags: [String] = m.kind == "mishearing" ? ["mishearing"] : []
        if m.kind == "abbr" {
            flags.append(t[i].count >= 3 ? "abbr" : "abbrShort")
        }
        if let plain = m.ids.first(where: { byId[$0]!.ordinal == nil }) {
            return (plain, m.end, flags)
        }
        // "Samuel 2" with no "first"/"second": reuse the last one heard, else assume 1.
        if let last = ctx.book, m.ids.contains(last) {
            return (last, m.end, flags + ["assumedOrdinal"])
        }
        return (m.ids[0], m.end, flags + ["assumedOrdinal"])
    }

    func nameAt(_ t: [String], _ i: Int, _ mode: DetectionMode) -> (ids: [String], end: Int, kind: String)? {
        guard i < t.count, let entries = nameIndex[t[i]] else { return nil }
        for e in entries {
            if e.kind == "abbr" && mode != .document { continue }
            if e.kind == "mishearing" && mode != .speech { continue }
            if i + e.words.count <= t.count && Array(t[i..<(i + e.words.count)]) == e.words {
                var end = i + e.words.count
                if e.kind == "abbr" && end < t.count && t[end] == "." {
                    end += 1   // "Jn. 3:16"
                }
                return (e.ids, end, e.kind)
            }
        }
        return nil
    }

    /// True when token i is "1"/"first"... and a numbered book name follows
    /// ("...2 and 1 Corinthians 15"). Stops us reading that "1" as a verse.
    func startsNumberedBook(_ t: [String], _ i: Int, _ mode: DetectionMode) -> Bool {
        guard bookOrdinals[t[i]] != nil, i + 1 < t.count, let m = nameAt(t, i + 1, mode) else { return false }
        return m.ids.contains { byId[$0]!.ordinal != nil }
    }

    // MARK: - Validation

    func maxVerse(_ book: String, _ chapter: Int) -> Int {
        guard let counts = verses[book], chapter >= 1, chapter <= counts.count else { return 0 }
        return counts[chapter - 1]
    }

    func valid(_ book: String, _ chapter: Int, _ verse: Int? = nil) -> Bool {
        let mv = maxVerse(book, chapter)
        guard mv > 0 else { return false }
        if let verse { return verse >= 1 && verse <= mv }
        return true
    }

    // MARK: - Matching

    func isChapterWord(_ w: String, _ mode: DetectionMode) -> Bool {
        chapterWords.contains(w) || (mode == .document && docChapterWords.contains(w))
    }

    func isVerseWord(_ w: String, _ mode: DetectionMode) -> Bool {
        verseWords.contains(w) || (mode == .document && docVerseWords.contains(w))
    }

    func isPunct(_ w: String) -> Bool { Tokenizer.punctuation.contains(w) }

    /// After the word "verse": optional "number", then a number.
    func verseNumber(_ t: [String], _ start: Int) -> Number? {
        var i = start
        if i < t.count && fillers.contains(t[i]) { i += 1 }
        if i < t.count && t[i] == "." { i += 1 }   // "v. 5"
        return number(t, i)
    }

    /// Reads "[chapter] N [verse part] [range]" starting at token j, after a
    /// book name. If `givenChapter` is set (ordinal form) only the verse part is read.
    func tail(_ t: [String], _ start: Int, _ book: String, _ mode: DetectionMode,
              _ inFlags: [String], givenChapter: Int? = nil) -> Tail? {
        let n = t.count
        let b = byId[book]!
        var flags = inFlags
        var j = start
        var hasKeyword = givenChapter != nil
        var chapter = givenChapter ?? 0

        if givenChapter == nil {
            if j < n && isChapterWord(t[j], mode) {
                j += 1
                hasKeyword = true
            }
            var num = number(t, j)
            if num == nil && !hasKeyword && mode == .speech {
                // "the book of Acts. Amen. In the beginning of chapter two"
                var k = j
                var words = 0
                while k < n && words <= limits["chapterGap"]! {
                    let w = t[k]
                    if isChapterWord(w, mode) {
                        num = number(t, k + 1)
                        if num != nil {
                            hasKeyword = true
                            if words > 0 { flags.append("gap") }
                        }
                        break
                    }
                    if !isPunct(w) {
                        if number(t, k) != nil || ordinal(t, k) != nil || nameAt(t, k, mode) != nil { break }
                        words += 1
                    }
                    k += 1
                }
            }
            guard let found = num else { return nil }
            chapter = found.value
            j = found.next
            var digits = found.digits
            // "Psalm one nineteen" -> 119 (when 1:19 does not exist)
            if b.chapters >= 100 && chapter < 10 && j < n,
               let nxt = number(t, j), nxt.value >= 10, nxt.value <= 99,
               !valid(book, chapter, nxt.value), valid(book, chapter * 100 + nxt.value) {
                chapter = chapter * 100 + nxt.value
                j = nxt.next
                digits = nil
            }
            // One-chapter books: "Jude 3" means Jude 1:3
            if b.chapters == 1 && chapter > 1 && valid(book, 1, chapter) {
                return (1, chapter, nil, j, conf["impliedVerse"]!, flags)
            }
            if !valid(book, chapter) {
                // "Acts 238" -> Acts 2:38 (speech recognisers sometimes glue the digits)
                if let digits, digits.count >= 2 {
                    let ds = Array(digits)
                    for p in 1..<ds.count {
                        let c = Int(String(ds[0..<p]))!
                        let v = Int(String(ds[p...]))!
                        if ds[p] != "0" && valid(book, c, v) {
                            return (c, v, nil, j, conf["impliedVerse"]!, flags + ["digitSplit"])
                        }
                    }
                }
                return nil
            }
        }

        var verse: Int? = nil
        var endVerse: Int? = nil
        var base = hasKeyword ? conf["chapterKeyword"]! : conf["chapterBare"]!
        var explicit = false          // verse marked by ":" or the word "verse"
        var allowAndRange = false
        var k = j
        var got: Number? = nil

        if k < n && t[k] == ":" {
            got = number(t, k + 1)
            explicit = true
        } else {
            var m = k
            if m < n && t[m] == "," { m += 1 }
            if m < n && andWords.contains(t[m]) { m += 1 }
            if m < n && isVerseWord(t[m], mode) {
                got = verseNumber(t, m + 1)
                explicit = true
                allowAndRange = true
            }
        }
        if got == nil && !explicit && mode == .speech {
            // "Luke 11 and 23", "Luke 11, 24", "John three sixteen"
            var m = k
            var sep: String? = nil
            if m < n && (t[m] == "," || andWords.contains(t[m])) {
                sep = t[m]
                m += 1
            }
            if m < n && !startsNumberedBook(t, m, mode) {
                if let cand = number(t, m), valid(book, chapter, cand.value) {
                    got = cand
                    allowAndRange = sep == ","
                }
            }
            if got == nil {
                // "chapter two. And let us just read the verse 1"
                m = k
                var words = 0
                while m < n && words <= limits["verseGap"]! {
                    let w = t[m]
                    if isVerseWord(w, mode) {
                        got = verseNumber(t, m + 1)
                        if got != nil {
                            explicit = true
                            allowAndRange = true
                            if words > 0 { flags.append("gap") }
                        }
                        break
                    }
                    if !isPunct(w) {
                        if number(t, m) != nil || ordinal(t, m) != nil || nameAt(t, m, mode) != nil { break }
                        words += 1
                    }
                    m += 1
                }
            }
        }
        if let g = got {
            if valid(book, chapter, g.value) {
                verse = g.value
                k = g.next
                base = explicit ? conf["explicitVerse"]! : conf["impliedVerse"]!
            } else {
                flags.append("verseDropped")   // heard a verse number that does not exist
            }
        }
        if let v = verse, k < n {
            // range: "55 through 58", "16-18", "verses 9 and 10"
            var m = k
            let isRange = rangeSymbols.contains(t[m]) || rangeWords.contains(t[m])
                || (allowAndRange && andWords.contains(t[m]))
            if isRange {
                m += 1
                if m < n && isVerseWord(t[m], mode) { m += 1 }
                if m < n && !startsNumberedBook(t, m, mode) {
                    if let cand = number(t, m), cand.value > v, valid(book, chapter, cand.value) {
                        endVerse = cand.value
                        k = cand.next
                    }
                }
            }
        }
        return (chapter, verse, endVerse, k, base, flags)
    }

    /// Turns the base score and the flags into the final confidence.
    /// May add the "riskyBare" flag.
    func score(_ book: String, _ base: Double, _ verse: Int?, _ flags: inout [String]) -> Double {
        var s = base
        if flags.contains("mishearing") { s -= conf["penaltyMishearing"]! }
        if flags.contains("assumedOrdinal") { s -= conf["penaltyAssumedOrdinal"]! }
        if flags.contains("gap") { s -= conf["penaltyGap"]! }
        if flags.contains("digitSplit") { s -= conf["penaltyDigitSplit"]! }
        if flags.contains("verseDropped") { s -= conf["penaltyVerseDropped"]! }
        if byId[book]!.risky && verse == nil && base == conf["chapterBare"]! && !flags.contains("followOn") {
            s -= conf["penaltyRiskyBare"]!
            flags.append("riskyBare")
        }
        return (max(0.05, min(0.99, s)) * 100).rounded() / 100
    }

    /// A reference that names its book, starting at token i.
    func explicitAt(_ t: [String], _ i: Int, _ mode: DetectionMode, _ ctx: Context) -> Match? {
        let n = t.count
        // 1. "Acts 2:38", "First Corinthians chapter 13 verse 4"
        if let bk = bookAt(t, i, mode, ctx) {
            var m = bk.next
            if m < n && t[m] == "the" { m += 1 }
            var r: Tail?
            if let o = ordinal(t, m), o.next < n, isChapterWord(t[o.next], mode), valid(bk.book, o.value) {
                r = tail(t, o.next + 1, bk.book, mode, bk.flags, givenChapter: o.value)   // "Acts the second chapter"
            } else {
                r = tail(t, bk.next, bk.book, mode, bk.flags)
            }
            guard let r else { return nil }
            if r.flags.contains("abbrShort") && r.verse == nil && !shortOK.contains(t[i]) {
                return nil   // two-letter abbreviations need a verse: "is 5" is not Isaiah 5
            }
            return (bk.book, r.chapter, r.verse, r.endVerse, r.end, r.base, r.flags)
        }
        // 2. "the second chapter of Acts", "chapter 2 of the book of Acts"
        var chapter: Int? = nil
        var j = i
        let o = ordinal(t, i)
        if let o, o.next < n, isChapterWord(t[o.next], mode) {
            chapter = o.value
            j = o.next + 1
        } else if isChapterWord(t[i], mode), let num = number(t, i + 1) {
            chapter = num.value
            j = num.next
        }
        if let ch = chapter, j < n, ofWords.contains(t[j]) {
            j += 1
            if j < n && t[j] == "the" { j += 1 }
            if j + 1 < n && introWords.contains(t[j]) && ofWords.contains(t[j + 1]) { j += 2 }
            if j < n, let bk = bookAt(t, j, mode, ctx), valid(bk.book, ch),
               let r = tail(t, bk.next, bk.book, mode, bk.flags, givenChapter: ch) {
                return (bk.book, r.chapter, r.verse, r.endVerse, r.end, r.base, r.flags)
            }
        }
        // 3. "the twenty third psalm"
        if let o, o.next < n, t[o.next] == "psalm", valid("PSA", o.value),
           let r = tail(t, o.next + 1, "PSA", mode, [], givenChapter: o.value) {
            return ("PSA", r.chapter, r.verse, r.endVerse, r.end, r.base, r.flags)
        }
        return nil
    }

    /// A reference that leans on the last one: "verse 4", "chapter 3",
    /// "the first chapter", "the next verse". Speech mode only.
    func followOnAt(_ t: [String], _ i: Int, _ ctx: Context) -> Match? {
        let n = t.count
        guard let book = ctx.book, i - ctx.pos <= limits["contextTokens"]! else { return nil }
        let w = t[i]
        let base = conf["followOn"]!
        if verseWords.contains(w) {
            if let got = verseNumber(t, i + 1), valid(book, ctx.chapter, got.value) {
                let verse = got.value
                var k = got.next
                var endVerse: Int? = nil
                if k < n && (rangeSymbols.contains(t[k]) || rangeWords.contains(t[k]) || andWords.contains(t[k])) {
                    if let cand = number(t, k + 1), cand.value > verse, valid(book, ctx.chapter, cand.value) {
                        endVerse = cand.value
                        k = cand.next
                    }
                }
                return (book, ctx.chapter, verse, endVerse, k, base, ["followOn"])
            }
            return nil
        }
        if w == "chapter" {
            if let num = number(t, i + 1), valid(book, num.value),
               let r = tail(t, num.next, book, .speech, ["followOn"], givenChapter: num.value) {
                return (book, r.chapter, r.verse, r.endVerse, r.end, base, r.flags)
            }
            return nil
        }
        if let o = ordinal(t, i), o.next < n, t[o.next] == "chapter", valid(book, o.value),
           let r = tail(t, o.next + 1, book, .speech, ["followOn"], givenChapter: o.value) {
            return (book, r.chapter, r.verse, r.endVerse, r.end, base, r.flags)
        }
        if nextWords.contains(w) && i + 1 < n && t[i + 1] == "verse", let v = ctx.verse {
            if valid(book, ctx.chapter, v + 1) {
                return (book, ctx.chapter, v + 1, nil, i + 2, base, ["followOn"])
            }
        }
        return nil
    }

    /// Scans a token list. Returns the detections and the context at the end.
    func detectTokens(_ t: [String], mode: DetectionMode, context: Context = Context()) -> (detections: [Detection], context: Context) {
        var ctx = context
        var out: [Detection] = []
        var recent: [String: Int] = [:]   // key -> token index where it was last seen (de-duplication)
        var i = 0
        let n = t.count
        while i < n {
            if isPunct(t[i]) {
                i += 1
                continue
            }
            var r = explicitAt(t, i, mode, ctx)
            var kind = Detection.Kind.explicit
            if r == nil && mode == .speech {
                r = followOnAt(t, i, ctx)
                kind = .followOn
            }
            guard let m = r else {
                i += 1
                continue
            }
            var flags = m.flags
            let confidence = score(m.book, m.base, m.verse, &flags)
            let ref = Reference(book: m.book, chapter: m.chapter, verse: m.verse, endVerse: m.endVerse)
            let d = Detection(reference: ref, start: i, end: m.end, confidence: confidence, kind: kind,
                              flags: flags, text: Tokenizer.join(t[i..<m.end]))
            if let last = recent[d.key] {
                if i - last > limits["dedupeTokens"]! { out.append(d) }
            } else {
                out.append(d)
            }
            recent[d.key] = i
            ctx = Context(book: m.book, chapter: m.chapter, verse: m.endVerse ?? m.verse, pos: m.end)
            var end = m.end
            // document lists: "Acts 2:38; 4:12" and "John 3:16, 5:24"
            while mode == .document && end + 3 < n && (t[end] == ";" || t[end] == ",") && t[end + 2] == ":" {
                guard let c = number(t, end + 1), valid(m.book, c.value),
                      let r2 = tail(t, end + 2, m.book, mode, [], givenChapter: c.value),
                      let v2 = r2.verse else { break }
                var f2: [String] = []
                let conf2 = score(m.book, r2.base, v2, &f2)
                let ref2 = Reference(book: m.book, chapter: r2.chapter, verse: v2, endVerse: r2.endVerse)
                out.append(Detection(reference: ref2, start: end + 1, end: r2.end, confidence: conf2,
                                     kind: .explicit, flags: f2, text: Tokenizer.join(t[(end + 1)..<r2.end])))
                ctx = Context(book: m.book, chapter: r2.chapter, verse: r2.endVerse ?? v2, pos: r2.end)
                end = r2.end
            }
            i = end
        }
        return (out, ctx)
    }

    /// Finds every reference in a piece of text.
    public func detect(_ text: String, mode: DetectionMode = .speech) -> [Detection] {
        detectTokens(Tokenizer.tokenize(text), mode: mode).detections
    }

    // MARK: - Display

    public func book(_ id: String) -> Book? { byId[id] }

    /// "Acts 2:38", "Matthew 13:55–58", "Psalm 23".
    public func display(_ ref: Reference) -> String {
        guard let b = byId[ref.book] else { return ref.key }
        var s = "\(b.singular ?? b.name) \(ref.chapter)"
        if let v = ref.verse {
            s += ":\(v)"
            if let e = ref.endVerse { s += "\u{2013}\(e)" }
        }
        return s
    }

    /// Words worth teaching the speech recogniser: every book name.
    public var vocabulary: [String] {
        books.map { $0.name } + ["Psalm", "Revelation"]
    }
}
