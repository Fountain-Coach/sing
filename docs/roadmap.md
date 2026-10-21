# Scenarios and acceptance — sing

**Development status as of 2026-10-21:** conceptual contract and static source audit; no new singing audio from sing. Existing Alter/Ego Marie Ork MIDI-triggered system-mix sound is separately witnessed in [Satzfunk](https://github.com/Fountain-Coach/Satzfunk).

## S0 — source and capability inventory (done, documentary only)

- [x] Establish sing under Fountain-Coach and document component ownership.
- [x] Inspect audio/MIDI/voice routes in Fountain Coach and predecessor repositories.
- [x] Identify known missing midi2sampler build exports, note-scheduling and renderer gaps.
- [ ] Test actual compiled target exports and local integration graph independently.

## S1 — first *real* singing sound (pending)

**Fixture:** `examples/three-syllables.json`, synthetic `la mi na` with three timed notes and explicit phoneme/vowel mapping.

- [ ] Validate authored schema, store input hash, verify text/phoneme/note ID integrity.
- [ ] Produce a private Alter/Ego ARIA state with the existing hash-bound Satzfunk tool from a licensed Marie Ork state.
- [ ] Load derived state into actual vendor Audio Unit and establish explicit phrase cursor/reset.
- [ ] Send note on/off via typed MIDI2 local route, with logged MIDI1 adapter limits where necessary.
- [ ] Capture *isolated* rendered audio; test no-note silence, repeated rendering and real sound output. Save WAV format, cryptographic digests and timing/audio-quality witness.
- [ ] Have the author identify intelligible `la mi na`, not just non-silent sound.

## S2 — native independent singer (pending)

- [ ] Build a small consented phoneme corpus and legally admitted rights receipts.
- [ ] Implement a second independent **procedural resonator** path, informed by PPG Phonem's 12-resonator/excitation/phoneme approach, not its proprietary internals. Test a vowel with independent pitch and formant movement and consonant-to-vowel transitions.
- [ ] Reuse only actual exported `midi2sampler` code; add proper sample reader, buffer lifecycle and voice state.
- [ ] Sustain vowel over variable pitch without unwanted formant shifts; consonant noise, airflow and release with click-free transitions.
- [ ] Implement melisma, legato, silence/rest, repeated syllable with explicit advancement rules.
- [ ] Compare output with Alter/Ego behavioral reference, not claim identical timbre.

## S3 — composer and Satzfunk (pending)

- [ ] Implement self-describing instrument profile and author-selected voice.
- [ ] Bind a manuscript selection to score and voice via existing Reframe/Satzfunk API authority.
- [ ] Audition/comparison, source-preserving acceptance and immutable receipts. No popup-first DAW.
- [ ] Measure true native MIDI2 scheduling/capture and listen on an admitted physical output.
- [ ] Publish a *new, rights-cleared* First Hearing only by its owning release process.

## S4 — 7VST reinterpretation and children (pending)

- [ ] Historical evidence parity, rights, original credits and edition segregation.
- [ ] Derive one of 18 new vocal parts and compare with private reference, without treating pitch/duration coincidences as the original sequence.
- [ ] Create bounded offspring instrument identities (syllable, melisma, choir, 7VST variant), each with independent tests and rights.
- [ ] Compose a complete 7VST new edition while leaving all archival audio/text unchanged.

## Test evidence table

For each milestone, record: source and scenario hash; Git commits/revision of every used instrument; interpreter/host version and bank identity (metadata only); exact tool invocation; MIDI message receipts; captured isolated WAV checksum and audio properties; audible reviewer verdict; privacy/licensing and publication state. A mock, a file write, a UI launch or a non-silent system mix is **not** evidence of correctly articulated singing.
