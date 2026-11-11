# Word Cue Lab

*Written November 11, 2026. Nothing here has been compiled yet.*

Word Cue Lab is the developer's bench for Word Cue. It uses the same detection engine as the app, so what it shows is what a church would get.

## What it does

| Job | How |
|---|---|
| Load a sermon | Import a recording (transcribed on the Mac by Apple's recogniser) or a transcript from any tool (`.txt`, JSON list, or JSON lines) |
| See what was caught | A table of every detection: time, verse, score, why, and the words heard |
| Review | Mark each one Correct, Wrong verse (and say the right one), or Not a reference |
| Record misses | Paste the words and the verse they should have produced |
| Try a sentence | Type anything and watch what the detector does |
| Export | Wrong, false-alarm and missed items become test cases in `proposed-cases.json` |
| Church corrections | Import a corrections file a church exported from Word Cue's Service Log |

Sessions are saved in `~/Library/Application Support/Word Cue Lab/`.

## Turning a miss into a fix

1. Review a sermon in the Lab and press **Export Cases**.

⋮

2. Open `proposed-cases.json`, pick the cases worth keeping, and paste them into `app/WordCueKit/Tests/WordCueKitTests/Resources/cases.json`.

⋮

3. Run `python3 engine-python/run_tests.py`. The new cases fail.

⋮

4. Change the rules (JSON first, Python logic if needed) until they pass, then copy any logic change into `Engine.swift`.

## Connecting Claude

The connector is a small program called `wordcue-lab-mcp`. Claude starts it on your Mac and talks to it directly. There is no API key and nothing runs in the cloud.

1. Build it once. In Terminal:

   ```
   cd app/WordCueKit
   swift build -c release --product wordcue-lab-mcp
   ```

   - `cd app/WordCueKit` moves Terminal into the engine's folder, where `Package.swift` lives.
   - `swift build` compiles Swift code using that `Package.swift`.
   - `-c release` means "configuration: release", the fast, optimised build.
   - `--product wordcue-lab-mcp` builds only the connector, not everything.
   - The finished program lands at `app/WordCueKit/.build/release/wordcue-lab-mcp`.

⋮

2. Tell Claude where it is. Add this to Claude's connector (MCP) settings, with the real path to your `word-cue` folder:

   ```json
   {
     "mcpServers": {
       "wordcue-lab": {
         "command": "/PATH/TO/word-cue/app/WordCueKit/.build/release/wordcue-lab-mcp"
       }
     }
   }
   ```

   Where that settings file lives depends on the Claude app and version, so check Claude's own help for "MCP" before editing it.

⋮

3. Restart Claude. It can now use these tools:

| Tool | What Claude can do |
|---|---|
| `list_sessions` | See the sermons in the Lab |
| `get_transcript` | Read a transcript, or part of one |
| `get_detections` | Run the detector over a session and see every result and review |
| `detect` | Try the detector on any sentence |
| `lookup_verse` | Read KJV text for a reference |
| `review_detection` | Mark a detection correct, wrong or a false alarm |
| `add_miss` | Record a reference the detector missed |
| `propose_cases` | Turn the reviews into proposed test cases |

**Privacy:** when Claude reads a transcript, that text is sent to Claude. Keep only sermons in the Lab that are fine to share that way. Audio never leaves the Mac.
