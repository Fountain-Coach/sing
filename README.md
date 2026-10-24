# sing

**MIDI 2.0-native singing instruments for Fountain Coach.**

**Status, 24 October 2026:** the native Swift synthesizer now renders three independent, SHA-256-verified WAV takes from **one five-second synthetic score**: plain, articulated, and expressive. The articulation mode prolongs /m/ and /n/ nasal onsets and shapes their transition to vowels; the expressive mode adds typed MIDI 2.0 pitch bend and breath, plus optional vibrato. Four notes retain three syllable articulations across melisma. A separate macOS PCM output adapter works without CoreMIDI, and full authored WAV outputs were independently reproduced byte-for-byte outside the Mac. **No proprietary voice bank, no alternate MIDI plane.** Human listening, external MIDI transport, hard-real-time limits and publication remain separate pending gates.

A voice is an instrument, a syllable is a timed phonetic state, and a performance is an executable score. **sing** makes text, phonemes, notes, expression, performer identity, and verifiable sound independently addressable. Our own glottal-excitation/formant synthesis is the implementation path. Alter/Ego and Wolfgang Palm's PPG Phonem remain **historical, black-box references only**; neither proprietary implementation is part of this source or required to build and render.

## Position in the estate

- **[Satzfunk](https://github.com/Fountain-Coach/Satzfunk)** (private source authority) is the manuscript-addressed listening, editorial approval and publication context: First Reading → First Hearing.
- **[Reframe](https://github.com/Fountain-Coach/Reframe)** owns source text, selected passage, edition, identity and reader/writer decisions.
- **[Teatro](https://github.com/Fountain-Coach/Teatro)**, **[ScoreKit](https://github.com/Fountain-Coach/ScoreKit)** and **[AudioTalk](https://github.com/Fountain-Coach/AudioTalk)** express scenes, temporal notation, performance intent.
- **[midi2](https://github.com/Fountain-Coach/midi2)** is the typed Universal MIDI Packet and instrument-transport foundation; **[midi2sampler](https://github.com/Fountain-Coach/midi2sampler)** contributes sample DSP, not a completed singer.
- **sing** owns phonetic alignment, voice identity/capability contracts, renderer-neutral vocal performance, comparison and instrument tests. No duplicate editorial coordinator, MIDI transport or generic DAW.
- **[instruments.fountain.coach](https://github.com/Fountain-Coach/instruments.fountain.coach)** may catalogue admitted instrument identities; it is a supporting reference domain, not a new public editorial front.

## One voice; many performances

A source passage and its hash are not a voice bank. A voice bank and its licence are not a score. An executable score and its renderer are not a published First Hearing. Keeping these separate will let one score be performed by an independent procedural singer, a consented sample voice, or an explicitly qualified future neural model. Historic vendor compatibility is optional research, not a product gate.

**7VST / Seven Against Thebes** is the documented historical specimen: a 2017 Alter/Ego/Bidule/ARIA experiment and privately restored audio/text evidence. The author also reports extensive use of **PPG Phonem for iPad** in the historical Bandcamp work; particular track assignments have not yet been independently established. New renditions are **new editions**, never silently labelled as the historical production. See [7VST lineage](docs/7vst-case-study.md).

**Satzfunk offspring** may be independently versioned voices, choirs, pronunciation models, scores, or small autonomous performance agents with explicit parentage, controlled execution, provenance and rights. “Babies” means independent artistic instruments, not unbounded code replication. See [offspring contract](docs/offspring.md).

## Documentation and first milestone

- [23 October: native voice first and verified boundaries](docs/native-stack-decision-2026-10-23.md)
- [23 October: typed MIDI 2.0 UMP rehearsal evidence](docs/evidence/ump-rehearsal-2026-10-23.md)
- [23 October: real-time voice callback and macOS audio-output witness](docs/evidence/realtime-macos-output-2026-10-23.md)
- [24 October: extended native expressive audition and physical output witness](docs/evidence/expressive-singing-2026-10-24.md)
- [24 October: three-take listening comparison and verified checksums](docs/evidence/three-take-comparison-2026-10-24.md)
- [Architecture and instrument boundaries](docs/architecture.md)
- [Code audit: Fountain Coach + Contexter](docs/source-audit-2026-10-21.md) and [immutable upstream Git pins](docs/audit-pins-2026-10-21.json)
- [Alter/Ego compatibility reference](docs/alterego-reference.md)
- [Wolfgang Palm's PPG Phonem for iPad: resonator voice and historical Bandcamp testimony](docs/phonem-reference.md)
- [7VST historical source and new score](docs/7vst-case-study.md)
- [Satzfunk family / offspring](docs/offspring.md)
- [Executable acceptance scenario and roadmap](docs/roadmap.md)
- [Publishing, consent and rights](docs/rights-and-release.md)
- [Provisional performance JSON schema](schemas/sing-phrase-v1.schema.json), [short synthetic phrase](examples/three-syllables.json), and [five-second sustained melisma](examples/sustained-melisma.json)

**Current milestone:** the identical synthetic phrase now has **plain, articulated and expressive auditions**, distinguished by actual waveform differences and preserved by source/audio hashes. Typed MIDI 2.0 notes, pressure, pitch bend and breath are decoded off the audio thread; the independent native voice produces sustained vowels, a voiced nasal onset, optional vibrato and melisma without a CoreMIDI dependency. **First intelligible-singing acceptance remains pending a human listener's verdict** and callback measurements under load. Next: assess syllable clarity by listening, improve phonemes and natural phrasing, then test a separately authorized non-CoreMIDI transport. No historical text, voice banks, passwords or audio exports belong in public Git.

## Local build and acoustic test

```sh
swift test
swift run -c release sing-render examples/three-syllables.json /tmp/sing-la-mi-na.wav
swift run -c release sing-render examples/three-syllables.json /tmp/sing-control.wav --no-notes-control
swift run -c release sing-midi2-rehearsal examples/three-syllables.json /tmp/sing-ump.wav
swift run -c release sing-midi2-rehearsal examples/three-syllables.json /tmp/sing-pressure.wav --pressure
swift run -c release sing-midi2-rehearsal examples/three-syllables.json /tmp/sing-realtime.wav --realtime
swift run -c release sing-midi2-rehearsal examples/sustained-melisma.json /tmp/sing-plain.wav --realtime
swift run -c release sing-midi2-rehearsal examples/sustained-melisma.json /tmp/sing-articulated.wav --realtime --articulated
swift run -c release sing-midi2-rehearsal examples/sustained-melisma.json /tmp/sing-expressive.wav --realtime --articulated --expressive --vibrato
swift run sing-macos-output examples/three-syllables.json --probe
# plays quietly on the machine's default output only when explicitly requested:
swift run sing-macos-output examples/sustained-melisma.json --play --articulated --expressive --vibrato
python3 -m unittest discover -s tests -v
python3 tools/check_phrase.py examples/three-syllables.json
python3 tools/check_phrase.py examples/sustained-melisma.json
```

The Swift tests measure deterministic PCM, typed MIDI 2.0 Note On/Off, Polyphonic Pressure, Pitch Bend and Breath CC2 events, malformed/reserved-field rejection, fundamental-frequency shifts, noise-vs-loudness distinction, buffer-size invariance, sustained melisma, optional vibrato, quiet release and CoreMIDI exclusion. They also verify WAV output, reject unknown phonemes and require silence for the no-note control. The Python validator checks phrase/note alignment and rejects false authored rendering or release states, with optional full JSON Schema validation when the `jsonschema` package is installed. These tests verify **sample production, not perceived intelligibility**, human consent, musicality or physical MIDI delivery. No GitHub CI is configured.

## Evidence standard

Audited code ≠ built package ≠ integrated renderer ≠ audible output ≠ authorized release. Every milestone must name its evidence. Public links to private repositories resolve only for authorized readers. Do not run GitHub Actions or publish a site as an incidental side effect. Git is source authority; deployment is separately authorized and verified.

Created 2026-10-21. © Fountain Coach contributors; rights of source materials and dependencies remain with their respective owners. No blanket code/media licence is granted by repository visibility.
