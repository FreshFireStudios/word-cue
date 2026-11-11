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
12. **Scripture quoted without a reference is not detected.** That needs text matching and is left for later.
13. **Document mode** (dropped files) also accepts abbreviations like "Jn 3:16" and lists like "Acts 2:38; 4:12". Cross-chapter ranges ("John 3:16–4:2") are not handled.

## Scores

14. **Score levels:** 95% for an explicit verse, 85% for "N and M" style, 80% for "chapter N", 60% for a bare "Luke 24" or a follow-on, with deductions for misheard names and guesses. All of it lives in `rules.json`.
15. **Suggestions under 50% are hidden** (adjustable in Settings).
16. **Auto-send is off.** When a church turns it on, the default bar is 90% and it only applies to verse-level matches, never whole chapters.

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
