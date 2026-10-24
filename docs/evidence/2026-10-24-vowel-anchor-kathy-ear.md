# Sing / Ear — privately installed vowel-preservation experiment
24 October 2026 · **Sing owns rendering; Teatro/Ear owns evaluation.**

## Disposition

**The standalone vowel-anchor prototype is integrated into the actual Sing
speech-to-singing research tree, installed and executed.**
No second MIDI transport, CoreMIDI, new voice bank, model, server,
unapproved training corpus, publication or change to native Swift's default
rendering was introduced. The original articulated Sing baseline remains
the reference. **The new render is not accepted as intelligible singing.**

The user is not asked to install software, grade audio or download an
engineering artifact. This source-only candidate is maintained in Sing.

## Inspected, owned inputs and new private source

- Authorized original score: `examples/sustained-melisma.json` with typed
  Fountain-Coach/midi2 score compiled separately by the **existing Swift**
  speech-to-singing package; four notes with MIDI pitches **60,64,67,64**
  on three syllables, including `la` as an explicit two-note melisma.
  Python consumes the existing score JSON as an offline *research direction*,
  **not** compiled UMP and not a second MIDI implementation.
- Original private Samantha spoken WAV SHA:
  `0112aaf01cf6c83d9c695b908f4211b376ce8b5b0e04654995aff447fb44bdbb`.
  Real-source F0 dropped rapidly across each vowel; the old source-to-target
  ratio exceeded this prototype's bound for `mi` (392Hz versus about 163Hz
  near source vowel onset), so the prototype **refuses to render Samantha**,
  rather than silently raising its allowed pitch ratio.
- New, independently generated **local macOS `say` Kathy** source (not OpenAI,
  not a licensed voice model) under `/tmp/sing-vocal-Kathy.wav`, SHA:
  `6cb2bd4b5eaa43eac8635cf21bec904689f8a1aabdf46312d5c3c597124fa0eb`.
  Its matching provisional, **not human-verified**, onset/vowel manifest is
  `/tmp/sing-vocal-Kathy.json`. Its early vowel F0s were **241.21,
  242.42, 238.81 Hz**, so all four demanded MIDI pitches fall within
  the explicitly permitted source ratio **0.67...1.90**.
  The source is retained only privately and cannot be reused as a voice bank.

## What was installed

`Experiments/SpeechToSing/scripts/vowel_anchor.py` is a no-dependency
Python source module operating on SHA-verified mono PCM16 48-kHz speech.
It retains the attack PCM, uses an early, stable 90ms period estimate
and an overlapping, pitch-synchronous 140ms source-vowel grain window
to sustain the target MIDI-note frequencies. It preserves the original
natural last 70ms vowel release with a declared 10ms fade, rather than
discarding the ending as a new synthesized instrument. Release mode
`source-gap` is kept solely as a deterministic historical comparison.

A source edit is *not* an independently recognized consonant boundary.
This is source-directed *rendering*, not source-blind Ear inference.
The source remains under `/tmp` and the audio never enters public Git
or a reusable singer instrument. This implementation does **not** replace
`PrivateSpeechSinger` or `Midi2SamplerDSP` in the native Swift source.

### Private source-addressed outputs

| Candidate | Private WAV SHA-256 | Status |
| --- | --- | --- |
| Existing native Swift render from the same Kathy WAV | `748465a82316415ba80d8f7d42666fddc441ca02d9de03e9aa05df21a8cb644a` | Reference only |
| Prototype `source-gap` (mostly silent source end) | `56229b206cd0b3c6ba8794c24cb1e314df1534176dcc6c9e4246cca385c986ae` | Negative acoustic activity |
| Prototype `natural-vowel` source ending | `3edb992bae53c2f638a77761c6e0c9474a4dec1edc9275715463482ba4b9ebf5` | Passes acoustic activity, fails singing |

The historic `source-gap` WAV was re-rendered from its exact source and
score and compared byte-for-byte; it matched the recorded SHA. Each output
is **249,600 frames / 5.2 seconds / 48-kHz mono PCM16**.

## Actual independent Ear evidence

The real **original** Ear AudioWorklet plus independent supplemental acoustic
feature processor were executed in headless Chrome. Ear's original acoustic
activity threshold **>430** source-bound events was left unchanged:

| Same Kathy source, separate renderer | Original Ear active windows | Four Ear pitch proxies (Hz) |
| --- | ---: | --- |
| Native Swift baseline from Kathy | 446 | 260.9 / 333.3 / 387.1 / 333.3 |
| Source-gap variant | **427 — FAIL** | 260.9 / 333.3 / 389.8 / 333.3 |
| Natural-vowel variant | **442 — PASS** | 260.9 / 333.3 / 389.8 / 333.3 |

The source-gap measured figures were acquired via a **temporary diagnostic
copy** of the browser validator with the *count assertion skipped to observe
the raw event count*. The actual Ear-owned JavaScript was never modified,
and the official Ear gate previously rejected that variant. The natural-vowel
variant then ran the **unaltered full Ear-owned regression** and passed the
actual original browser count gate. Supplemental pitch proxies are acoustic
autocorrelation measurements, not the original shipped Ear's fixed-note 48
placeholder, and not recognized syllables.

**Independent Apple SoundAnalysis** on private sources and outputs:
spoken Kathy **2/2** vocal-evidence windows; native Swift Kathy **0/9**;
source-gap **1/9**; natural-vowel **0/9**. The latter variant still
looks to Apple's classifier like music, brass/trombone or synthesizer,
**not a successful natural singing voice**. Vocal labels are diagnostic,
not human judgments or calibrated phoneme probabilities.

**Independent Apple source-blind word transcription:**
spoken Kathy `Love me, love.`; native and both anchored sung candidates
return an **empty transcription**. This source is not itself a certified
`la mi na` speech realization. **PocketSphinx audio-only phone hypotheses**
were returned but fail to establish the intended `lɑ / mi / nɑ` phonemes.
No intelligibility or voice identity is certified.

The full Ear-owned source-addressed command for the natural-vowel candidate
executed the real Chrome worklet, original Apple lexical and vowel-envelope
comparison, speech/phonetic negative controls, human-rated spoken references,
the one-singer human-sung timing reference, raw PocketSphinx and independent
WebRTC VAD. Its private receipt:
`/tmp/ear-vowel-anchor-kathy-natural-e2e.json`.
Actual final status:
`browser=passed`,
`lexical-gate-blocked`,
`source=Love me, love.`,
`candidate=(empty)`,
`syntheticPhoneticProbe=NOT_QUALIFIED`,
`phonemeRecognition=RAW_ALLPHONE_HYPOTHESES_NOT_QUALIFIED`,
`activityHeldout=failed`,
`mediaPublished=false`,
`testServicesTerminated=true`.

These checks **do not** pass an independent singer or listener-intelligibility
gate. The complete SoundAnalysis comparison for the prototype is also
available privately at
`/tmp/sing-anchor-natural-release-sound.json`, separate from the unified
Ear receipt because the latter's source admission is pinned to Samantha
and must not be silently rewritten for Kathy.

## Local tests and reproduction

```sh
cd ~/Developer/sing
swift test
swift test --package-path Experiments/SpeechToSing
cd Experiments/SpeechToSing
python3 -m unittest -q scripts/test_vowel_anchor.py
python3 scripts/vowel_anchor.py \
  --source /tmp/sing-vocal-Kathy.wav \
  --source-manifest /tmp/sing-vocal-Kathy.json \
  --score ../../examples/sustained-melisma.json \
  --release-style natural-vowel \
  --output /tmp/sing-vowel-anchor-kathy-release.wav \
  --receipt /tmp/sing-vowel-anchor-kathy-release.json
```

Actual test runs: **22/22 root Swift**, **5/5 speech experiment Swift**,
**14/14 Python**. Tests cover note identity, source hash, original attack
sample equality, natural release, deterministic PCM, ratio limitation,
source F0, noise rejection and no automatic publication.

No TTS or OpenAI model was installed, no OpenAI API usage, CoreMIDI,
networked audio server, new production code, CI or private media publication.

## Engineering decision

Keep the source-preserving pipeline available as a **bounded experiment** and
keep the original articulated Sing take as the authority. Natural release
corrects a real technical defect in the first prototype (source-gap silence),
but pitch correctness and vowel-envelope similarity alone still produce an
instrument-like synthetic sound that independent Ear does not recognize as
sung words.

The next signal-processing step requires a genuinely time-varying, vocal-tract
preserving source model and better independently intelligible initial speech,
not simply more gain, more pitch correction or changing Ear's acceptance
threshold. Naturalistic OpenAI speech capture remains separately gated by
actual authorized API credentials, rights, and independent source-blind checks.
