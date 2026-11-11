# Word Cue app: notes for Claude

Read `README.md`, `DECISIONS.md` and `docs/` before changing anything.

## Product decisions (settled, do not re-ask)

- Mac only, Apple Silicon, macOS 27 minimum. Direct download, notarized, Sparkle updates. Not the App Store.
- "Free & Source-Available": free, source public, all rights reserved.
- A scripture companion beside the presentation app, not a presentation app.
- Resizable sidebar plus compact mode. Keyboard shortcuts are a must. No in-app search box.
- Operator review is always the default. Auto-send is optional and off.
- First target: ProPresenter, through its API, with a fallback.
- Latency goal: 1 to 2 seconds from the microphone to the suggestion.
- Use Apostolic scripture examples in all materials (Acts 2:38, John 3:5, Acts 4:12, Deuteronomy 6:4).
- Bundle ID: `com.freshfirestudios.wordcue`.

## Rules for working here

- Work on the `app-build` branch. Never merge into `main`. Never change files outside `app/`.
- Check Apple documentation first. Ask Bryson before using other sources.
- The Python engine in `engine-python/` is the answer key. Any logic change goes there first, then into `Engine.swift`, and both must pass `cases.json`.
- Rules belong in the shared JSON files, not in code, whenever possible.
- Sermon audio and full transcripts never go in this public repo.
- Remove the `UNTESTED` line at the top of a Swift file only after it compiles and its behaviour has been checked.

## Working with Bryson

- He is learning. Show the exact command or code, then explain simply what each piece does.
- Before he runs any Terminal command, explain in depth what the command and each part does.
- Ask for pasted raw text when troubleshooting, not screenshots.
- No profanity.
