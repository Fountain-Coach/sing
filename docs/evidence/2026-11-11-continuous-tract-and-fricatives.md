# Continuous Sing vocal tract and fricative singing: execution evidence

**Date:** 11 November 2026. **Source owner:** `Fountain-Coach/sing`, feature branch `feat/sing-vocal-tract-root-20261111`. **Status:** implemented and tested native source candidate; **not** an admitted FCIS instrument release, human-approved voice, browser AudioWorklet or publication.

## What changed

The existing `SingVoice` library now exposes `SingTractControls` and `SingVocalTract` as one continuously sampled, stateful **source/filter instrument**. Its control state separates normalized airflow, turbulence-generating constriction, periodic voicing, independent pitch, tract opening/frontness and conservative level. It uses source-owned seeded aperiodic excitation, polyBLEP glottal excitation, three variable resonant filters, bounded control smoothing and a truly silent output condition. It has no time-limited score and no imposed cyclic noise-volume envelope. This is a *computational analogy* of a vocal tract, **not a measured human anatomy or physical fluid simulation**.

`RealtimeSinger` retains the historical `l,m,n` phoneme source and its sample-accurate MIDI 2.0 scoring, pressure, CC2 breath and pitch controls. It now also accepts unvoiced `f,s,h` consonant onsets (noise excitation rather than a glottal note), and the `u,e,o` vowel resonances alongside existing `ɑ,i`. The original `ProceduralSinger.render` offline path implements the same new supported phoneme types. The test-only phrase `examples/air-syllables.json` covers `sɑ,fu,ho` without pretending to be a human speech corpus. Unsupported phonemes such as `ʃ` remain rejected rather than faked. No new MIDI2 packets, CoreMIDI, vendor samples, training, voice bank or permissions were introduced.

`sing-tract-study` is an additional native **offline audition executable** reusing the same SingVoice samples and existing WAV writer. It renders three original 3-second controlled conditions plus a single continuous 7-second *recording* of breath → constriction → voiced phonation → release. The audio engine is continuous: these lengths bound a reproducibility witness, **not** a scheduled automatic-stop patch.

## Actual build and test

Authorized Ubuntu Mac mini `Swift 6.3.3`, x86_64 Linux, source copied directly from this branch into `~/Worktrees/sing-root-20261111`. `swift test -j 4` PASS **33 tests / 0 failures**: 17 previous MIDI2 tests, 5 original voice tests, 7 new continuous-tract tests, 4 new fricative tests. Tested exact seeded sample repeatability, sample-buffer-size parity, true zero output, non-finite/refused controls, output bounds, spectrally distinct open/narrow breath, voicing onset, reset reproducibility, >10-second continuous output, live source-control change, and real fricative-vowel output. Existing typed UMP tests and pre-existing procedural singer PCM continue to pass.

`swift run -c release sing-tract-study ~/Worktrees/sing-root-20261111-evidence` PASS. Four 48 kHz, 16-bit, original synthesized mono WAV files and an execution JSON were generated privately. Exact file digests from Ubuntu:

| Private witness WAV | SHA-256 | Frames |
|---|---|---:|
| `open-breath.wav` | `622a8f23547c393aa95ebf65c8731d0768d003c2bb5a4a568ad5d1cc1dc13a58` | 144000 |
| `narrow-breath.wav` | `7c1e2073caa2f5bd8c62e7bae0e8e394f4163da7d3d361b5739a8941d1c0bde4` | 144000 |
| `phonation.wav` | `35bef2483a61ed7fc8c8fcb1bf5d12533b46dff265c5f1a4f95a6c291d4c0c5c` | 144000 |
| `breath-to-voice.wav` | `e0f17809b78d489dfe9383f62c5d60c43243a41939256442d1498d4604d77b0b` | 336000 |

Their PCM signal peaks are 0.13 or lower and are not mastered. The source/receipt is held on the authorized Ubuntu workspace for further private listening; the raw WAV media is **not committed** or published.

## Evidence boundaries

- **Implemented:** native source code, sample-level continuous controllable renderer, physically motivated *separable controls*, original output WAV, repeatable acoustic proxies and scorer-compatible additional phonemes.
- **Measured by code:** low-frequency versus higher-frequency signal differences, nonperiodic noise source, deterministic reset, sample peak and RMS, and no automatically scheduled patch stop.
- **Unestablished:** true vocal-fold fluid mechanics; actual pressure-flow calibration; recorded human/singing source comparison; vowel/formant tracking with real measured vocal tract; full IPA and language coverage; intelligible speech; independent Ear phoneme recognition; hard real-time stress/profiling; browser Csound parity; native iPhone/iPad/VoiceOver listening; any reader-facing executable edition.
- **Not authorized:** private human voice capture, speech imitation, sample redistribution, consumer publication or FCIS-KIT/midi2 instrument release. The writer's rejected v191 wind never becomes this source.

## Next bounded gate

Use the independently generated WAVs to establish a *baseline*, then compare with rights-cleared human breath, /f/ and /s/ recordings through Ear. Define a controlled observed acoustic fit, improve model where it fails, and only then realize a single source-pinned native-to-browser bridge for BREATH-01. A browser player that sounds plausible is not a scientific measurement.
