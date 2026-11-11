# Build progress (working file for resuming; delete when the build is finished)

Branch `app-build`, everything inside `app/`. Never touch main or website files.
Spec to build toward: `../manual/Word-Cue-User-Guide.pdf` (39 pages; text via `pdftotext -layout`).
Python tests: `python3 engine-python/run_tests.py` must end `0 failed`.
No Swift compiler here. Every Swift file starts with an UNTESTED line.

## Done (pushed)
- [x] Round 1: engine (Python tested + Swift mirror), KJV, ProPresenter client, first app screens, preview, docs.

## Round 2 plan (Bryson, Nov 11: "build everything, both apps, connections and integrations")
Work top to bottom. Commit + push after each item. Tick it here.
- [ ] A1 Kit: `PresentationAdapter` protocol + adapters: ProPresenter (exists), OpenLP (Remote API :4316), FreeShow (API :5505), Keyboard (EasyWorship/Other via Accessibility keystrokes). Automatic = API first, then keyboard.
- [ ] A2 Kit: settings model matching manual section 08 (all 9 panels), Codable, export/import, defaults from the manual.
- [ ] A3 Engine: filters (ignored phrases, ignored books, editable require-chapter list), confidence re-tuned so manual's 70% minimum shows bare chapters and follow-ons; quoted-scripture matcher (Beta) in Python first, then Swift; add cases.
- [ ] A4 Kit: ServiceLog (history per service, transcripts retention, export).
- [ ] B1 App: Service View per manual 04/05 (status row, problem banner, Likely Match, Send/Skip, This Service history with Resend, Live Transcript, footer Pause/Clear), all states.
- [ ] B2 App: compact floating panel (corner, opacity, on top), menu bar extra, window pairing with presentation app, show/hide, launch at login, keep awake, confirm quit.
- [ ] B3 App: shortcuts per manual (Return, esc, space, Cmd-B, Cmd-R, Cmd-\, Cmd-Z; Anywhere = Control-Option; Option-Cmd-W), editable.
- [ ] B4 App: first-run setup (5 steps), Settings window with 9 panels + search.
- [ ] B5 App: file drop -> queue/service list with Undo; practice session (run a recorded sermon file); feedback + diagnostics; Sparkle hook (package not added until keys exist).
- [ ] C1 Word Cue Lab app target: import audio, transcribe on device, run engine, review detections against transcript, mark corrections, export new cases for cases.json.
- [ ] C2 Lab MCP connector: small stdio MCP server target so Claude can read Lab sessions and run the detector. Config snippet in docs.
- [ ] D1 Xcode project: add Lab + MCP targets; update preview page, README, CLAUDE.md, DECISIONS.md; delete this file.

## Design notes worth keeping
- Manual defaults: min confidence 70%, auto-send 95% (range 80-100), cooldown 60 s, dismiss unsent after 30 s, sidebar fixed ~380 px right edge full height, compact panel top right 95% opacity.
- Status colours: green healthy, yellow verse waiting, red problem. States: Ready, Listening, Likely Match, Verse waiting (15 s), Auto-sent, Paused, App lost connection (keep listening), No audio.
- Shortcuts: Send Return / Skip esc / Pause space / Clear Cmd-B / Resend Cmd-R / compact Cmd-\ / undo drop Cmd-Z; Anywhere adds Control-Option; show-hide Option-Cmd-W.
- Fonts: SF Pro UI, Plus Jakarta Sans wordmark only. Colours in WordCue/Views/Theme.swift (from the website).
- Manual says detection uses Apple's Foundation Model; round 1 chose plain rules (DECISIONS 5). Keep rules as the engine; add the model only as an optional, off-by-default second opinion if time allows.
- ProPresenter API has no Bible command (docs/PROPRESENTER-API.md): Message tokens primary.
- Bryson will transcribe the remaining sermons himself; `engine-python/run_transcript.py` accepts JSON list or JSON lines of {start,end,text}; plain .txt support would help him (add).
- Swift mirrors Python function-for-function; change Python first.
