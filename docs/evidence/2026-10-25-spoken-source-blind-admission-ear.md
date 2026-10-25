# Sing / Ear — source-blind spoken reference admission, still blocked
25 October 2026. Sing owns the development reference. Ear owns independent
audio assessment. No vocal performance or edition has been published.

## Core verdict

**A usable provisional higher-register spoken test source has been generated,
but NO phoneme-verified `la mi na` source or intelligible singing instrument
has been admitted.**

The previous source selected for WORLD synthesis was macOS Kathy and Apple's
source-blind speech transcription rendered it `Love me, love.`. Correct
MIDI pitches cannot repair an incorrectly articulated source. We have now
tested a finite local spoken-source cohort, verified duplicates by PCM SHA,
and demonstrated that source-level pitch control can generate pitch-safe
speech. That is **exploratory development**, not independent human phoneme
ground truth or evidence of a natural singer.

## Predeclared first source cohort — important anti-overcounting finding

A frozen and SHA-256-recorded candidate plan was written to
`/tmp/sing-spoken-reference-cohort-20261025/plan.json` **before running any
speech recognition**. Its independent local speech synthesis produced
60 planned syllable-spelling/voice combinations: 5 local macOS voices,
2 syllable-1 spellings, 3 syllable-2 spellings, 2 syllable-3 spellings,
at 125 words/minute, three individually captured syllables each followed
by 150ms isolation. One **Kate (Enhanced) / `la`** source failed the
original minimum-active-syllable duration. That entire six-combination
branch was excluded without weakening the threshold.

**54 generated WAV filenames were only EIGHT unique SHA-256 waveforms.**
The first four voices often produce identical underlying PCM for
`la/lah`, `mi/me/mee` and `na/nah`. Repeated spelling variants are
**not independent acoustic witnesses**; they do not multiply a speaker,
phoneme truth or distinct experiment. The private source audit records
each group, 54 names, 8 unique WAV SHA values, every source-quality
rejection and every separate Apple transcript. No audio was committed.

| Voice | Submitted WAV filenames | Distinct PCM SHA identities | Normalized independent transcript |
| --- | ---: | ---: | --- |
| Kathy | 12 | 1 | `love me love` |
| Samantha | 12 | 1 | `la me nah` |
| Karen | 12 | 1 | `la me nah` |
| Kate (Enhanced) | 6 | 1 | `me no` |
| Moira | 12 | 4 | `la me no` or `me now` |
| **Total** | **54** | **8** | |

The original source plan allowed `la me na`, `la mi na`,
`lah me nah`. Separately, **Ear's pre-existing** lexical evaluator
allows `la me nah`, `la mi na`, `lah me nah`. These two lists
**are not identical**. We explicitly **did not** adjust either plan
after observing the resulting audio: under the *first local plan*
0/8 distinct sources match, whereas under **Ear's canonical lexical
policy** 2/8 distinct sources match (Samantha and Karen). Their early
source vowel fundamental frequencies are roughly 163–185Hz and
172–179Hz respectively, too low for the existing 392Hz `mi` score
note under the exact source-to-note limit **0.67–1.90**. Therefore
neither is a complete source admission. Kathy's early 240Hz-ish
source fits the pitch bounds, but its transcript is not accepted
under either source or Ear phonetic criterion.

## Separate high-register speech production (NOT a held-out trial)

As an explicitly **subsequent exploratory development hypothesis**,
the original macOS Speech Synthesis inline parameter `[[pbas 240]]`
was applied directly to source speech with Karen and Samantha, at
125 words/minute, before any WORLD transformation. This does **not**
authorize widening the vocoder's pitch-ratio bound. No extra phoneme
dictionary, forced alignment, singer identity, imported model or
new transport was created.

The chosen, privately reproducible **Karen** source:
`/tmp/sing-high-register-control-20261025/karen-pbas240.wav`.
SHA-256:
`5b9622bc6e0127e1e4c14904fb1859826bdcd8f9204d7c54ac80d318fc9c9533`.
The exactly recreated source matched that SHA byte-for-byte. Its
three early sustained vowel fundamentals are **342.857, 358.209 and
358.209 Hz**, with source periodicities 0.972, 0.9826 and 0.9809;
both first-syllable score notes (60,64), the second (67) and third
(64) satisfy **the unchanged 0.67–1.90 pitch-ratio bound**.

Apple SpeechTranscriber (source-blind audio, no lyrics passed)
returned **`La, me, na.`** for Karen; Apple's native SoundAnalysis
vocal-class diagnostic returned **2/2 vocal-positive windows**
(`speech` primary). Samantha's corresponding higher source was
`Law, me, nah.` and fails its own local lexical match.

**The Karen result is not a qualified reference.** It matches the
original local exploratory plan's `la me na` but Ear's canonical
fixed aliases **do not include `la me na`**, so Ear truthfully
returns `sourceReferencePassed=false`. The onset/vowel boundaries
were mechanically estimated from source activity and remain
`alignmentStatus=provisional`, not independent phoneme truth.
PocketSphinx's source-blind `AA UW EY N AA` raw phone guesses
do not prove the requested `L AA M IY N AA` sequence, and confidence
is uncalibrated. This source is retained as a bounded development input
only; no human-rated phoneme or second singer is available.

## Real controlled WORLD experiment with that source

Using the original **same** four-note Sing MIDI2-written phrase score,
without changing Swift's MIDI2 packet compilation, both new private
WORLD renders retain the same source, original consonant attacks and
natural releases, score notes and timing, and differ ONLY in source
spectrum trajectory (frozen vs evolving). The independent Apple word
recognizer, native sound-event model and full Ear owner-runner received
only the original audio bytes, never intended syllables or their labels.

| Test / output | Frozen spectrum | Evolving spectrum |
| --- | --- | --- |
| Exact private WAV SHA-256 | `0c5165c32bead7a571022e63555f377cfb307229c35c176488404056e0ff6012` | `02a7af1dbefbd0e8e8447af6c88f00af02fec62ed4b4d226028f208c71773a78` |
| Independent Apple transcript | **`La me, nah.`** | **`La, me, no.`** |
| Ear canonical candidate lexical alias | **Matches** | **Fails** |
| Ear canonical *source* lexical alias | **Fails** | **Fails** |
| Apple vocal-class test | **0/9**, fail | **2/9**, fail |
| Actual unmodified Ear AudioWorklet observed activity | **445**, pass | **445**, pass |
| Four Ear pitch proxies (Hz) | 260.9 / 333.3 / 387.1 / 333.3 | Same |
| Ear full-run status | **lexical-gate-blocked** | **lexical-gate-blocked** |
| Recognized phonemes, human intelligibility | **NOT QUALIFIED** | **NOT QUALIFIED** |
| Published audio or promoted instrument | **No** | **No** |

Both modes passed the unchanged actual Ear browser and independent
acoustic tests, independently executed in their **complete Ear-owned
test graph**, including real human spoken and human-sung references,
allphone and independent noise controls. Both returned
`RAW_ALLPHONE_HYPOTHESES_NOT_QUALIFIED`, held-out adversarial
WebRTC still fails, `testServicesTerminated=true`,
`publication=not-admitted`. Receipts:
`/tmp/ear-karen240-world-frozen-full-20261025.json`,
`/tmp/ear-karen240-world-evolving-full-20261025.json`.

**Important correction to the general engineering hypothesis**:
With Kathy's incorrectly articulated original source, time-evolving
WORLD spectra improved the transcript from empty to `Love me.`.
With this newly spoken high-register Karen source, frozen WORLD
spectrum preserves one of Ear's lexical aliases, while evolving WORLD
changes its final vowel enough that Apple transcribes `no` instead of
`nah`. Thus the advantage of evolving spectra is **not universal**;
the experiment deliberately does not pick a winner by adjusting source,
score or threshold. Both still sound more like instruments than
recognized singing to the independent classifier.

## Owning source changes, maintenance and privacy

- `make_speech_reference_cohort.py`: predeclared, finite local voice and
  syllable spellings, strict source duration, source SHA/manifest,
  explicit deduplication evidence after decoding, no media issue.
- `make_provisional_pitch_source.py`: repeatable, reversible private
  macOS high-register source, check no mutation of original source,
  permit no public singer/voice-bank rights; no user install.
- `verify_spoken_reference.py`: binds actual audio and manifest SHA,
  Apple source-blind results, frozen first plan, **Ear's actual owned
  lexical aliases read-only**, source pitch bounds and vocal-detection
  receipts, both WORLD output SHA and both full unmodified Ear runs.
  Mismatches fail rather than post-hoc acceptance.
- `test_spoken_reference_gate.py`: anti-duplicate counting,
  source identity, lexical-authority mismatch, pitch bounds, both
  WORLD conditions and missing phones, forged-source checks,
  rights and no implicit publication. Research private WAVs and
  reference transcripts remain outside public Git.

Private setup and reproduction:

```sh
cd ~/Developer/sing
python3 Experiments/SpeechToSing/scripts/make_speech_reference_cohort.py
python3 Experiments/SpeechToSing/scripts/make_provisional_pitch_source.py
python3 Experiments/SpeechToSing/scripts/verify_spoken_reference.py
python3 -m unittest discover -s Experiments/SpeechToSing/scripts \
 -p 'test_spoken_reference_gate.py' -q
```

The source-cohort generator replays its **original frozen plan** and
requires identical source WAV manifest identities. Independent Apple
transcripts and all Ear audio-test receipts are never fabricated by
the source generator; they were actually executed separately. No
GitHub CI, CoreMIDI, additional server, new MIDI parser, source WAV
in Git, trained voice bank, third-party model download or edition
publication was introduced.

**Engineering gate: still OPEN.** A subsequent separately scoped
source/witness must establish independently verified phoneme identity
and start/end times, consistent intended lyric interpretation,
reliable source voice activity and pitched vowel feasibility, then
both frozen and evolving renders must pass SOURCE-BLIND phoneme,
word/intelligibility and vocal-evidence criteria. No source or render
is admitted on the current receipts. Editorial authority remains
with the studio author.
