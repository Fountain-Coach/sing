# Scenarios and acceptance — sing

**Development status, 2026-10-23:** our own Swift procedural-formant offline engine now builds and emits reproducible PCM WAV from the original synthetic fixture. Both Linux and macOS compile/tests passed. Intelligible singing, physical MIDI 2.0 routing, real-time audio and publication are **not** yet demonstrated. Marie Ork / Alter-Ego are removed from the active implementation path. See [native voice-first decision](native-stack-decision-2026-10-23.md).

## S0 — source and capability inventory (done, documentary only)

- [x] Establish sing under Fountain-Coach and document component ownership.
- [x] Inspect audio/MIDI/voice routes in Fountain Coach and predecessor repositories.
- [x] Identify known missing midi2sampler build exports, note-scheduling and renderer gaps.
- [ ] Test actual compiled target exports and local integration graph independently.

## S1 — native first sound (PCM generated; intelligible singing pending)

**Fixture:** `examples/three-syllables.json`, original synthetic `la mi na` with three notes and timed consonant/vowel pairs. No proprietary samples, plugin state or vendor voicebank.

- [x] Compile native Swift package, validate supported phonemes and phrase/note identity, render a three-note synthetic vowel sequence to isolated WAV output.
- [x] Test repeatability, measured sound, valid WAV, unknown phoneme rejection and no-note silence. Five Swift tests passed on macOS and Linux, separately from existing five Python authored-phrase tests.
- [x] Produce 48 kHz mono 16-bit PCM WAV with recorded duration, level and SHA-256 digest (test fixture; no human audibility judgement).
- [ ] Have the author identify intelligible `la mi na` by listening to native output; redesign formant and consonant transitions as required.
- [ ] Store an immutable, typed render receipt with source revision and explicit human witness; generated PCM metrics are **not** a singing-quality verdict.
- [ ] Receive note on/off and per-note expression via the **existing** typed MIDI 2.0 route; current JSON-to-PCM renderer is offline, not a live MIDI instrument.
- [ ] Implement melisma, phrase reset, legato, silence/rest, real-time callback and device output without untested promises.

## S2 — native independent singer (pending)

- [ ] Build a small consented phoneme corpus and legally admitted rights receipts.
- [x] Implement our **first independent procedural resonator prototype** with original excitation, per-phoneme formant banks and timed consonant-to-vowel crossfades; it currently covers only the original la/mi/na test phonemes, without proven naturalness.
- [ ] Extend the prototype with independent continuous pitch/formant movement, tested vocal tract resonance and consonant transitions.
- [ ] Reuse only actual exported `midi2sampler` code; add proper sample reader, buffer lifecycle and voice state.
- [ ] Sustain vowel over variable pitch without unwanted formant shifts; consonant noise, airflow and release with click-free transitions.
- [ ] Implement melisma, legato, silence/rest, repeated syllable with explicit advancement rules.
- [ ] Compare native auditions with author-selected acoustic/perceptual reference criteria; vendor fidelity and Marie Ork compatibility are **not** acceptance requirements.

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
