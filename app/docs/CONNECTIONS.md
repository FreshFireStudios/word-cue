# Presentation app connections

*November 11, 2026. None of these has been run against the real app.*

| App | How Word Cue sends a verse | Source | Confidence |
|---|---|---|---|
| ProPresenter | Official API. No Bible command exists, so the verse goes out as a Message with fill-in blanks | openapi.propresenter.com | Endpoints confirmed; JSON bodies to verify |
| FreeShow | API on port 5506: `{"action": "start_scripture", "reference": "John 3:16"}`. FreeShow shows it from its own Bible | freeshow.app/api | Confirmed from the docs page |
| OpenLP | Remote API on port 4316: search the Bible plugin, then send the result live | Written from memory | **Unverified.** The docs site blocked me |
| EasyWorship, Other | Brings the app forward, types the reference, presses Return. Needs Accessibility | macOS keyboard events | Unverified; needs each app's Bible-search key |

"Automatic" tries the API first and falls back to typing, so a dropped API does not stop the service.

## What each can do

| | Go live | Add to service list | Clear screen | Uses the app's own Bible |
|---|---|---|---|---|
| ProPresenter | Yes | No | Yes | No (Word Cue's KJV) |
| FreeShow | Yes | As a new show (to verify) | Yes | Yes |
| OpenLP | Yes (to verify) | Yes (to verify) | Yes (to verify) | Yes |
| Keyboard | Yes | No | No | Yes |

## To check on the Mac, in this order

1. **ProPresenter:** Test Connection, then send Acts 2:38. If the Message does not appear, compare the JSON in `ProPresenterClient.swift` (marked VERIFY) with the spec.

⋮

2. **FreeShow:** turn on its API in Settings > Connections and send a verse.

⋮

3. **OpenLP:** open `http://localhost:4316/api/v2/core/system` in a browser with Remote turned on. If that works, try a verse; if the Bible search path is wrong, the fix is in `OpenLPAdapter`.

⋮

4. **Bundle IDs:** `PresentationApp.bundleIdentifiers` in `Settings.swift` are my best guesses. They drive "show when the app opens". Check each real one on your Mac.

## Proclaim (added November 14)

| | |
|---|---|
| How Word Cue sends a verse | Keyboard: brings Proclaim forward, types the reference into its Bible search, presses Return |
| Proclaim's own API | Proclaim has an official "App Command API" (turn on a Network Control Password under Settings > Remote). Its commands cover slides, service items, going on and off air, and quick screens such as Blank and Logo. None of them shows a Bible verse, so Word Cue cannot use it to send scripture |
| Later | The API's Blank command could power Word Cue's Clear Screen for Proclaim. Its port and message format still need reading from Faithlife's article, which would not load from here |
| To check on a Mac with Proclaim | The app identifier in `Settings.swift` is a guess; the key that opens Proclaim's Bible search |

Sources: [Proclaim App Command API](https://support.faithlife.com/hc/en-us/articles/4972373093005-Proclaim-App-Command-API) (did not load from here), [Bitfocus Companion module for Proclaim](https://github.com/bitfocus/companion-module-logos-proclaim/blob/main/companion/HELP.md), [Faithlife community thread](https://community.logos.com/discussion/comment/1331041)

## Using the presentation app's own Bible (added November 14)

Word Cue only includes the King James text, because NKJV, ESV and most other translations are licensed. A church that owns another translation inside its presentation app can pick **Settings > Scripture Detection > Verse text from: [app]'s Bible**. Then Word Cue sends the *reference*, and the presentation app shows its own text.

| App | How it works with this setting |
|---|---|
| FreeShow, OpenLP | Already this way: their APIs look the reference up in the app's own Bible |
| ProPresenter, EasyWorship, Proclaim, Other | Word Cue brings the app forward and types the reference into its Bible search, then Return |

**How stable is typing?** Less than an API.

- It depends on the app's Bible search being ready: the right box selected, or a known key that opens it.
- It breaks if the app changes its layout or keys in an update.
- Word Cue cannot confirm the verse went live; the operator has to watch.
- It takes the keyboard for about half a second, so an operator typing at that moment can collide with it.

**How secure is it?**

- It needs macOS Accessibility permission, which lets Word Cue send keystrokes to any app. Word Cue only sends them after Send (or Auto-send), only the reference text plus Return, and only after bringing the chosen presentation app forward.
- If the wrong window is in front at that moment (a dialog, another app that steals focus), the reference is typed there instead. It is ordinary text, so the harm is small, but it is why Review first stays the default.
- Nothing leaves the Mac.
