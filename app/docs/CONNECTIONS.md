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
