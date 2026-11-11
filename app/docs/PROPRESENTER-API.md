# ProPresenter API: can it show a specific Bible verse?

*Checked November 11, 2026 against the official spec at <https://openapi.propresenter.com> (`swagger.json`, OpenAPI 3.0.2, API version 1.0).*

## Short answer

**No.** The official ProPresenter 7 network API has no Bible endpoint. I read all of `swagger.json` in four passes: the words "bible" and "scripture" do not appear in any path, tag or schema, and "verse" appears only as an example song-group name ("Verse 1"). Nothing in the API creates or edits slide text or imports a file either.

So Word Cue cannot say "ProPresenter, show Acts 2:38" and have ProPresenter's own Bible feature build the slide.

## What the API can do that helps

| Capability | Endpoint | Use for Word Cue |
|---|---|---|
| Check connection | `GET /version` | "Test Connection" button |
| List / create messages | `GET` / `POST /v1/messages` | One-time setup of a "Word Cue" message |
| Show a message with text filled in | `POST /v1/message/{id}/trigger` | **Put the verse on screen** |
| Hide a message | `GET /v1/message/{id}/clear` | Take the verse off screen |
| Clear the messages layer | `GET /v1/clear/layer/messages` | Backup clear |
| Stage message | `PUT` / `DELETE /v1/stage/message` | Show the reference to the preacher only |
| Trigger existing slides | `GET /v1/presentation/.../trigger`, `/v1/library/...` | Only for slides that already exist |
| Current slide text | `GET /v1/status/slide` | See what is on screen now |

The API listens on the port shown in ProPresenter under **Settings > Network** once **Enable Network** is on. Base address: `http://<computer>:<port>/`.

## The plan

1. **Primary: a ProPresenter Message with blanks.**
   ProPresenter Messages are text overlays with fill-in blanks called tokens. Word Cue creates one message named "Word Cue" whose text is `{Verse}` and `{Reference}`. When the operator approves a suggestion, Word Cue looks up the verse in its own KJV copy and triggers that message with both blanks filled in. A ProPresenter Theme controls the look, so the church styles it once inside ProPresenter.

⋮

2. **Fallback: copy and switch.**
   If the API is off or unreachable, Word Cue copies the reference ("Acts 2:38") to the clipboard and brings ProPresenter to the front, so the operator pastes it into ProPresenter's own Bible search. This uses ProPresenter's real Bible slides and needs no API.

⋮

3. **Later, if wanted: scripted keystrokes.**
   Word Cue could type the reference into ProPresenter's Bible panel by itself. That needs macOS Accessibility permission and depends on ProPresenter's keyboard shortcuts, which I could not confirm from here. It is stubbed in the app and switched off.

## Trade-offs of the Message approach

| | Message with tokens (primary) | ProPresenter's own Bible panel |
|---|---|---|
| Works through the API | Yes | No |
| Translation | Word Cue's KJV | Whatever is installed in ProPresenter |
| Look | A Theme on the Messages layer | The church's Bible template |
| Long passages | Word Cue sends one verse at a time; arrow keys page through | ProPresenter splits slides itself |
| Lands in the service playlist | No, it is an overlay | Yes, if saved to the playlist |

The last row matters for the **dropped files** feature ("send verses to the service list"): the API can reorder a playlist (`PUT /v1/playlist/{id}`) but only with items that already exist, and it cannot create a Bible presentation. Through the API alone that feature is not possible in ProPresenter. For now, dropped files fill Word Cue's own queue, and each verse is sent the same way as a live suggestion.

## Still to verify on a real ProPresenter

- The exact JSON bodies for creating and triggering a message. The Swift client marks these `VERIFY`. I read them from a summary of the spec, not from a live response.
- That a message can be addressed by name in the URL (the spec says UUID, name or index).
- That the active Look shows the Messages layer on the audience screen.
- How fast a trigger shows up on screen (it should be well under the 1-2 second budget on the same Mac).
- Renewed Vision may add Bible control in a later version. Recheck the spec before launch.
