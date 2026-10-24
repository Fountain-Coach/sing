# Scenarios and acceptance — sing

**Development status, 2026-10-24:** one 5.2-second native synthetic score now renders three distinct auditions—plain, articulated and expressive—using one portable Swift instrument. All three native Mac WAV files were independently reconstructed in the conversation container with **identical SHA-256 hashes**. The latest Mac regression passed **22 Swift tests and five Python phrase tests**. Real typed MIDI 2.0 packets provide note, pressure, ±2-semitone bend and breath control; the macOS PCM output host is separate and **CoreMIDI-free**. The 249,600-frame expressive output engine has been exercised, without a human listening verdict or analogue capture. See [the three-take acceptance witness](evidence/three-take-comparison-2026-10-24.md).

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
- [x] Prepare three-way private comparison with identical score/duration, verified PCM hashes, actual /m/ and /n/ onset changes, and optional pitch/breath/vibrato. All three WAV digests match Mac-source renders; see [comparison evidence](evidence/three-take-comparison-2026-10-24.md).
- [ ] Store an immutable, typed render receipt with source revision and explicit human witness; generated PCM metrics are **not** a singing-quality verdict.
- [x] Compile, decode and rehearse with the **existing** `Fountain-Coach/midi2` version 0.12.8 typed 64-bit Universal MIDI Packets (Note On, Note Off, 32-bit Polyphonic Pressure). Decoded pressure measurably changes the generated PCM; the path is **in-process/offline** and does not use CoreMIDI.
- [x] Demonstrate bounded, prevalidated, sample-positioned event scheduling through a separate real macOS PCM output engine without CoreMIDI. Source frames consumed and engine start were witnessed, **not** acoustic loopback or under-load real-time guarantees.
- [ ] Admit a real live MIDI 2.0 UMP endpoint or on-wire non-CoreMIDI transport; neither is currently demonstrated.
- [x] Demonstrate monophonic vowel-preserving melisma across two note pitches (no retriggered consonant), reset/repeated PCM invariance, a 400 ms bounded release tail, and sample-identical output for varying buffer sizes.
- [x] Run a separate macOS AVAudioEngine PCM adapter against the instrument callback. Output engine started and the voice processed all 90,240 scheduled frames at 48 kHz. No CoreMIDI.
- [ ] Independently measure callback allocation behavior, worst-case latency, underruns and extended host stability; obtain an actual listening/loopback witness.
- [ ] Admit externally arriving MIDI 2.0 events from an authorized non-CoreMIDI transport. Live external MIDI source is not yet implemented.

## S2 — native independent singer (pending)

- [ ] Build a small consented phoneme corpus and legally admitted rights receipts.
- [x] Implement our **first independent procedural resonator prototype** with original excitation, per-phoneme formant banks and timed consonant-to-vowel crossfades; it currently covers only the original la/mi/na test phonemes, without proven naturalness.
- [x] Extend the voice with independent MIDI 2.0 continuous pitch bend that changes the fundamental without shifting the constant vowel-resonator centers; test measurable pitch ratio.
- [ ] Implement author-controllable **formant movement**, better vocal-tract resonance and independently audible consonant transitions (not falsely inferred from the existing fixed onset-to-nucleus filter crossfade).
- [ ] Reuse only actual exported `midi2sampler` code; add proper sample reader, buffer lifecycle and voice state.
- [x] Sustain a vowel across a four-note/three-syllable phrase with melisma and independent pitch motion; provide deterministic MIDI 2.0 Breath Control CC2 noise and bounded release with measured end-of-tail RMS.
- [ ] Improve noisy/unvoiced consonants, vocal naturalness and verify click-free transitions by listening and more complete acoustic metrics.
- [x] Implement and test explicit melisma that retains the vowel and does not restart consonant articulation on the second pitch.
- [ ] Implement general ties/legato control, explicit rests, repeated-syllable advancement, phrase cursor management and pitch-continuous articulation beyond the current monophonic fixture.
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
