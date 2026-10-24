# Speech-derived singing: private native resynthesis and independent Ear — 24 October 2026

**Implementation owner:** Fountain-Coach/sing. **Reused sampler DSP:** Fountain-Coach/midi2sampler pinned `64aaed8613a1f8eff0fc8bdb76656688848b0f87`, using actual exported `SamplerDSP` and `Window.equalPowerScalar` helpers. **Independent acoustic witness:** [Teatro Ear's new private comparison](https://github.com/Fountain-Coach/teatro.fountain.coach/blob/main/docs/evidence/ear-speaks-to-sings-2026-10-24.md).

## Exact execution on an authorized macOS host

- Original Sing 22/22 Swift tests passed (current root rerun required for any subsequent change).
- midi2sampler independent `swift build` passed; its corpus/persistence/resampling/loop-stitcher directories remain excluded by its own `Package.swift`, and are not silently copied into Sing.
- Separate `Experiments/SpeechToSing` macOS 14+ package `swift test`: **4/4 passed** after final phase-grain repair. Tests establish typed MIDI2 score usage, one syllable articulation across two first notes, determinism, synthetic pitch proximity, input SHA rejection and unvoiced/noise negatives.
- The macOS `say` executable generated isolated local speech `la` / `me` / `na` through `afconvert`, concatenated **only as a private test corpus** with provisional vowel boundaries. This input is **not** OpenAI speech, not a certified phonetic transcript, not licensed as a reusable sample voicebank and not published.
- A separate, self-contained Realtime API capture adapter for `gpt-realtime-2.1-mini` and `marin` is implemented and **dry-run validated only**; no `OPENAI_API_KEY` was found in the authorized Mac shell. A live OpenAI capture, licensed voice reuse and permanent voicebank are not claimed.

## Source-addressed media facts (private, /tmp only)

| Identity | SHA-256 |
| --- | --- |
| Spoken macOS `say` WAV (48 kHz mono PCM16) | `0112aaf01cf6c83d9c695b908f4211b376ce8b5b0e04654995aff447fb44bdbb` |
| Existing Sing articulated baseline | `1d285c6b0a9dd2f7b7be58aac1509b5f55bcac5e3636c530cbec25f20db8f505` |
| Final speech-derived sung candidate | `42b79af5aec3ff1efbcae0b3caf9e43ab2adab4cdd4149376b9cad5329704d6b` |

Both final scored takes have **249,600 frames / 5.2 seconds / 48 kHz / mono PCM16**, and use the **same original typed MIDI 2.0 Universal MIDI Packet** score compiled by existing Sing. There is no CoreMIDI, MIDI1 downgrade, second MIDI plane, live speech API dependency, hardware transport, or published asset.

## Real Ear development verdict

Original shipped Ear worklet SHA: `4f1d800fd5518975c0bc98a5fb0ace93eaa726d8731bf330a8eff59a9d115427`. A separate test-only Ear spectral feature processor observed the same exact media within actual Chrome 155 Web Audio graph. Source digests verified by the browser, explicit graph connections and cleanup, `AudioContext` closed.

| Scored part | Target Hz | Procedural Ear estimate Hz | Speech-derived Ear estimate Hz | Speech-derived diagnostic confidence |
| --- | ---: | ---: | ---: | ---: |
| `la` first note | 261.63 | 260.9 | 260.9 | 0.9970 |
| `la` second note (one vowel; melisma) | 329.63 | 333.3 | 333.3 | 0.9780 |
| `mi` | 392.0 | 387.1 | 387.1 | 0.9804 |
| `na` | 329.63 | 333.3 | 333.3 | 0.9751 |

Source-derived: **446 original Ear active windows** and **500 supplemental feature windows**. Procedure baseline: **487 original Ear active windows** and **500 supplemental windows**. Ear's existing note 48 event is still a **fixed placeholder**, not pitch transcription. Detection is a diagnostic autocorrelation proxy.

The **first** speech-derived candidate emitted weak `mi` confidence (0.221) and no valid `na` pitch. Sing's source grain selection was repaired to phase-anchor one repeatable voiced grain; Ear independently reprocessed the changed candidate and all four target pitches now appear with high diagnostic confidence. The difference in Ear active/silent windows shows that the acoustic envelope differs: **no claim of voice naturalness, correct syllables, stable formants or human singing intelligibility**.

## Next acceptance boundary

1. Implement and independently calibrate Ear's **phoneme recognizer** with source-blind, correctly labelled sung/unsung material, confusables, silence/noise negative controls, confidence and abstention (Ear issue #1).
2. Independently test formant retention, consonant-to-vowel continuity, vocal-identity consistency, audible realism and under-load real-time viability. Current experimental sampled output is **offline only**.
3. Only with explicit permissions/rights check for API-generated audio, perform a **private actual OpenAI** speech capture and re-run the same scenario, replacing the local Mac voice test and preserving original source/model hashes.
4. No AI generated material is published until explicitly authorized in the owning Satzfunk/Reframe editorial estate.

**Decision:** speech-derived synthesis is now a witnessed and reproducible private *acoustic development candidate*; **not** an intelligible natural singer, accepted voice bank or finished First Hearing.
