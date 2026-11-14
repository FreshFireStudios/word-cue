# Build progress (working file for resuming; delete when the build is finished)

Branch `app-build`, everything inside `app/`. Never touch main or website files.
Python tests: `python3 engine-python/run_tests.py` must end `0 failed` (119 cases now).
No Swift compiler here. Every Swift file starts with an UNTESTED line.
Rounds 1 and 2 are done and pushed (see README, DECISIONS 1-53).

## Round 3 (Bryson, Nov 11 afternoon). Work top to bottom, commit + push after each, tick here.
Bryson's words: the preview "looks a lot blander and less designed" than the manual; "I want each screen on my manual to be exactly what the user sees."
ROOT CAUSE: rounds 1-2 used only `pdftotext` of ../manual/Word-Cue-User-Guide.pdf and never looked at the figures.

- [x] R1 DONE: all figures read (notes below), preview rebuilt for every screen incl. all 9 Settings panels + search, published as artifact version 4.
- [x] R2 DONE: Theme, Service View, compact, drop, setup, Settings rebuilt to the figures; window placement keeps the sidebar on the operator screen (R6 part 3 done too).
- [x] R3 File import stays in Word Cue: dropped-file verses go to a list inside Word Cue, each with a go-live button; do NOT push them into the presentation app's service list (remove the addToServiceList attempt in AppModel.importFiles; keep Undo). Note that manual section 06 needs rewording. Add to DECISIONS.
- [x] R4 EasyWorship: Page Down = Go Live, Control-C = text off (from help.easyworship.com). No documented search-focus key, no Mac-specific keys listed, bundle id still a guess: all noted in DECISIONS 55.
- [x] R5 DONE: normalize.json (archaic map, endings, stop words) used by the 4-gram matcher; new loose (paraphrase) matcher in Python + Swift; 125 cases pass; RESULTS + DECISIONS 60 updated. Previews skip quote matching (speed).
- [x] R6 DONE: speech switch (Enhanced=SpeechTranscriber, Standard=DictationTranscriber, VERIFY options); require-chapter list drives engine.riskyBooks (bare "Acts 2" scores lower), toggle off clears it; Recognize switches filter in AppModel.cue; sidebar-off-projector done in R2.
- [x] R7 DONE: app/LICENSE drafted (marked DRAFT, not legal advice).
- [x] R8 DONE: Proclaim added (keyboard). Its App Command API has no Bible command; noted in CONNECTIONS.md.
- [x] R9 DONE: verseSource setting (Word Cue KJV / presentation app Bible); ProPresenter switches to typing when chosen; stability + security write-up in CONNECTIONS.md.
- [~] R10 detection-method chooser (Rules + Apple Intelligence) DONE; Create ML tagger scaffold DONE (Lab export + docs/TAGGER.md); iPhone/iPad companion NOT started (large: new target, Mac/phone link). Do it after the first Mac build works, so there are fewer untested files.
- [ ] R11 Update docs, README, DECISIONS; delete this file.

## Answers already given to Bryson (do not re-argue)
- Rules vs Foundation Model: 31/31 on 3 sermons, 0 false alarms, 2 wrong verse from speech-to-text, 1 dropped under 70% (correctly), 19 quote matches. I am biased (wrote the rules, tuned on the same sermons, never ran the model). Plan: rules stay the engine, model as second opinion, compare on the Mac.

## Where things are
- Figure notes moved to docs/DESIGN-NOTES.md (read only the screen you are changing).
- Mac session plan: when Bryson links his Mac, clone FreshFireStudios/word-cue (branch app-build) into the connected folder, then: `cd app/WordCueKit && swift test` first (engine), then `xcodebuild -project app/WordCue.xcodeproj -scheme WordCue -configuration Debug CODE_SIGN_IDENTITY=- build`, fix errors, repeat; then WordCueLab scheme. Explain every Terminal command to Bryson before running it.
