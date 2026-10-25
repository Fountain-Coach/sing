# Sing — source-filter spectral evolution and independent Ear comparison
25 October 2026 · Fountain-Coach/sing development owner · research-only

## Decision

**Implement and retain a new, bounded time-varying WORLD spectral-envelope
experiment. Do not promote as a natural, intelligible singer.**

The existing Sing speech-to-singing proof repeats a fixed, source-selected
pitch-synchronous vowel grain. The new candidate decomposes a short voiced
speech nucleus into approximate acoustic **fundamental frequency**, spectral
envelope and aperiodicity, then independently directs its pitch with the
same existing four written MIDI2 notes. The source's spectral and aperiodic
trajectories evolve naturally through the sustained vowel. It preserves the
source's actual consonant attack and final source vowel release with the
previously tested, disclosed private edit boundary.

The comparison is **controlled:** all inputs, SHA-256 source identity, score,
note timing, original consonant attack, source release and WORLD synthesis
engine are held equal; ONLY whether the spectrum/aperiodicity is frozen or
time-evolving changes. The environment and source waveforms are pinned.

**Independent new observation:** Apple source-blind word transcription
returns an **empty string** for the frozen WORLD condition, but **`Love me.`**
for the evolving condition. The earlier pre-WORLD source-grain renderer also
returned empty text. This is a partial acoustic advance, NOT recognized
`la mi na`, NOT a perceptual or singer-quality finding. The same actual
spoken source returns **`Love me, love.`**, rather than the phrase intended
by the original written score, so the source itself is not a fully qualified
phonetic reference. No target lyrics, phone labels, score or singer identity
is passed to any independent acoustic/lexical inference.

## Implementation ownership and separation

- **Sing**: `Experiments/SpeechToSing/scripts/world_vocal_tract.py` is a
  distinct, reversible *offline research renderer*.
  `vowel_anchor.render(..., vowel_renderer=...)` permits the research
  comparator to replace ONLY sustained vowel synthesis, with the original
  default unmodified. It is NOT a new MIDI2 parser, stream, profile or host.
- The canonical source score
  `examples/sustained-melisma.json` is **the same original source JSON** as
  native Swift Sing/Midi2SamplerDSP; the native Swift path still compiles it
  to typed Fountain-Coach/midi2 UMP. Python consumes this JSON directly for
  off-line comparisons and does **not** claim to receive UMP.
- **External research dependency**: PyWorld / WORLD wrapper in
  `/Volumes/DockerDisk/fountain-coach/devtools/sing-world-venv`,
  kept wholly outside normal production Sing. No server or new privileged
  daemon. Dependency install/recovery script is
  `Experiments/SpeechToSing/scripts/setup_world_research.sh`; pinned
  `numpy==2.3.4`, `pyworld-prebuilt==0.3.6.post1`, Python 3.14 on macOS
  Apple Silicon. Research venv consumes ~46 MB of the external volume,
  retaining the internal disk for native source code.
- **Supply-chain acknowledgement**: binary wheel provenance was not
  attested by the upstream release. Installation has verified PyPI SHA-256
  hashes and wheel-only selection in
  `requirements-world-macos-arm64.txt`:
  - `numpy-2.3.4-cp314-cp314-macosx_14_0_arm64.whl`:
    `62b2198c438058a20b6704351b35a1d7db881812d8512d67a69c9de1f18ca05f`
  - `pyworld_prebuilt-0.3.6.post1-cp314-cp314-macosx_11_0_arm64.whl`:
    `e30aa681a3da7b6c5a38ceb7ec483b6c3fc3643ed40677ea40503307a7fe1bce`
  - A separate compatible macOS 11 NumPy wheel digest is retained in the
    lock file. Source distribution and wheels must be reviewed independently
    before any commercial shipping or on-device incorporation. Upstream
    WORLD is modified BSD; the Python wrapper is distributed with its
    own terms. None of this grants rights over any underlying voice.
- **Ear / Teatro**: unchanged shipped Ear AudioWorklet SHA
  `4f1d800fd5518975c0bc98a5fb0ace93eaa726d8731bf330a8eff59a9d115427`,
  supplemental first-party acoustic feature worklet, Apple source-blind
  lexical inference, separately verified human references, all-phone
  decoder and adversarial false-speech controls. Ear remains judge of the
  audio; Sing does not self-certify intelligible syllables.
- No CI, CoreMIDI, model training, third-party voice bank, sample copying
  into SamplerDSP, public WAV/phoneme labels or publisher action.

## Real, private, SHA-addressed evidence

Original control: isolated macOS `say -v Kathy` speech,
`/tmp/sing-vocal-Kathy.wav`. Its raw SHA-256:
`6cb2bd4b5eaa43eac8635cf21bec904689f8a1aabdf46312d5c3c597124fa0eb`.
It is not an OpenAI-generated recording, licensed voice bank, verified
pronunciation or declared singing performer. Syllable onset/vowel boundaries
are provisional test metadata, not recognized phone times.

All candidates: **48,000 Hz**, mono PCM16, **249,600 frames / 5.2 seconds**,
same score (60,64,67,64), one onset for each of three syllables, a two-note
melisma for the first syllable, source attack and source release copied
through the same crossfade. WAVs and reports stay only under `/tmp`.

| Condition | Private WAV SHA-256 | Spectrum |
| --- | --- | --- |
| Original source-grain natural-release benchmark | `3edb992bae53c2f638a77761c6e0c9474a4dec1edc9275715463482ba4b9ebf5` | Repeated one grain |
| WORLD frozen spectrum | `3ab4cd685d611172659fbc1db49b4489635d29bf88cc99421453ee7ecd481335` | One source spectral profile |
| WORLD evolving spectrum | `3ac7c0b06f7384c271ec41ace11fbdd531d12f63bb26c86c8659b6c91269f9d6` | Source spectrum evolves |

WORLD's log-spectral end-to-start distance for the three source vowels is
**0 / 0 / 0** for frozen and **1.367662 / 1.846553 / 1.556587** for
evolving, computed on interpolated source WORLD envelopes (dimensionless
root-mean-square log-spectral difference). This is **verified acoustic
variation**, not proof of human vocal-tract identity or naturalness.

Both independently rerendered candidate WAVs matched their prior SHA-256
**byte-for-byte** from the same pinned local source. The original
vowel-anchor default also reproduces the original committed SHA as a unit
test. All original Sing default render code and its accepted articulated
baseline remain untouched.

## Independent results — important separate gates

| Independent criterion | Source-grain baseline | WORLD frozen | WORLD evolving |
| --- | ---: | ---: | ---: |
| Apple source-blind transcription | Empty | **Empty** | **Love me.** |
| Apple SoundAnalysis vocal-evidence windows | 0 / 9 | 0 / 9 | **0 / 9** |
| Actual original Ear browser acoustic activity | 442 | **442** | **442** |
| Actual four note pitch estimates (Hz) | 260.9, 333.3, 389.8, 333.3 | 260.9, 333.3, 387.1, 333.3 | 260.9, 333.3, 387.1, 333.3 |
| Human-verified `la mi na` phonemes | **No** | **No** | **No** |
| Publishing authorized | **No** | **No** | **No** |

All four written frequencies are 261.63, 329.63, 392.00, 329.63 Hz.
These estimates are diagnostic autocorrelation from actual Ear audio,
not the shipped Ear's placeholder note number 48. The native Apple
SoundAnalysis v1 classifier (OS-supplied model) still calls both WORLD
candidates primarily **music / synthesizer / brass / wind**, not a voice.
This contrasts with the spoken source 2/2 vocal evidence windows and real
human-singing reference 80/85. The stronger partial lexical transcript
must not override the separate failed voice-evidence gate.

An unmodified FULL Ear owner-run was executed on the evolving output:
receipt `/tmp/ear-world-kathy-evolving-full-20261025.json`.
`browser=passed`, `lexical-gate-blocked`,
source `Love me, love.`, candidate `Love me.`,
`phonemeRecognition=RAW_ALLPHONE_HYPOTHESES_NOT_QUALIFIED`,
`humanSungTimingReference=phrase-onset-proxy-below-gate`,
`activityHeldout=failed` (new chirp still produces 1 false phone after
WebRTC screening), `mediaPublished=false`,
`testServicesTerminated=true`.
Real original Ear active windows = 442, supplementary features = 500.
The frozen condition separately ran the **unaltered browser and original
source-count acceptance**, 442 windows, 500 feature windows; the frozen
word transcript was obtained through the same independent native Apple
transcription executable. Native SoundAnalysis and word transcription
independent receipts:
`/tmp/sing-world-apple-vocal-comparison.json`,
`/tmp/sing-world-headtohead-native-transcript.json`.

The original spoken source is not actually pronounced as requested,
the English vowel labels are provisional, the human-sung reference
still contains **only one singer**, and the separate human-sung
all-phone error remains **69.54% / 75.47%**. Nothing licenses a public
voice model or certifies a first hearing.

## Local regression and reproducibility

New research code:
`world_vocal_tract.py` (WORLD DIO + StoneMask + CheapTrick + D4C +
synthesis, 5 ms frames; original source-driven time varying filters, not
target lyrics), `test_world_vocal_tract.py`, idempotent external-disk
installer and hashed requirements. Includes no network path during
synthesis. Safety: source-bound SHA manifest, bounded duration and
pitch-ratio (0.67...1.90), voiced-only admission, finite PCM and peak
guard, one existing score, original attack and natural release, no
publishing, rejection of invalid source/score/noise.

Executed **22/22 Sing root Swift tests, 5/5 independent Swift speech
experiment tests, 14/14 original Python source-grain tests and 12/12
new WORLD tests = 53 successful automated tests**. WORLD frozen/evolving
replays were byte-identical. Hashed wheel download was independently
verified and the setup script passed its existing-install verification.
Ear's full browser and private reference tests passed as a harness,
but their acceptance statuses remain blocked as above.

Reproduction on the already authorized Mac (maintenance/installation
owned by the development workflow; no user download required):

```sh
cd ~/Developer/sing
sh Experiments/SpeechToSing/scripts/setup_world_research.sh

WORLD=/Volumes/DockerDisk/fountain-coach/devtools/sing-world-venv/bin/python
"$WORLD" Experiments/SpeechToSing/scripts/world_vocal_tract.py \
 --source /tmp/sing-vocal-Kathy.wav \
 --source-manifest /tmp/sing-vocal-Kathy.json \
 --score examples/sustained-melisma.json \
 --trajectory evolving \
 --output /tmp/sing-world-kathy-evolving.wav \
 --receipt /tmp/sing-world-kathy-evolving.json
"$WORLD" -m unittest discover -s Experiments/SpeechToSing/scripts \
 -p 'test_world_vocal_tract.py' -q
```

## Next defensible acceptance target

Keep both controlled WORLD variants for evaluation. Do **not** promote
the evolving condition solely because Apple recognized two words:
the words are not the intended score and native vocal classification still
fails completely. Move phonetic source admission toward **one clearly
articulated, correctly recognized actual speech source** and independently
timed consonant/vowel boundaries, then reassess source-internal
spectral/aperiodic evolution and timbre under the same score. Only
source-blind, speaker-disjoint, verified phoneme references and
intelligibility tests can eventually make a singer qualified.

The studio author retains all editorial decision rights; Ear compares
audio and cannot authorize publication.
