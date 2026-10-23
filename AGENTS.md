# sing — agent and contributor instructions

## Mission
Design and verify independently reproducible MIDI 2.0 singing instruments interoperating with Satzfunk/Teatro. Implement our own native vocal synthesis first; neither Marie Ork nor Alter/Ego is on the critical path. Treat old vendor experiments and 7VST as protected historical research only. Build reusable, self-describing instruments; do not replace the manuscript/editorial workflow.

## Authority
- **sing:** phoneme alignment, vowel sustains, consonant transitions, melisma, voice capabilities, acoustic controls, renderer contracts, tests and evidence receipts.
- **Reframe:** source selection and editorial intent.
- **Satzfunk:** private audition, take comparison, approvals and First Hearing release.
- **Teatro/ScoreKit/AudioTalk:** score and expressive direction.
- **midi2:** Universal MIDI Packets, profiles, property exchange and transport.
- **midi2sampler / Csound / others:** audio implementation only after actual build and sound verification.
- **FountainStore / EstatePublisher:** immutable custody and authorized publication; **Ear:** physical execution witness if implemented.

## Non-negotiable
1. **No fabricated listening receipts:** distinguish conceptual, source-inspected, compiled, simulated, real-device performed, captured audio, and publicly released.
2. **No duplicate platform:** reuse Fountain-Coach/midi2 typed Universal MIDI Packets; no second MIDI plane, no new transport, no autonomous publication system. **CoreMIDI is explicitly prohibited** in sing, including bridges, sidecars and fallback paths. Keep hardware/audio output separate from packet parsing and synthesis. AVFoundation PCM output is allowed only in the separate macOS audio-host executable; it must never become a MIDI dependency of SingVoice or SingMIDI2.
3. **No imported vendor assets:** no proprietary Alter/Ego code, Plogue binaries, Marie Ork/Daisy/Bones banks, private Aeschylus translations, 2017 source media, or secrets in Git.
4. **No voice imitation without consent.** Capture and licensing are part of the instrument identity.
5. **No claims from prose:** inspect Package.swift, compiled targets, implementation, executable endpoint and real output before declaring a capability.
6. **No GitHub CI**; prefer local, deterministic commands, tests, checksums, and explicitly recorded witnesses.
7. **No implicit release:** an instrument's autonomous generation, training or performance can propose a candidate, but never approve payment, data exposure, host configuration or public issue of an edition.
8. Follow FCIS's one-source-of-truth, scenario, reversible git history, minimal abbreviation and precise evidence principles.
9. Preserve original archive metadata and separate original, restoration, derived score, and new performance.
10. Never rewrite another repository automatically. Cross-repository changes require their owning contracts and corresponding tests.

## First scenario
The current accepted execution contract is Fountain-Coach/midi2 typed UMP → SingMIDI2 **off-thread preflight** → bounded RealtimeSinger sample events → PCM. Run `swift test` and the existing Python phrase checks; run `sing-midi2-rehearsal --realtime` for deterministic audio. `sing-macos-output --probe` only inspects compatibility; `--play` actually makes sound on the default system output and must be explicitly requested. The host's successful playback report is not a human listening or analogue-capture witness. Never use CoreMIDI, Apple MIDI endpoints, proprietary voices, an alternate MIDI plane or GitHub CI.

## Working style
Contributors must report: inspected refs, implementation change, exact local test command/result, audio witness when applicable, uncertainties, and downstream impact.
