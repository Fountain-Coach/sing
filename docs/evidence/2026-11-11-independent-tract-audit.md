# Independent acoustic audit — original Sing tract witnesses

**Date:** 11 November 2026. **Instrument source:** `Fountain-Coach/sing@2469cf3a304e71015b4156292170218d61f8aee4`. **Status:** native synthetic acoustic measurements, not human-physiology or natural-voice acceptance.

**Original source material:** Four exact SHA-256-locked 48 kHz, signed 16-bit mono WAV files from the native Ubuntu `SingVocalTract`, private in `~/Worktrees/sing-root-20261111-evidence/`. Original bytes remain unchanged. Their original SHA hashes are recorded in `2026-11-11-continuous-tract-and-fricatives.md`; structured independent results and SHA are checked into `2026-11-11-tract-audit.json`.

**Independent validator:** `python3 tools/analyze_tract_audio.py ~/Worktrees/sing-root-20261111-evidence` (Python standard library WAV and explicit Hann-window FFT only; no synthesizer code import). `python3 -m unittest discover -s tests -q` PASS **23/23**, including 3 new independent FFT, seeded noise and RMS tests. SoX independently cross-checked original RMS at 0.25/0.30/1.00/2.00 seconds.

| Original file | RMS dBFS | Spectral centroid (Hz) | Power ratio 3–9 kHz / 100 Hz–1 kHz | Peak 80–300 Hz autocorrelation |
|---|---:|---:|---:|---:|
| open-breath.wav | −37.43 | 1,937.8 | 0.112 | 0.0749 |
| narrow-breath.wav | −27.37 | 8,964.4 | 2.593 | 0.0569 |
| phonation.wav | −34.85 | 782.9 | 0.011 | **0.9741** at **195.9 Hz** |
| breath-to-voice.wav | −31.75 | 1,933.3* | 0.113* | 0.0749* |

*The mixed-passage spectrum/periodicity is computed only for its **first open-breath segment**, not the entire seven seconds. Peak and full-passage RMS refer to the complete passage.*

**The core discovery:** constricted-breath PCM is **10.06 dB higher RMS** than open breath. Comparing source recordings at unity gain would confound texture with loudness. A browser research audition must use a declared *analytical RMS-matching gain*, while preserving each original source file's bytes and checksum. This is **not LUFS mastering**, and equal RMS does not guarantee equal perceived loudness. A conservative listener-controlled common level remains separate.

The unvoiced noise shows low within-window pitch-autocorrelation, whereas voiced output exhibits a strong roughly 196 Hz periodic component. This is consistent with the synthetic control model. It does **not** establish that source noise sounds human, that a human will perceive the intended contrast, or that there is no low-frequency rhythmic pumping at arbitrary duration. The 100 ms steady-window envelope variation is 3.69% (open) and 1.25% (narrow); subjective listening remains decisive.

**Observation gap:** no rights-cleared, measured human breath /s/ /f/ corpus, physically captured audio, source-blind phoneme recognition, physical iPhone/iPad playback, headphones-perception comparison, or admitted browser continuous-Sing synthesizer yet. Our comparison data are computed from *synthetic* audio. Treat these as reproducible hypotheses, not empirical calibration to a human vocal tract.
