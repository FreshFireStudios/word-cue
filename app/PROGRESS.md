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
- [~] A2 (Settings.swift written with every manual setting + defaults; uses plain synthesized Codable, so a settings file missing a key will fail to import - make decoding tolerant; AppSettings in the app still uses the old round-1 fields and must be switched to WordCueSettings) Kit: settings model matching manual section 08 (all 9 panels), Codable, export/import, defaults from the manual.
- [x] A3 (done, pushed; Swift mirrored; 119 cases pass in Python) Engine: filters (ignored phrases, ignored books, editable require-chapter list), confidence re-tuned so manual's 70% minimum shows bare chapters and follow-ons; quoted-scripture matcher (Beta) in Python first, then Swift; add cases.
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

## Where I stopped (Nov 11, about 7:15 am Mountain, usage at 85%)
- Next up: A1 adapters. Verified facts: FreeShow API = POST http://localhost:5506 with JSON {"action":"start_scripture","reference":"John 3:16"}; also scripture_next, scripture_previous, clear_slide, clear_all, create_show {text,name}; optional header Authorization: Bearer KEY (source: freeshow.app/api; WebSocket is 5505).
- OpenLP could NOT be verified (gitlab blocked). From memory, mark VERIFY: GET /api/v2/plugins/bibles/search?text=John+3:16 -> list of [id, title]; POST /api/v2/plugins/bibles/live {"id": id}; POST /api/v2/plugins/bibles/add {"id": id}; POST /api/v2/core/display {"display":"blank"}; GET /api/v2/core/system; port 4316.
- Adapter shape planned: protocol PresentationAdapter { name; test(); show(VerseItem); addToServiceList(VerseItem); clear() } in the Kit; KeyboardAdapter (CGEvent typing, needs Accessibility) in the app; an OutputRouter in the app picks API first, then keyboard, per settings.connectionMethod.
- Quote matcher results on the 3 sermons were all real verses (Acts 2:2, Luke 11:25-26, 1 Cor 15:56-57, 2 Cor 10:5, Matt 16:18, Acts 1:5, 2 Kings 5:2-3 ...). Add this to docs/RESULTS.md.
- docs/RESULTS.md and DECISIONS.md still describe round-1 scores (60% for bare chapter / follow-on, 50% hide level). Update: bare chapter 75%, follow-on 72%, hide below 70%, auto-send 95%.
- Add a Swift test: Engine.gramHash(["for","god","so","loved"]) == 0xdd9b2a1e8a78ae70.
- Sermon transcripts live only in the scratchpad (may be gone after a reset); Bryson will transcribe the rest himself and run_transcript.py now accepts plain .txt.
