# Word Cue app

The Mac app. The website lives in the folder above this one and is not touched from here.

**Status: first build, written without a Mac. The detection logic is tested. The Swift code has never been compiled.**

## What is where

| Folder | What it holds | Tested? |
|---|---|---|
| `WordCue/` | **Word Cue**, the operator's app: Service View, compact panel, first-run setup, Settings, audio, speech, connections | No |
| `WordCueLab/` | **Word Cue Lab**, the developer's bench: load a sermon, review detections, export test cases | No |
| `WordCueKit/` | The shared engine as a Swift package: detection, quoted scripture, KJV lookup, settings, service log, presentation adapters, Lab store | Swift: no. Rules: yes, through Python |
| `WordCueKit/Sources/wordcue-lab-mcp/` | The Lab's connector for Claude | No |
| `WordCueKit/Sources/WordCueKit/Resources/` | `books.json`, `numbers.json`, `rules.json`, `versification.json`, `kjv.json`. Both engines read these | Yes |
| `WordCueKit/Tests/WordCueKitTests/Resources/cases.json` | 119 shared test cases | Python passes all |
| `engine-python/` | The Python reference engine and its test runners | Yes |
| `WordCue.xcodeproj` + `Config/` | One Xcode project with both apps, Info.plist, entitlements | No |
| `preview/index.html` | Clickable preview of the screens | Open it in a browser |
| `docs/` | `RESULTS.md`, `PROPRESENTER-API.md`, `CONNECTIONS.md`, `LAB.md`, `SPEECH-NOTES.md` | |
| `tools/` | Scripts that built the data files, transcripts and the Xcode project | |
| `DECISIONS.md` | Every call made without asking | |

The design spec is the User Guide in `../manual/`.

## Run the detection tests (works anywhere with Python 3)

```
python3 engine-python/run_tests.py
```

Expected last line: `119 cases, 0 failed`.

To run the detector over your own transcript (plain text, one line per segment, or JSON):

```
python3 engine-python/run_transcript.py my-sermon.txt --quotes
```

`--quotes` also matches scripture quoted without a reference.

## First time on the Mac

1. Install Xcode 27 from the App Store.

⋮

2. Open `app/WordCue.xcodeproj`.

⋮

3. Run the engine tests first: in Terminal, `cd app/WordCueKit` then `swift test`. These prove the Swift engine matches the Python one. Fix these before anything else.

⋮

4. In Xcode, pick your team under Signing & Capabilities for both targets. Choose the **WordCue** scheme and press Run. Expect compile errors: about 6,000 lines of Swift here have never met a compiler. `LiveTranscriber.swift` is the likeliest place, since it uses Apple's newest speech API and was written from the documentation alone.

⋮

5. Then choose the **WordCueLab** scheme and run that. `docs/LAB.md` covers the Lab and its Claude connector, and `docs/CONNECTIONS.md` lists what to check for each presentation app.

**If Xcode will not open the project:** make a new macOS App project named WordCue (SwiftUI, bundle ID `com.freshfirestudios.wordcue`) inside `app/`, delete its starter files, drag the `WordCue` folder in, add `WordCueKit` with File > Add Package Dependencies > Add Local, and copy the settings from `Config/`. Add a second app target for `WordCueLab` the same way.

## Changing a detection rule

1. Add a failing case to `cases.json`.

⋮

2. Change the JSON rule file, or `engine-python/wordcue_engine.py` if it needs logic.

⋮

3. Run the Python tests until they pass.

⋮

4. Copy any logic change into the matching function in `WordCueKit/Sources/WordCueKit/Engine.swift`. The two files are laid out in the same order for this reason.

© 2026 Bryson Woods, Fresh Fire Studios. All rights reserved.
