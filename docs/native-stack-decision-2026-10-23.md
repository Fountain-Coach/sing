# Native voice first — implementation decision, 23 October 2026

**Decision:** proceed with Fountain Coach's independent singing instrument. Remove Marie Ork / Alter-Ego from the critical implementation and acceptance path. Preserve original 7VST assets and the former vendor renderer study as historical documents, not dependencies.

## First executable native cut

A source-controlled Swift package now owns **SingVoice**, a deliberately small native **offline procedural voice renderer** and **sing-render** command-line executable. They have **zero third-party dependencies**. The first audition fixture is the existing original examples/three-syllables.json (la mi na, three pitches, three onset/nucleus pairs). Its phonetic content is synthetic, with no licensed human voice or third-party voicebank.

The engine has its own band-limited glottal excitation, stateful formant resonators, fixed onset-to-nucleus transitions, note-on/note-off amplitude envelopes and a PCM WAV writer. The first iteration is intentionally monophonic and rejects unsupported phonemes and melisma rather than hallucinating correct musical or phonetic support. This is **not** formant-model validation, demonstrated lyric intelligibility, a real-time Audio Unit, a neural voice, or a MIDI 2.0-receiving instrument.

### Build and audition on macOS or Linux

    swift test
    python3 -m unittest discover -s tests -v
    python3 tools/check_phrase.py examples/three-syllables.json
    swift run -c release sing-render examples/three-syllables.json /tmp/sing-la-mi-na.wav
    swift run -c release sing-render examples/three-syllables.json /tmp/sing-negative.wav --no-notes-control

Review the first WAV by ear before declaring intelligible speech or singing. The control WAV **must** be silent. For every candidate, record input revision, renderer revision, sample rate, rendered file digest, acoustic measurements and an independently witnessed author listening verdict. Do not publish audio by running tests.

## Next native work, in order

1. **S1a acoustic witness:** audition the produced file on a real output and decide whether la mi na is intelligible. Repair articulation and formants if not. Record source hash and a truthful listening verdict.
2. **S1b singing articulation:** add vowel stability, independent pitch/formant control, audible consonant articulation, breath and vibrato; test rests, note-off, phrase reset, melisma and pitch changes on a single vowel.
3. **S1c typed MIDI 2.0 interface:** reuse Fountain-Coach/midi2 Universal MIDI Packets and timebase, mapping note lifecycle and per-note expression into instrument state. Never send text or a voicebank as pretend MIDI notes. Provide a governed, versioned instrument identity and transport capability report.
4. **S2 real-time implementation:** move audio callback processing into a bounded real-time path, reuse only actually exported midi2sampler primitives where needed, and verify buffer lifecycle, output routing, click budgets and practical latency. Do not conflate this with the offline renderer.
5. **S3 rehearsal integration:** audition in Teatro; hand authored render candidates and source hashes to Satzfunk. Accept/publication remain separate, rights-controlled actions.

## Boundaries

- sing = phonetic scoring, acoustic instrument, native renderer, tests and acoustic evidence.
- midi2 = one Universal MIDI Packet plane and transport, not duplicated here.
- midi2sampler = optional existing DSP primitives; it is not yet a complete singer.
- Teatro, ScoreKit, AudioTalk = the score, performance direction and temporal contract.
- Reframe and Satzfunk = manuscript / audition / rights / publication authority.
- No Daisy, Bones Basic, Marie Ork, Alter/Ego preset format, PPG Phonem binary or vendor soundbank dependency.
- Historical Alter/Ego and Phonem research may remain as an unexecuted source lineage, without blocking the independent voice.
- No GitHub CI, unsanctioned deployment, new HTTP service, unapproved asset publication or automated rights grant.

**Evidence discipline:** a compiled test proves a compiled test; PCM metrics prove measurable sample data; a real listening witness is required before claiming intelligible singing; only explicit editorial admission makes a First Hearing.
