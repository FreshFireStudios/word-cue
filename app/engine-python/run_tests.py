#!/usr/bin/env python3
"""Runs the shared test cases against the Python reference engine.

    python3 engine-python/run_tests.py

Also checks that feeding the text one word at a time (the way live speech
arrives) ends with the same answers as reading it all at once.
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wordcue_engine import Engine, Session, KJV, tokenize

HERE = os.path.dirname(os.path.abspath(__file__))
CASES = os.path.join(HERE, "..", "WordCueKit", "Tests", "WordCueKitTests", "Resources", "cases.json")


def stream_keys(engine, text, mode, small=False, quotes=False):
    s = Session(engine, mode)
    s.quotes = quotes
    if small:
        s.MAX_TOKENS, s.KEEP_TOKENS = 40, 10
    latest = {}
    for word in text.split(" "):
        for kind, d in s.feed(word):
            if kind == "remove":
                latest.pop(d, None)
            else:
                latest[d.start] = d.key
    return [latest[k] for k in sorted(latest)]


def main():
    engine = Engine()
    cases = json.load(open(CASES, encoding="utf-8"))["cases"]
    failed = 0
    for c in cases:
        quotes = c.get("quotes", False)
        engine.set_filters(c.get("ignoredBooks", ()), c.get("ignoredPhrases", ()))
        got = [d.key for d in engine.detect(c["text"], c["mode"], quotes=quotes)]
        streamed = stream_keys(engine, c["text"], c["mode"], quotes=quotes)
        engine.set_filters()
        ok = got == c["expect"] and streamed == c["expect"]
        if not ok:
            failed += 1
            print("FAIL %s\n  text:     %s\n  expected: %s\n  got:      %s\n  streamed: %s" % (c["id"], c["text"], c["expect"], got, streamed))
    # long-run check: all speech cases as one stream, with a tiny buffer so trimming is exercised
    speech = [c for c in cases if c["mode"] == "speech" and len(c) <= 5 and not c.get("quotes")
              and "ignoredBooks" not in c and "ignoredPhrases" not in c]
    joined = " . ".join(c["text"] for c in speech)
    whole = [d.key for d in engine.detect(joined)]
    trimmed = stream_keys(engine, joined, "speech", small=True)
    if whole != trimmed:
        failed += 1
        print("FAIL long-stream: trimming changed the answers\n  whole:   %s\n  trimmed: %s" % (whole, trimmed))
    # KJV lookup spot checks
    kjv = KJV()
    assert kjv.verses("ACT", 2, 38)[0][1].startswith("Then Peter said unto them, Repent, and be baptized")
    assert [v for v, _ in kjv.verses("ACT", 2, 38, 39)] == [38, 39]
    assert len(kjv.verses("PSA", 117)) == 2
    print("%d cases, %d failed" % (len(cases) + 1, failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
