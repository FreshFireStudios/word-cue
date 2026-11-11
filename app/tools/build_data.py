#!/usr/bin/env python3
"""Builds the shared data files in WordCueKit/Sources/WordCueKit/Resources.

Run once (already done, outputs are committed):
    python3 tools/build_data.py path/to/en_kjv.json

Input: the public-domain King James text as JSON from
https://github.com/thiagobodruk/bible (json/en_kjv.json) - a list of 66 books,
each {"chapters": [[verse, verse, ...], ...]}.

Outputs:
    books.json          names, abbreviations and chapter counts for the 66 books
    versification.json  how many verses each chapter has (used to reject impossible references)
    kjv.json            the verse text, keyed by book id
"""
import json, sys, os

OUT = os.path.join(os.path.dirname(__file__), "..", "WordCueKit", "Sources", "WordCueKit", "Resources")

# id, display name, ordinal (for numbered books), spoken names, written abbreviations, extras
# "names" are matched in live speech. "abbr" only in document mode (dropped files).
# "mishearings" are things speech recognition writes instead of the book name.
# "risky" marks names that are also everyday words, so a bare "Mark 5" scores lower.
B = [
 ("GEN","Genesis",None,["genesis"],["gen","ge","gn"],{}),
 ("EXO","Exodus",None,["exodus"],["exod","exo","ex"],{}),
 ("LEV","Leviticus",None,["leviticus"],["lev","lv"],{}),
 ("NUM","Numbers",None,["numbers"],["num","nu","nm"],{"risky":True}),
 ("DEU","Deuteronomy",None,["deuteronomy"],["deut","deu","dt"],{"mishearings":["due to ronomy"]}),
 ("JOS","Joshua",None,["joshua"],["josh","jos"],{}),
 ("JDG","Judges",None,["judges"],["judg","jdg","jgs"],{"risky":True}),
 ("RUT","Ruth",None,["ruth"],["ru","rut"],{}),
 ("1SA","1 Samuel",1,["samuel"],["sam","sa","sm"],{}),
 ("2SA","2 Samuel",2,["samuel"],["sam","sa","sm"],{}),
 ("1KI","1 Kings",1,["kings"],["kgs","ki","kin"],{}),
 ("2KI","2 Kings",2,["kings"],["kgs","ki","kin"],{}),
 ("1CH","1 Chronicles",1,["chronicles","chronicle"],["chron","chr","ch"],{}),
 ("2CH","2 Chronicles",2,["chronicles","chronicle"],["chron","chr","ch"],{}),
 ("EZR","Ezra",None,["ezra"],["ezr"],{}),
 ("NEH","Nehemiah",None,["nehemiah"],["neh","ne"],{}),
 ("EST","Esther",None,["esther"],["esth","est"],{}),
 ("JOB","Job",None,["job"],["jb"],{"risky":True}),
 ("PSA","Psalms",None,["psalms","psalm"],["ps","psa","pss"],{"singular":"Psalm","mishearings":["salm","salms","palm","palms"]}),
 ("PRO","Proverbs",None,["proverbs","proverb"],["prov","pro","pr"],{}),
 ("ECC","Ecclesiastes",None,["ecclesiastes"],["eccl","eccles","ecc","ec"],{}),
 ("SNG","Song of Solomon",None,["song of solomon","song of songs","songs of solomon"],["song","sos","sng"],{}),
 ("ISA","Isaiah",None,["isaiah"],["isa","is"],{"mishearings":["isiah"]}),
 ("JER","Jeremiah",None,["jeremiah"],["jer","je"],{}),
 ("LAM","Lamentations",None,["lamentations"],["lam","la"],{}),
 ("EZK","Ezekiel",None,["ezekiel"],["ezek","eze","ezk"],{}),
 ("DAN","Daniel",None,["daniel"],["dan","da","dn"],{}),
 ("HOS","Hosea",None,["hosea"],["hos","ho"],{}),
 ("JOL","Joel",None,["joel"],["jl"],{}),
 ("AMO","Amos",None,["amos"],["am"],{}),
 ("OBA","Obadiah",None,["obadiah"],["obad","ob"],{}),
 ("JON","Jonah",None,["jonah"],["jon","jnh"],{}),
 ("MIC","Micah",None,["micah"],["mic","mi"],{}),
 ("NAM","Nahum",None,["nahum"],["nah","na"],{}),
 ("HAB","Habakkuk",None,["habakkuk"],["hab"],{"mishearings":["habakuk","habbakuk","habacuc"]}),
 ("ZEP","Zephaniah",None,["zephaniah"],["zeph","zep"],{}),
 ("HAG","Haggai",None,["haggai"],["hag","hg"],{}),
 ("ZEC","Zechariah",None,["zechariah"],["zech","zec"],{}),
 ("MAL","Malachi",None,["malachi"],["mal"],{}),
 ("MAT","Matthew",None,["matthew"],["matt","mt"],{}),
 ("MRK","Mark",None,["mark"],["mk","mrk"],{"risky":True}),
 ("LUK","Luke",None,["luke"],["lk","luk"],{}),
 ("JHN","John",None,["john"],["jn","jhn"],{}),
 ("ACT","Acts",None,["acts","acts of the apostles"],["ac"],{"risky":True,"mishearings":["axe","ax","axed","act"]}),
 ("ROM","Romans",None,["romans"],["rom","ro","rm"],{}),
 ("1CO","1 Corinthians",1,["corinthians","corinthian"],["cor","co"],{}),
 ("2CO","2 Corinthians",2,["corinthians","corinthian"],["cor","co"],{}),
 ("GAL","Galatians",None,["galatians"],["gal","ga"],{"mishearings":["gallations","galations"]}),
 ("EPH","Ephesians",None,["ephesians"],["eph","ephes"],{}),
 ("PHP","Philippians",None,["philippians"],["phil","php","pp"],{"mishearings":["philippines","phillipians"]}),
 ("COL","Colossians",None,["colossians"],["col"],{"mishearings":["collosians","colossian"]}),
 ("1TH","1 Thessalonians",1,["thessalonians","thessalonian"],["thess","thes","th"],{}),
 ("2TH","2 Thessalonians",2,["thessalonians","thessalonian"],["thess","thes","th"],{}),
 ("1TI","1 Timothy",1,["timothy"],["tim","ti"],{}),
 ("2TI","2 Timothy",2,["timothy"],["tim","ti"],{}),
 ("TIT","Titus",None,["titus"],["tit"],{}),
 ("PHM","Philemon",None,["philemon"],["philem","phm"],{}),
 ("HEB","Hebrews",None,["hebrews"],["heb"],{}),
 ("JAS","James",None,["james"],["jas","jm"],{}),
 ("1PE","1 Peter",1,["peter"],["pet","pe","pt"],{}),
 ("2PE","2 Peter",2,["peter"],["pet","pe","pt"],{}),
 ("1JN","1 John",1,["john"],["jn","jhn"],{}),
 ("2JN","2 John",2,["john"],["jn","jhn"],{}),
 ("3JN","3 John",3,["john"],["jn","jhn"],{}),
 ("JUD","Jude",None,["jude"],["jud"],{}),
 ("REV","Revelation",None,["revelation","revelations"],["rev","re"],{}),
]

def main(src):
    kjv = json.load(open(src, encoding="utf-8-sig"))
    assert len(kjv) == 66 == len(B)
    books, vers, text = [], {}, {}
    for (bid, name, ordinal, names, abbr, extra), src_book in zip(B, kjv):
        chapters = src_book["chapters"]
        entry = {"id": bid, "name": name, "ordinal": ordinal, "names": names, "abbr": abbr,
                 "chapters": len(chapters), "risky": bool(extra.get("risky")),
                 "mishearings": extra.get("mishearings", [])}
        if "singular" in extra: entry["singular"] = extra["singular"]
        books.append(entry)
        vers[bid] = [len(c) for c in chapters]
        text[bid] = [[v.strip() for v in c] for c in chapters]
    assert sum(sum(v) for v in vers.values()) == 31102
    dump = lambda name, obj, **kw: json.dump(obj, open(os.path.join(OUT, name), "w", encoding="utf-8"), ensure_ascii=False, **kw)
    with open(os.path.join(OUT, "books.json"), "w", encoding="utf-8") as f:
        f.write("[\n" + ",\n".join(" " + json.dumps(b, ensure_ascii=False) for b in books) + "\n]\n")
    with open(os.path.join(OUT, "versification.json"), "w", encoding="utf-8") as f:
        f.write("{\n" + ",\n".join(' %s: %s' % (json.dumps(k), json.dumps(v, separators=(",", ":"))) for k, v in vers.items()) + "\n}\n")
    with open(os.path.join(OUT, "kjv.json"), "w", encoding="utf-8") as f:
        f.write("{\n" + ",\n".join(' %s: %s' % (json.dumps(k), json.dumps(v, ensure_ascii=False, separators=(",", ":"))) for k, v in text.items()) + "\n}\n")

if __name__ == "__main__":
    main(sys.argv[1])
