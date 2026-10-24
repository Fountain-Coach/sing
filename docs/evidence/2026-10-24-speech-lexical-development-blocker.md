# Sing — phonetic continuity experiment: pitch passes, words do not

**Date:** 24 October 2026. **Owner:** Sing. **Independent evaluator:** Teatro / Ear. **No published audio.**

Sing's prior spoken-sample-derived vocal renderer could already generate the four MIDI 2.0 notes of the original `la mi na` score, and Ear independently verified those notes. This continuation tests the missing property: does a recognizer **without access to the score or expected lyrics** recover the syllables from that actual sound?

## Ear's measured result (private, reproducible)

Apple's **on-device** English SpeechTranscriber (macOS 26+, local `en_US` installed) recovered “La, me, nah.” from the original macOS `say` spoken control. It produced **“Love”** for the original speech-derived singing WAV, and no transcript for the original procedural singing WAV. No OpenAI audio has been fetched: there is still no `OPENAI_API_KEY` in the connected terminal environment.

**Decision: block any claim of recognized `la mi na` or naturalistic singing.** Source-blind word transcription is a useful control, **not** independent phoneme recognition, and no reliable human listening verdict was obtained.

Ear also confirmed that reordered `la na me`, consonant-changed `ma me na`, silence, and noise do not produce the same accepted lexical phrase. This phrase-specific test refuses to infer intelligibility or phoneme recognition from matching pitches alone. See the owner [Ear's exact evidence and executable gate](https://github.com/Fountain-Coach/teatro.fountain.coach/blob/main/docs/evidence/ear-private-lexical-and-envelope-gate-2026-10-24.md).

## Controlled test of articulation preservation

The experimental voice now accepts **explicitly selected** `--natural-prelude-ms 50..320` to preserve more of the source speaker's naturally spoken consonant-to-vowel gesture before MIDI 2.0-controlled sustained vowel grains. The previous renderer is **default unchanged** (mode 0). The same input corpus with default mode 0 reproduced the original SHA **byte-for-byte**:

`42b79af5aec3ff1efbcae0b3caf9e43ab2adab4cdd4149376b9cad5329704d6b`

Three tested private variants:

| Natural speech prelude | SHA-256 prefix | Independent whole-take lexical result |
| --- | --- | --- |
| 140 ms | `ee62ce61` | “Love” |
| 230 ms | `aae8d04a` | “Me. Nah.” |
| 300 ms | `61f6400c` | “Me. Nah.” |

All are **development candidates only**. The 230-ms variant independently passed the actual Ear browser graph and its four diagnostic pitch measurements: 260.9 / 333.3 / 387.1 / 333.3 Hz with high local autocorrelation confidence; it still **omits the first syllable** in whole-phrase text. A segmented check of the sung output yielded “Love / Me / No” for the individual syllables. Treat every recognition as a fallible, language-dependent proxy, not a phonetic verdict.

Broad, smoothed spectral-envelope comparisons against the original spoken source were also measured independently by Ear: **0.9897 / 0.9879 / 0.9905 / 0.9638** for the four original sampled-note regions. This supports coarse vowel-spectrum retention but **not** stable formants, speaker identity, sound quality, voice naturalness, correct consonant recognition or intelligibility. The wider issue is phonetic transition and timing, not pitch alone.

## Reproduce

```sh
cd Experiments/SpeechToSing
swift test

# Existing, auditable default output, byte-for-byte with prior milestone:
swift run sing-speech-rehearsal ../../examples/sustained-melisma.json \
 /tmp/sing-speech-macos.wav /tmp/sing-speech-macos.json \
 /tmp/sing-speech-hybrid.wav

# Explicit experimental articulation preservation:
swift run sing-speech-rehearsal ../../examples/sustained-melisma.json \
 /tmp/sing-speech-macos.wav /tmp/sing-speech-macos.json \
 /tmp/sing-speech-prelude-230.wav --natural-prelude-ms 230
```

From Teatro, run `scripts/run_private_speech_gate.py` with either `/tmp/sing-speech-hybrid.wav` or `/tmp/sing-speech-prelude-230.wav` as `--speech-derived`; this performs the real browser Ear analysis, on-device lexical probe with negative controls, vowel-envelope comparison and SHA cross-check in one bounded invocation. Its private JSON receipt is written to `/tmp`; browser services and temporary staged audio are disposed.

**Remaining requirements:** actual API-generated spoken control (after credentials and output-use rights authorization), independent forced alignment and phoneme recognizer with out-of-sample controls, speaker-specific formant trajectories/voice naturalness assessment and physical/realtime performance safety. Do **not** weaken the acceptance criterion to call any nonempty ASR transcript a recognized lyric.

**Publication and editorial authority remain separate:** no audio committed to public Git, no First Hearing generated, no unlicensed derived voice bank.
