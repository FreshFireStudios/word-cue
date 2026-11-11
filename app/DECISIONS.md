# Decisions made while Bryson was away

*Overnight build, November 10–11, 2026. Each line is a call I made without asking. Change any of them.*

## Scope and safety

1. **Sermon transcripts and audio are not in the repo.** The repo is public, and the transcripts name church members and children. Only short reference phrases (no names) went into the test cases. The full transcripts exist only in the cloud workspace, which is temporary.
2. **Nothing outside `app/` was touched.** The root `README.md` and the website still say OpenLP. I left them, since those are website files.
3. **Bundle ID stays `com.freshfirestudios.wordcue`** as the handoff says. If the studio becomes Apostolic Design Studio, decide before the first public release: a bundle ID is hard to change once people have installed the app.
4. **No licence file for the app yet.** The site licence says the app gets its own. That is a legal document and yours to write. Until then the code is all rights reserved by default.

## Detection

5. **Rules, not an AI model.** The detector is a set of plain rules reading shared JSON files. It is fast (about 2 ms), gives the same answer every time, and can be tested without a Mac. The Create ML tagger stays a later phase.
6. **"Luke 11 and 23" means Luke 11:23.** In preaching, "chapter and verse" is far more common than "chapters 11 and 23".
7. **A book with no chapter gives no suggestion.** "In Corinthians..." is ignored.
8. **A numbered book said without its number** ("Samuel 2 and 8") reuses the last one heard, else assumes 1, at a lower score.
9. **Follow-ons are on:** "verse 4", "chapter 3", "the first chapter", "the next verse" lean on the last reference for about 600 words, at a 60% score.
10. **The same reference within about 30 words is reported once.**
11. **Impossible references are dropped** using a table of how many verses each chapter has. "Acts 2 verse 99" becomes Acts 2.
12. **Scripture quoted without a reference** was left out of round 1 and added in round 2 as a Beta switch, off by default (see decision 36).
13. **Document mode** (dropped files) also accepts abbreviations like "Jn 3:16" and lists like "Acts 2:38; 4:12". Cross-chapter ranges ("John 3:16–4:2") are not handled.

## Scores

14. **Score levels:** 95% for an explicit verse, 85% for "N and M" style, 80% for "chapter N", 75% for a bare "Luke 24", 72% for a follow-on, with deductions for misheard names and guesses. All of it lives in `rules.json`. (Round 2 raised the last two so they clear the manual's 70% minimum.)
15. **Suggestions under 70% are hidden,** as the manual says (adjustable in Settings).
16. **Auto-send is off.** When a church turns it on, the default bar is 95%, as the manual says, and it only applies to verse-level matches, never whole chapters.

## ProPresenter

17. **Verses go out as a ProPresenter Message with fill-in blanks**, because the API has no Bible command. Details in `docs/PROPRESENTER-API.md`.
18. **Fallback is copy-and-switch:** copy the reference, bring ProPresenter forward, operator pastes into Bible search. Scripted keystrokes are not built.
19. **Dropped files fill Word Cue's own list,** not ProPresenter's playlist. The API cannot create Bible slides, so "send to the service list" is not possible through it.
20. **A range or chapter is sent one verse at a time,** paged with the arrow keys.

## Bible text

21. **King James Version is bundled** (public domain in the United States; the Crown holds rights in the UK). Source: the `en_kjv.json` file from github.com/thiagobodruk/bible, checked to have all 31,102 verses. Other translations need licences.

## App

22. **The Xcode project file was written by hand** using Xcode 16's folder-synced groups, so every file in `app/WordCue/` is included automatically. If Xcode refuses to open it, the README has a two-minute fallback.
23. **Swift 5 language mode,** not Swift 6, so untested code hits fewer strict-concurrency errors on the first build.
24. **Not sandboxed, hardened runtime on,** with the audio-input entitlement, matching direct download plus notarization.
25. **Sparkle is not added yet.** It needs a signing key pair and an update-feed address, which should be made on your Mac.
26. **Problem reports save to this Mac only.** Sending them to your Google account as Google Docs needs a small Apps Script endpoint, like the one behind the launch-notify sheet. There is a marked spot for its address in `FeedbackReporter.swift`.
27. **Global shortcuts use Control-Option** (Return, Delete, arrows, Period) so they work while ProPresenter is in front. In-window shortcuts are plain Return, Delete, arrows and Escape.
28. **System font and the website's dark palette.** Plus Jakarta Sans is not bundled, to keep the Apple-like feel in controls. Easy to change in `Theme.swift`.
29. **Audio capture uses AVAudioEngine** with an input-device picker. Apple's newer `CaptureInputSequenceProvider` may be simpler; see `docs/SPEECH-NOTES.md`.

## Tools

30. **Transcripts were made with Whisper (small English model)** through sherpa-onnx, the only speech model reachable from the cloud workspace. It stands in for Apple's recogniser and will not make the same mistakes.
31. **No Swift was compiled.** A Swift toolchain download was tried and could not be run in the workspace. Every Swift file is marked UNTESTED at the top.

## Round 2 (November 11, built from the User Guide)

32. **The User Guide is the spec.** Where round 1 and the guide disagreed, the guide won: fixed 380-point sidebar on the right edge, Likely Match with Send and Skip, This Service history, nine Settings panels, the guide's shortcuts and defaults.
33. **The guide says detection uses Apple's on-device Foundation Model. The build still uses plain rules.** Rules passed every test here, run in about 2 ms, and cannot refuse a passage. Apple's model could not be tried without a Mac. If you want it, it fits as a second opinion on low-score matches. The guide's wording in section 07 should change, or the model should be added.
34. **Speech engine "Standard" and "Enhanced" do the same thing for now.** Both use Apple's `SpeechTranscriber`. The switch is saved but not wired, because I could not confirm which Apple API "Standard" should map to.
35. **Translations: KJV only.** The NKJV and ESV choices in the guide are not offered, because both are licensed. A second translation is not built.
36. **Quoted scripture (Beta)** needs about eight words in a row from one verse. If the same words are in several verses and no chapter was just named, it gives no suggestion.
37. **"Require a chapter number" is always on for every book.** No book name alone ever triggers a verse. The editable list in Filters is saved but changes nothing yet; today it only matters for scoring inside the engine.
38. **One Likely Match at a time.** If a new verse is heard while one is waiting, the older one moves to This Service marked "Not sent" and can still be sent from there.
39. **Duplicate cooldown is by time** (60 seconds, in the app) on top of the engine's own 30-word rule.
40. **OpenLP is written from memory.** Its documentation site blocked me. Every OpenLP call is marked VERIFY. ProPresenter and FreeShow come from their official API pages.
41. **FreeShow port is 5506** (its HTTP API), not 5505 (its WebSocket). FreeShow looks the verse up in its own Bible.
42. **EasyWorship and "Other" work by typing.** Word Cue brings the app forward and types the reference, then Return. A setting holds the key that opens that app's Bible search; I do not know EasyWorship's, so it starts empty. Note that EasyWorship is a Windows program; confirm it is really a target on the Mac.
43. **"Add to the service list" works only where the app allows it:** OpenLP (unverified) and FreeShow (as a new show). ProPresenter's API cannot, so dropped files land in This Service and are sent from there.
44. **Undo for a file drop** removes the verses from Word Cue.
45. **Not built from the guide:** Snap app beside Word Cue, ProPresenter port auto-discovery, the Spanish language model check, re-download/reset of the speech model (macOS manages it), and Sparkle itself (the hook is in `Updater.swift`).
46. **"Pause during music"** uses Apple's built-in sound classifier. The label names it listens for are unverified.
47. **Pairing** brings Word Cue forward when the presentation app comes forward, without taking the keyboard. Sending them to the back together is left to macOS.
48. **The sidebar goes on the screen the window is already on.** Keeping it off the projector display is up to where the operator first puts it; the guide's promise that it never appears there is not enforced in code.

## Word Cue Lab

49. **Lab is a second app in the same Xcode project,** sharing the engine package, with bundle ID `com.freshfirestudios.wordcuelab`.
50. **The Claude connector is a small command-line program** (`wordcue-lab-mcp`) that Claude starts on your Mac. No API key. It can read Lab sessions, run the detector, record reviews and misses, and propose test cases.
51. **Proposed cases go to a separate file,** not straight into `cases.json`. A person moves the good ones across, so nothing Claude or a church sends changes the engine unreviewed.
52. **Church corrections are text only:** the words heard, what Word Cue suggested, and what the operator says was right. Word Cue's Service Log can export them and the Lab can import them. No way to send them over the internet is built.
53. **Transcripts shown to Claude leave the Mac.** The Lab says so on its connector screen. Keep only shareable sermons in the Lab.

## Round 3 (November 11, afternoon)

54. **Dropped-file verses stay in Word Cue** (Bryson's call). They are listed in This Service in file order, each with a Send button that puts it live. Nothing is pushed into the presentation app's own service list. This is the same for every app. Section 06 of the User Guide still says the verses go into the presentation app and needs rewording.
