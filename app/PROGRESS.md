# Build progress (working file for resuming; delete when the build is finished)

Branch `app-build`, everything inside `app/`. Never touch main or website files.
Python tests: `python3 engine-python/run_tests.py` must end `0 failed` (119 cases now).
No Swift compiler here. Every Swift file starts with an UNTESTED line.
Rounds 1 and 2 are done and pushed (see README, DECISIONS 1-53).

## Round 3 (Bryson, Nov 11 afternoon). Work top to bottom, commit + push after each, tick here.
Bryson's words: the preview "looks a lot blander and less designed" than the manual; "I want each screen on my manual to be exactly what the user sees."
ROOT CAUSE: rounds 1-2 used only `pdftotext` of ../manual/Word-Cue-User-Guide.pdf and never looked at the figures.

- [ ] R1 Read every figure in the manual AS IMAGES (Read tool, `pages:` param, a few pages at a time; figures are on pages 3, 6-7 setup, 8-9 service view + compact, 10 states, 12 file drop, 16 settings search, 17-33 one settings panel each) and write what each looks like into "Figure notes" below BEFORE coding (colours, spacing, type sizes, exact labels, icons, layout). Then rebuild preview/index.html so each screen matches its figure. Republish the artifact: write the body (no doctype/html/head/body tags) to a scratchpad file and call Artifact with url https://claude.ai/artifact/SenUmXooRweu9oSHottnmV (read it first if this session has not published it). The repo copy preview/index.html = same body wrapped in a full HTML document.
- [ ] R2 Bring the SwiftUI screens in line with the same figures (WordCue/Views/*.swift).
- [x] R3 File import stays in Word Cue: dropped-file verses go to a list inside Word Cue, each with a go-live button; do NOT push them into the presentation app's service list (remove the addToServiceList attempt in AppModel.importFiles; keep Undo). Note that manual section 06 needs rewording. Add to DECISIONS.
- [ ] R4 EasyWorship 8 IS a Mac app (Bryson confirmed; my "Windows only" note in DECISIONS 42 was wrong - fix it). Look up its Mac Bible-search shortcut and bundle identifier (web search), set them in Settings.swift / keyboardOpenSearch default for EasyWorship.
- [ ] R5 Tune quoted-scripture matching ("semantic search"): catch looser quotes/paraphrase (e.g. "seek the kingdom of God first" = Matt 6:33; modernised words hath/has, thee/you; allow gaps). Python first, cases, then Swift.
- [ ] R6 Wire Standard/Enhanced speech switch; wire the editable "require a chapter number" list; keep the sidebar off the projector (place the window on the screen that is NOT the presentation output: prefer the screen with the menu bar / built-in display; add a "Word Cue screen" picker).
- [ ] R7 App licence file ("Free & Source-Available": free to use, source public to read, all rights reserved). Model it on the wording of ../License. Mark it as a draft for Bryson to review.
- [ ] R8 Add Proclaim to the presentation apps list (keyboard adapter unless it has an API - check).
- [ ] R9 "Bible text via the app's own search": to get NKJV/ESV etc without licensing, let Word Cue type the reference into the presentation app's Bible search and send it live (that is what KeyboardAdapter does). Make it a per-church choice: "Verse text from: Word Cue (KJV) / my presentation app's Bible". Write up how stable/secure it is in docs/CONNECTIONS.md.
- [ ] R10 Later/large, only if usage allows, each as its own commit: detection-engine chooser in Settings (rules / Apple Foundation Model second opinion; speech: Apple / other), Create ML tagger scaffold (training-data export from Lab), iPhone/iPad companion app target.
- [ ] R11 Update docs, README, DECISIONS; delete this file.

## Answers already given to Bryson (do not re-argue)
- Rules vs Foundation Model: 31/31 on 3 sermons, 0 false alarms, 2 wrong verse from speech-to-text, 1 dropped under 70% (correctly), 19 quote matches. I am biased (wrote the rules, tuned on the same sermons, never ran the model). Plan: rules stay the engine, model as second opinion, compare on the Mac.

## Figure notes (fill in during R1)
