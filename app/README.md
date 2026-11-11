# Word Cue app

The Mac app. The website lives in the folder above this one and is not touched from here.

**Status: first build, written without a Mac. The detection logic is tested. The Swift code has never been compiled.**

## What is where

| Folder | What it holds | Tested? |
|---|---|---|
| `WordCueKit/` | The engine as a Swift package: detection, KJV lookup, ProPresenter client, shared rule files | Swift: no. Rules: yes, through Python |
| `WordCueKit/Sources/WordCueKit/Resources/` | `books.json`, `numbers.json`, `rules.json`, `versification.json`, `kjv.json`. Both engines read these | Yes |
| `WordCueKit/Tests/WordCueKitTests/Resources/cases.json` | 110 shared test cases | Python passes all |
| `engine-python/` | The Python reference engine and its test runners | Yes |
| `WordCue/` | The macOS app: SwiftUI screens, microphone input, Apple speech | No |
| `WordCue.xcodeproj` + `Config/` | Xcode project, Info.plist, entitlements | No |
| `preview/index.html` | Clickable preview of the screens | Open it in a browser |
| `docs/` | ProPresenter API findings, results report, Apple speech notes | |
| `tools/` | Scripts that built the data files and transcripts | |
| `DECISIONS.md` | Every call made without asking | |

## Run the detection tests (works anywhere with Python 3)

```
python3 engine-python/run_tests.py
```

Expected last line: `110 cases, 0 failed`.

## First time on the Mac

1. Install Xcode 27 from the App Store.

⋮

2. Open `app/WordCue.xcodeproj`.

⋮

3. Run the engine tests first: in Terminal, `cd app/WordCueKit` then `swift test`. These prove the Swift engine matches the Python one. Fix these before anything else.

⋮

4. In Xcode, pick your team under Signing & Capabilities, then press Run. Expect compile errors in `LiveTranscriber.swift` first; it uses Apple's newest speech API and was written from the documentation alone.

**If Xcode will not open the project:** make a new macOS App project named WordCue (SwiftUI, bundle ID `com.freshfirestudios.wordcue`) inside `app/`, delete its starter files, drag the `WordCue` folder in, add `WordCueKit` with File > Add Package Dependencies > Add Local, and copy the settings from `Config/`.

## Changing a detection rule

1. Add a failing case to `cases.json`.

⋮

2. Change the JSON rule file, or `engine-python/wordcue_engine.py` if it needs logic.

⋮

3. Run the Python tests until they pass.

⋮

4. Copy any logic change into the matching function in `WordCueKit/Sources/WordCueKit/Engine.swift`. The two files are laid out in the same order for this reason.

© 2026 Bryson Woods, Fresh Fire Studios. All rights reserved.
