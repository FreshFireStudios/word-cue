#!/usr/bin/env python3
"""Runs the detector over a timed transcript and prints what it found.

    python3 engine-python/run_transcript.py transcript.json

The file holds {"start": seconds, "end": seconds, "text": "..."} segments,
either as one JSON list or one object per line (what tools/transcribe.py writes). Segments are fed in order through
a live Session, the same way the Mac app feeds finalized speech.
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wordcue_engine import Engine, Session, tokenize


def run(path, engine=None):
    engine = engine or Engine()
    session = Session(engine)
    rows = {}
    raw = open(path, encoding="utf-8").read().strip()
    segments = json.loads(raw) if raw.startswith("[") else [json.loads(line) for line in raw.splitlines()]
    for seg in segments:
        for kind, d in session.feed(seg["text"]):
            if kind == "remove":
                rows.pop(d, None)
            else:
                first = rows.get(d.start, {}).get("time", seg["start"])
                rows[d.start] = {"time": first, "key": d.key, "display": engine.display(d),
                                 "confidence": d.confidence, "kind": d.kind, "flags": d.flags, "text": d.text}
    return [rows[k] for k in sorted(rows)]


if __name__ == "__main__":
    for path in sys.argv[1:]:
        print(os.path.basename(path))
        for r in run(path):
            print("  %2d:%02d  %-22s %.2f  %-8s %s  <- %r" % (r["time"] // 60, r["time"] % 60, r["display"],
                  r["confidence"], r["kind"], ",".join(r["flags"]), r["text"]))
