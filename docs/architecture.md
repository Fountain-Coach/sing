# sing — instrument architecture

**Design decision / 2026-10-21, native-first revision / 2026-10-23.** The original Swift formant renderer is now paired with a sample-positioned, persistent RealtimeSinger callback and separate macOS AVAudioEngine output host. Both MIDI2-in-process and audio-engine execution have been witnessed. **A live external MIDI 2.0 transport, quantified hard-real-time deadline guarantees and perceptually confirmed singing are not yet established.** Marie Ork, Alter/Ego and CoreMIDI are out of the implementation path. See [native voice first](native-stack-decision-2026-10-23.md) and [real-time witness](evidence/realtime-macos-output-2026-10-23.md).

## Pipeline

```text
Reframe passage + source revision + author selection
      ↓
Satzfunk editorial direction → AudioTalk/ScoreKit/Teatro score
      ↓
sing phrase compiler:
  phoneme plan → syllable alignment → articulatory timeline
      ↓
renderer-neutral performance:
  voice identity; vowel/consonant state; note schedule; continuous expression
      ↓
our native synthesis:
  glottal excitation → stateful formants → timed articulations → PCM
      ↑
existing typed MIDI 2.0 UMP + separate versioned instrument state
  (live event adapter pending; offline input currently comes from JSON)
      ↓
optional future adapters:
  consented sample/resynthesis voice or separately qualified renderer
  (no mandatory commercial voice or imported plugin state)
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

Implemented first native path: an independent Swift offline source/filter instrument using original glottal excitation, three-band formant resonators, timing and amplitude envelopes. It only covers the artificial la/mi/na fixture and has not passed a listening intelligibility verdict. Next: improve vocal excitation/articulation and connect existing MIDI 2.0 delivery. A consented sample/phonetic corpus path may later reuse actual exported midi2sampler operations with independent pitch/formant handling. Neural synthesis is optional, not the MVP.

## MIDI contract

- MIDI 2.0 Universal MIDI Packets are the **native event plane**; no new proprietary MIDI transport.
- Note On/Off schedule pitched sections; per-note controllers/pressure/pitch modulate timbre, intensity, pitch and phonetic articulation where renderer declares support.
- Lyrics, phonemes, voice banks, state hashes, licensing and source passages are **not** carried as a stream of MIDI notes. Load them via a versioned, authorized instrument state/capability contract; MIDI-CI may expose properties where appropriate.
- A note need not advance the syllable. **Melisma** is multiple notes on one vowel; a note-off need not close a phoneme if a legato/tie is active.
- Explicit phrase reset and deterministic syllable cursor prevent accidental dependence on GUI state. Map to MIDI 1.0 only at an adapter boundary and document expression loss.

## Realtime requirements (to measure)

No allocations/locks/file I/O in the native render callback, bounded scheduling jitter, coherent sample rate, stable voice state, controlled crossfades, click-free releases, and observability without logging on the audio thread. Values and thresholds are test criteria to set after the first real engine measurement; no invented latency budget.

## Renderer adapters

**Historical compatibility only:** the old Alter/Ego / ARIA / Marie Ork workflow is preserved for source research and comparison; no plugin, license, voicebank or preset is needed to build or test our native singer. There is no requirement to implement its adapter.

**Native sing voice (implemented in part):** SingVoice is our independently authored Swift source/filter instrument. Its persistent sample-by-sample engine supports standard typed MIDI 2.0 Note On/Off, polyphonic pressure, channel pitch bend (±2 semitones) and breath-controller CC2, plus an author-selected 5.3 Hz vibrato mode. Resonator centers remain fixed when fundamental pitch bends; breath uses deterministic shaped noise, with bounded smoothing and no sample banks. Four notes over three syllables demonstrated melisma through a separate macOS PCM output engine. **The output has not been judged intelligible singing.** Moving formant trajectories, more consonants, proven real-time latency/allocations, a separately authorized non-CoreMIDI physical transport, and wider phonetic repertoire are still missing. Optional consented resynthesis may reuse only actual exported midi2sampler primitives. [Phonem](phonem-reference.md) is historical reference, not a source dependency.

**Csound and others:** optional, separate render implementations only after independent linkage and audio output are witnessed. Nothing of this kind is a prerequisite for the native singer.

## Minimal portable phrase contract

`schemas/sing-phrase-v1.schema.json` describes only authored, pre-execution input. No property inside it proves rendered audio, available voice, or permission for public release. A subsequent typed `render-receipt` will require actual evidence. Keep renderer-specific state separate.
