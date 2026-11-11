# Detection results: first three sermons

*November 11, 2026. Python reference engine, run on speech-to-text transcripts of the three sermon recordings Bryson supplied.*

## Bottom line

The detector caught **every Bible reference that was spoken with a book and chapter: 31 of 31**, with **no false alarms** across about 108 minutes of preaching. Two of the 31 came out with the wrong verse number, and both trace back to the speech-to-text step mishearing the number, not to the detector.

Read that score with one large caution: **I wrote the rules while looking at these same three sermons.** A score this clean on the material the rules were built from says the approach works. It does not say how it will do on a sermon it has never seen. The other 28 recordings are the real test.

## Scores

| Sermon | Length | Spoken references | Caught | Wrong verse | False alarms |
|---|---|---|---|---|---|
| A Certain Sound From Heaven | 32 min | 3 | 3 | 0 | 0 |
| Cleaned, But Not Occupied | 38 min | 16 | 16 | 0 | 0 |
| Creating the Atmosphere for Miracles | 38 min | 12 | 12 | 2 | 0 |
| **Total** | **108 min** | **31** | **31** | **2** | **0** |

"Spoken reference" means the preacher named a book and a chapter, with or without a verse. I built the answer key by reading all three transcripts start to finish.

The shared test file holds 110 cases (81 written by hand, 29 phrases from these sermons). The Python engine passes all 110, both when it reads the text at once and when it is fed one word at a time the way live speech arrives.

## What it caught

| How it was said | Example from the sermons | Result |
|---|---|---|
| Chapter and verse spelled out | "Luke chapter 11 and verse 24" | Luke 11:24 |
| "N and M" | "Colossians 2 and 15", "Acts 1 and 4" | Colossians 2:15, Acts 1:4 |
| Comma between numbers | "Luke 11, 24", "Matthew 3, 11" | Luke 11:24, Matthew 3:11 |
| "verse number" | "Proverbs chapter 23 verse number seven" | Proverbs 23:7 |
| Ranges | "Matthew 13, verse 55 through 58", "2 Kings 5 and 1 through 3", "1 Corinthians 12, nine and 10" | Matthew 13:55–58, 2 Kings 5:1–3, 1 Corinthians 12:9–10 |
| Numbered books | "2nd Corinthians 10 and 4", "1 Samuel 14 and 6" | 2 Corinthians 10:4, 1 Samuel 14:6 |
| Chapter only | "Acts chapter two", "Luke 24" | Acts 2, Luke 24 |
| Words between book and chapter | "the book of Acts. Amen. In the beginning of chapter two" | Acts 2 |
| Verse arriving a sentence later | "book of Acts, chapter two. And let us just read the verse 1" | Acts 2:1 |

It also made two **follow-on** suggestions that lean on the last reference, both at a lower score of 60%:

- "the next verse tells us" became Acts 2:2.
- "read in the first chapter" became Acts 1.

## What it got wrong or missed

1. **Wrong verse, twice, from speech-to-text.**
   - "1 Kings 13 and 20" was suggested as 1 Kings 13:20. The preacher then read 13:2 and said "1 Kings 13 and 2" a moment later, which was caught correctly. The first one was most likely "13 and 2" misheard.
   - "for Samuel 2 and 8" was suggested as 1 Samuel 2:8 at 60%. He had just said "1 Samuel 2 and 18", so this was "First Samuel 2 and 18" misheard twice over. The detector recovered the book (it reuses the last Samuel it heard) but could not recover the verse.

⋮

2. **One follow-on was off by one.** In the first sermon the preacher said "read the verse 1" and then read verse 2, so "the next verse" was suggested as Acts 2:2 when he was moving to 2:3. The detector followed what was said.

⋮

3. **Scripture quoted without a reference is not detected at all.** This is the biggest gap. Examples: "ye shall receive power after" (Acts 1:8), "seek the kingdom of God first" (Matthew 6:33), "today is the day of salvation" (2 Corinthians 6:2), and the Acts 2:2–4 passage read aloud in two of the sermons. I did not count these. Catching them means matching spoken words against the Bible text, which is a separate feature for a later step.

⋮

4. **A book named with no chapter gives no suggestion.** "The Bible says that in Corinthians if there's an uncertain sound" points at 1 Corinthians 14:8, but with no chapter there is nothing to look up. This is by design for now.

## What it correctly ignored

These all contain book names or numbers and produced nothing:

- "Genesis to Revelation, 66 books, 1,189 chapters, 31,102 verses"
- "You can read it in Matthew and Mark and Luke"
- "James and John wanted to sit right next to him", "John the Baptist"
- "Peter ... standing up with the 11"
- "it's not your job to...", "the pastor's job"
- "I see it's 7/29", "12-week Bible study", "12 baskets", "5,000 men"
- "Samuel, Samuel, he got up"

## Speed

Re-reading 3,000 words of transcript takes about **2 milliseconds** in Python, and Swift will be faster. Detection will not be what decides the 1–2 second goal. Apple's speech recogniser will, and that can only be measured on the Mac.

## Limits of this test

| Limit | Why it matters |
|---|---|
| Rules were tuned on these three sermons | The score is a best case |
| Transcripts came from Whisper (small English model), not Apple's recogniser | Apple will mishear different words and may write "Acts 2:38" where Whisper writes "Acts 2 and 38". Both styles are in the test cases, but real Apple output is untested |
| Three preachers, one church, 108 minutes | Other accents, rooms and habits will bring new phrasings |
| The Swift engine has not been compiled | It is a line-by-line copy of the Python and should pass the same 110 cases, but that is unproven until `swift test` runs on the Mac |
| Verse text is King James only | Other translations need a licence |

## Next for accuracy

1. Run the other 28 recordings and log every miss as a new case in `cases.json`.

⋮

2. On the Mac, run the same recordings through Apple's recogniser and compare.

⋮

3. Decide whether quoted-scripture matching is in the first release.
