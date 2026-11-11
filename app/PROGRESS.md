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
- [x] R4 EasyWorship: Page Down = Go Live, Control-C = text off (from help.easyworship.com). No documented search-focus key, no Mac-specific keys listed, bundle id still a guess: all noted in DECISIONS 55.
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

### Seen so far: pages 8-9 only (Figures 7 and 8). Pages 3, 6-7, 10, 12, 16-33 still to read.
General look (both figures): DARK window, near-black warm charcoal (#232220-ish) with rounded outer corners ~14px, sitting on a light warm-grey rounded card in the manual. Text off-white. All buttons are fully rounded PILLS. Orange (#C2611F-ish, the brand burnt orange) is the Send colour; amber/gold for small accents (KJV tag, mic bars, "Waiting for you"). Green only for healthy status. Type is a clean geometric sans (SF Pro in app), medium weights, small sizes; lots of air; hairline dividers at low opacity.

Figure 7, full sidebar, top to bottom:
1. Title bar: real traffic lights (red/yellow/green), then small flame icon + "Word Cue" wordmark (semibold, ~13px). Right: ONE dark rounded pill holding two icons: compress/arrows-in (compact) and a gear/sun-like settings icon.
2. Status row: pill "● Listening" = dark green tinted pill, green dot, green text. Next to it a tiny 5-6 bar audio meter in AMBER (vertical bars of varying height, last ones dimmer), not a horizontal bar. Far right: green circle check icon + "ProPresenter" in white.
3. Likely Match block: left label "Likely Match" (small, grey, sentence case, not uppercase). Right: "● High confidence" in green with green dot (WORD, not a percent). Then "John 3:16" large bold white (~22-24px) with "KJV" small amber superscript-ish tag beside it. Under it "● Waiting for you · 15 seconds" in amber/yellow with dot. Then verse text in the SANS face (not serif), light grey-white, ~12px, 3 lines.
4. Buttons row: "Send ↩" wide ORANGE pill (about 2/3 width, white bold text, return glyph), then "Skip esc" dark-grey pill (1/3), "esc" dimmer.
5. Hairline divider. "This Service" label left (small grey), count "7" right.
6. History rows, each separated by a hairline: reference left in white medium (~12px); right side: time "10:42" in grey, then a small circular-arrows RESEND ICON (not a text button). A skipped row is dimmed, with "Skipped" small grey tag before the time. Rows shown: Romans 10:9, Acts 2:38, Ephesians 4:5 (Skipped), Acts 2:4, Joel 2:28, Acts 4:12, John 3:5.
7. Bottom: hairline; row "› Live Transcript" (chevron, label) with a small toggle switch on the right (off).
8. Footer: two pills side by side: "Pause space" (dark grey pill, "space" dimmer) and "Clear Screen ⌘B" in RED-ORANGE text on a dark reddish-tinted pill.

Figure 8, compact panel (dark rounded card, ~290x145):
Row 1: "● Listening" green pill, amber mic bars, then right: green check + "ProPresenter", and a round dark button with expand arrows.
Row 2: "John 3:16" bold + amber "KJV"; right "● High confidence" green.
Row 3: first line of the verse, one line, ellipsis.
Row 4: "Send ↩" orange pill (wide), "Skip esc" grey pill, and a small round dark button with a red clear-screen icon (x in a rectangle).
Disconnected variant: no Listening pill shown; right side red x-circle + "OpenLP"; then a dark-red banner row: warning triangle, "OpenLP lost connection" in salmon, and a "Reconnect" grey pill at right; rest the same.

So the app is DARK-FIRST in the manual (my round-2 preview used system/light and looked generic). Confidence shows as words ("High confidence"), history uses icon buttons, meter is bars.

### Pages 10-12 (Figures 9, 10, 11) seen.
Empty Likely Match area (Ready / Listening / Paused / No audio): label "Likely Match", then a ROW: small rounded-square dark icon tile (sparkle/asterisk glyph) + grey one-line message to its right ("Start listening to catch verses as they're preached." / "Listening for scripture..." / "Paused. Nothing is being detected until you resume." / "Waiting for audio from the soundboard"). It is a short block, NOT a tall centred area; This Service follows right under it.
This Service empty: label + "0" at right, then grey "Verses appear here as they're sent."
Ready state: status pill is GREY "● Ready"; no mic bars; footer primary button "Start Listening space" is an ORANGE pill (same orange as Send). Paused: grey "● Paused" pill; footer "Resume space" ORANGE pill. Listening: footer "Pause space" dark-grey pill. Clear Screen pill always at right, red-tinted.
Likely Match fresh: under the reference a grey line "Heard 4 seconds ago"; when waiting 15 s it becomes amber "● Waiting for you · 15 seconds".
Auto-sent: Likely Match area back to "Listening for scripture..."; top history row shows amber "Auto-sent" tag before the time.
App lost connection (FreeShow shown): status pill still green Listening; app name at right with RED x-circle. Dark-red rounded banner under the status row: warning triangle, bold "FreeShow lost connection", small text "Verses can't be sent until it's back. Word Cue is still listening.", and a grey "Reconnect" pill at right. Send and Skip dimmed.
No audio: RED "● No audio" pill. Banner: "No audio from [Soundboard Interface]", "Check the USB cable and that the pulpit channel is up on the board.", grey pill "Audio Settings". Likely Match row says "Waiting for audio from the soundboard".
Figure 11 drag: whole sidebar dimmed with an orange DASHED rounded border inset; centre: orange rounded-square tile with a download arrow, bold "Drop to add verses", small grey "Every reference goes straight into EasyWorship's service list, in order." (REWORD per R3: "...is added here, in order."), tiny "PDF · Image · Text".
After drop: a centred floating dark rounded CARD (toast) over the list: big green check circle, bold "6 verses added to EasyWorship" (REWORD per R3: "6 verses added"), small grey "From sermon-notes.pdf", and a grey pill "Undo ⌘Z".

### Pages 6-7 (Figures 2-6, setup) seen.
Setup window: dark, landscape (~560x470), traffic lights top-left, everything CENTRED. Top: a small rounded-square icon tile (orange-tinted for Welcome/Audio with flame/mic glyph; green-tinted shield-check for Allow access and You're all set; blue-tinted display icon for Connect). Under it a bold centred title ("Welcome to Word Cue", "Allow access", "Choose your audio", "Connect your presentation app", "You're all set") and a centred grey 1-2 line subtitle. Then ONE grouped card (slightly lighter dark, rounded ~10px) holding rows separated by hairlines; each row = small coloured rounded-square icon tile + bold label + grey sub-label, with the control or status at the right:
- Welcome rows: "Hears the sermon / From your soundboard, transcribed on this Mac." · "Finds the verses / Spoken and written references, in real time." · "You send them / Every verse waits for you by default."
- Allow access rows: Microphone (right: green dot "Allowed") · Speech Recognition (right: orange "Allow" pill). Below card, tiny grey centred note "Accessibility is only requested later, if Word Cue needs it."
- Audio rows: "Audio interface" (right: dark select pill "[Your soundboard interface]") · "Input channel" (right: select "Channel 1 — Pulpit") · "Live level" with a thin ORANGE horizontal bar under it and at right green dot "Speech detected".
- Connect rows: "Presentation app" (right: select pill "OpenLP") · three numbered steps with small orange number tiles ("1 Open OpenLP on this Mac." "2 In OpenLP's settings, turn on Remote." "3 Come back here. Word Cue connects automatically.") · "Connected to OpenLP / Using OpenLP's API" with green tile and a grey "Test" pill at right.
- Done rows: Audio / Speech recognition / OpenLP each with green dot "Ready" at right, then "Launch Word Cue at login" and "Show Word Cue when OpenLP opens" each with an ORANGE toggle (on).
Bottom bar: 5 tiny progress dots at bottom-LEFT (current one orange); at bottom-RIGHT a grey "Back" pill (not on step 1) and an orange "Continue" pill; last step's button reads "Start Using Word Cue".

### Not yet seen: page 3 (Figure 1, sidebar beside presentation app), page 16 (settings search), pages 17, 19, 21, 23, 25, 27, 29, 30, 32 (one Settings panel figure each). Read these next, note them, then build Settings to match.
### Preview rebuild status: Service View / compact / states / drop / setup being rebuilt dark from these notes (see git log). Settings still the round-2 generic version until its figures are read.
