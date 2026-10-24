# Ear-mediated development selection — 24 October 2026

**Source owner:** Fountain-Coach/sing; **listening owner:** Fountain-Coach/teatro.fountain.coach (Ear).

**Status:** independently measured *acoustic development baseline* selected. **Intelligible singing, speech recognition and human playback are not proven.** No public release.

## The author's decision on decision authority

The author directs: **"that's not my decision — use ear!"** This explicitly means Sing's engineering-audition comparison belongs to Ear, not an author-operated subjective grading procedure. Editorial approval, ownership, rights and permission to publish a First Hearing remain author-controlled and are not delegated to a signal meter.

## What Ear actually executed

The same original synthetically generated 5.2-second / 48 kHz mono score (four MIDI2 notes over `la mi na` with a sustained first syllable) produced three distinct WAVs:

| Variant | Original Mac WAV SHA-256 |
| --- | --- |
| plain | `f4826365089889eafef579f5e0b3cf6f77d7bf570fcc0fa6e1d5f85ef191cf24` |
| articulated | `1d285c6b0a9dd2f7b7be58aac1509b5f55bcac5e3636c530cbec25f20db8f505` |
| expressive | `b7390503bdcb4669235fc417e0d21f8008c578f59228ab7ee0817e3df3ff8d27` |

Under an explicit private Web Audio source graph in headless Chrome 155, the **unmodified shipped Teatro Ear AudioWorklet**, source-identical to SHA-256 `4f1d800fd5518975c0bc98a5fb0ace93eaa726d8731bf330a8eff59a9d115427`, processed each original WAV. A separately scoped, test-only companion Ear AudioWorklet measured spectral features and diagnostic pitch. Neither worklet sent speech to a cloud API. Every browser-side WAV digest was independently verified before decoding. All three produced ~500 feature windows, 487/487/488 original-Ear active windows, timestamped source identities, actual silence reports and a successfully closed AudioContext.

The shipped Ear currently only observes energy, silence, and a start-of-stream onset; its `ear.ump` event uses a **fixed note number 48**, which is *not* detected pitch and is not a validated lyric transcript. The companion feature worklet uses 1024-frame windows, 512-frame hops, spectral balance / flux and diagnostic autocorrelation. It emits temporary test measurements, **not** a second MIDI transport.

## Actual Ear selection, bounded to the declared acoustic criterion

| Observation | Plain | Articulated | Expressive |
| --- | ---: | ---: | ---: |
| Relative high-frequency energy share at /m/ onset | 0.0103526 | **0.0016679** | 0.0016807 |
| Relative high-frequency energy share at /n/ onset | 0.0003197 | **0.0001376** | 0.0006617 |
| Spectral onset *candidates* (not syllable count) | 5 | 5 | 19 |

The articulated take has **~84% less high-frequency energy** at /m/ and **~57% less** at /n/ compared with plain, with the steady vowel band distribution effectively unchanged. With explicit decision criteria, the Ear test selects:

- **Development baseline: articulated.** Tune phonetic onset and release here, maintaining the stable vowel and existing voiced/sustained note.
- **Expressive: independent later performance control.** Its additional pitch/breath movement generates extra spectral onset candidates, but these are **not** extra syllables.
- **Intelligible la mi na: unresolved, unsupported by current Ear.** No speech recognition/phoneme classification was run; a true independent qualified local recognizer and negative controls are required. Do not relabel an RMS difference or pitch contour as a perceptual acceptance score.

Teatro owns the exact reproducible source and regression at [Ear three-take worklet witness](https://github.com/Fountain-Coach/teatro.fountain.coach/blob/main/docs/evidence/ear-sings-three-takes-2026-10-24.md). Its test harness `scripts/verify_sing_ear.mjs` exercises both real Web Audio worklets, checks exact media digests, pitch contour, acoustic onset contrast, telemetry, shutdown and the declared capability limitation.

## Policy and next acceptance

No CoreMIDI, MIDI1 downgrade, vendor voice banks, hidden speech cloud, publication, external MIDI input or second MIDI transport. No audio media added to public Git. The author is **not** asked to choose an engineering take. Ear must implement or admit a separately tested phonetic-recognition capability before it can claim truly intelligible singing; future output remains subject to genuine source/rights/editorial approval by its owner.
