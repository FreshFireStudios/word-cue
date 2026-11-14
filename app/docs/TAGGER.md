# Trained word tagger (Create ML): the plan

*November 14, 2026. A scaffold, not a working feature. Nothing here has been trained or run.*

**Why:** the rules catch references said in the usual ways. A tagger trained on real sermons could learn the unusual ways a particular church or preacher says them, and spot reference-shaped phrases the rules miss.

**What exists now**

| Piece | Where | State |
|---|---|---|
| Training data export | Word Cue Lab > Export > Create ML Training Data | Written, untested |
| Format | JSON array of `{"tokens": [...], "labels": [...]}`, labels `REF` or `NONE` | Create ML's Word Tagger format |
| Labels come from | Lab reviews: only references marked **Correct** are `REF`; sentences holding unreviewed or wrong detections are left out | So the tagger never learns from guesses |
| Choosing it in Word Cue | Not yet. It would become a third Detection method once a model exists | |

**Steps on the Mac, once a few sermons are reviewed in the Lab**

1. In Word Cue Lab, export the training data. It saves `tagger-training.json`.

⋮

2. Open the Create ML app (it comes with Xcode), make a new **Word Tagger** project, and give it that file. Use about a fifth of the sermons as test data, not the same ones.

⋮

3. Train, then check its scores against the rules on sermons it has never seen. Only keep it if it finds references the rules miss without adding false alarms.

⋮

4. If it earns its place, add the `.mlmodel` to the Word Cue target and wire it in as a third Detection method: the tagger marks a span, and the rules engine reads that span to get the exact verse.

**What it needs:** many reviewed sermons. A handful won't train anything useful; dozens, from different preachers, will start to.

**Privacy:** training data is text only, from sermons the church chose to load into the Lab. No audio.
