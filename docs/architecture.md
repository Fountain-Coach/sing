# sing — instrument architecture

**Design decision / 2026-10-21.** This is the planned contract, not a claim of working synthesis.

## Pipeline

```text
Reframe passage + source revision + author selection
      ↓
Satzfunk editorial direction → AudioTalk/ScoreKit/Teatro score
      ↓
sing phrase compiler:
  grapheme-to-phoneme → syllabification → alignment → articulatory timeline
      ↓
renderer-neutral performance:
  voice identity; vowel/consonant state; note schedule; continuous expression
      ↓
typed MIDI 2.0 UMP + separate versioned instrument state
      ↓
renderer adapters:
  A) signed Alter/Ego AU with licensed voice (reference, MIDI1 boundary)
  B) native midi2sampler + formant/pitch/excitation extensions (target)
  C) Csound or neural backend when demonstrably available (optional)
      ↓
captured PCM/audio + timing/rights receipts → Satzfunk private audition
      ↓
explicit author approval → authorized estate publisher / First Hearing
```

## Five separate identities

1. **Text source:** work, edition, immutable source hash, passage range, speaker and rights; never inferred from a rendered duration.
2. **Phonetic plan:** language, tokens, phonemes (with normalized notation), syllables, stress, diction and pronunciation choices.
3. **Score:** note-on/off, exact musical/real-time scheduling, rests, ties, melisma and expressive controls; events refer to syllable IDs rather than rewriting lyrics inside MIDI.
4. **Voice:** model/bank/reference recording ID, provenance, performer consent, redistribution and derivative rights, registered range/capabilities, voice-version hash.
5. **Render:** engine and binary version, translation/adapters, input hashes, actual audio format, latency, measured acoustic properties, execution witness and approval state.

## Acoustic principles

A voiced sound is conventionally decomposed into excitation (voicing/noise), time-varying spectral envelope/formants, and articulation. Pitch change **must not automatically shift formants**. Vowels must sustain across notes; unvoiced consonants need correctly placed attacks/releases and aperiodic noise. Joining fixed recordings alone is insufficient.

Candidate native implementation: a recorded consented phonetic corpus plus loop/crossfade operations from midi2sampler; perform pitch-synchronous or vocoder-style resynthesis with explicit formant treatment, continuous voice state, breath and acoustic quality controls. Neural synthesis is a replaceable backend, not required for MVP. An independent implementation may study WORLD, but verify actual licence and integration constraints before adoption.

## MIDI contract

- MIDI 2.0 Universal MIDI Packets are the **native event plane**; no new proprietary MIDI transport.
- Note On/Off schedule pitched sections; per-note controllers/pressure/pitch modulate timbre, intensity, pitch and phonetic articulation where renderer declares support.
- Lyrics, phonemes, voice banks, state hashes, licensing and source passages are **not** carried as a stream of MIDI notes. Load them via a versioned, authorized instrument state/capability contract; MIDI-CI may expose properties where appropriate.
- A note need not advance the syllable. **Melisma** is multiple notes on one vowel; a note-off need not close a phoneme if a legato/tie is active.
- Explicit phrase reset and deterministic syllable cursor prevent accidental dependence on GUI state. Map to MIDI 1.0 only at an adapter boundary and document expression loss.

## Realtime requirements (to measure)

No allocations/locks/file I/O in the native render callback, bounded scheduling jitter, coherent sample rate, stable voice state, controlled crossfades, click-free releases, and observability without logging on the audio thread. Values and thresholds are test criteria to set after the first real engine measurement; no invented latency budget.

## Renderer adapters

**Alter/Ego compatibility:** use the vendor Audio Unit as an unmodified black-box interpreter of derived ARIA state and MIDI, with licensed voice. An adapter must record state hash, preset identity, audio capture and MIDI route. Alter/Ego compatibility does not grant voice-bank redistribution or proprietary implementation rights.

**Native sing voice:** owns phonetic timeline and DSP without depending on Alter/Ego formats. Reuse midi2sampler's actual included primitives, then fill missing sampler, pitch/formant, noise and real-time rendering pieces. Do not mistake its README's excluded corpus/validation/resampling features for exported package products.

**Csound and others:** optional score/render implementations after linkage and output are witnessed; Teatro's local Csound C target currently contains a non-audible dummy/stub.

## Minimal portable phrase contract

`schemas/sing-phrase-v1.schema.json` describes only authored, pre-execution input. No property inside it proves rendered audio, available voice, or permission for public release. A subsequent typed `render-receipt` will require actual evidence. Keep renderer-specific state separate.
