# sing

**MIDI 2.0-native singing instruments for Fountain Coach.**

**Status: architecture and source audit, 21 October 2026. No native singing render is claimed.**

A voice is an instrument, a syllable is a timed phonetic state, and a performance is an executable score. **sing** makes text, phonemes, notes, expression, performer identity, and verifiable sound independently addressable. Its reference is Plogue Alter/Ego's playable lyric-and-MIDI workflow—not a fork or claim about its proprietary internals.

## Position in the estate

- **[Satzfunk](https://github.com/Fountain-Coach/Satzfunk)** (private source authority) is the manuscript-addressed listening, editorial approval and publication context: First Reading → First Hearing.
- **[Reframe](https://github.com/Fountain-Coach/Reframe)** owns source text, selected passage, edition, identity and reader/writer decisions.
- **[Teatro](https://github.com/Fountain-Coach/Teatro)**, **[ScoreKit](https://github.com/Fountain-Coach/ScoreKit)** and **[AudioTalk](https://github.com/Fountain-Coach/AudioTalk)** express scenes, temporal notation, performance intent.
- **[midi2](https://github.com/Fountain-Coach/midi2)** is the typed Universal MIDI Packet and instrument-transport foundation; **[midi2sampler](https://github.com/Fountain-Coach/midi2sampler)** contributes sample DSP, not a completed singer.
- **sing** owns phonetic alignment, voice identity/capability contracts, renderer-neutral vocal performance, comparison and instrument tests. No duplicate editorial coordinator, MIDI transport or generic DAW.
- **[instruments.fountain.coach](https://github.com/Fountain-Coach/instruments.fountain.coach)** may catalogue admitted instrument identities; it is a supporting reference domain, not a new public editorial front.

## One voice; many performances

A source passage and its hash are not a voice bank. A voice bank and its licence are not a score. An executable score and its renderer are not a published First Hearing. Keeping these separate lets one score be performed by Alter/Ego, a native sample/formant singer, a consented human voice, or an explicitly qualified future neural model.

**7VST / Seven Against Thebes** is the documented historical specimen: a 2017 Alter/Ego/Bidule/ARIA experiment and privately restored audio/text evidence. New renditions are **new editions**, never silently labelled as the historical production. See [7VST lineage](docs/7vst-case-study.md).

**Satzfunk offspring** may be independently versioned voices, choirs, pronunciation models, scores, or small autonomous performance agents with explicit parentage, controlled execution, provenance and rights. “Babies” means independent artistic instruments, not unbounded code replication. See [offspring contract](docs/offspring.md).

## Documentation and first milestone

- [Architecture and instrument boundaries](docs/architecture.md)
- [Code audit: Fountain Coach + Contexter](docs/source-audit-2026-10-21.md) and [immutable upstream Git pins](docs/audit-pins-2026-10-21.json)
- [Alter/Ego compatibility reference](docs/alterego-reference.md)
- [7VST historical source and new score](docs/7vst-case-study.md)
- [Satzfunk family / offspring](docs/offspring.md)
- [Executable acceptance scenario and roadmap](docs/roadmap.md)
- [Publishing, consent and rights](docs/rights-and-release.md)
- [Provisional performance JSON schema](schemas/sing-phrase-v1.schema.json) and [synthetic phrase example](examples/three-syllables.json)

**First acceptance:** one intentionally synthetic three-syllable phrase, three timed MIDI notes, a real renderer, isolated recorded audio, and a verifiable execution receipt. Follow with a multi-note vowel (melisma) and note-off release. No historical dramatic text, voice banks, passwords or audio exports belong in this public repository.

## Local documentary test

```sh
python3 -m unittest discover -s tests -v
python3 tools/check_phrase.py examples/three-syllables.json
```

The validator checks phrase/note alignment and rejects false rendering or release states. It additionally checks the complete JSON Schema only when the optional `jsonschema` Python package is installed. These tests do **not** synthesize or verify audio. No GitHub CI is configured.

## Evidence standard

Audited code ≠ built package ≠ integrated renderer ≠ audible output ≠ authorized release. Every milestone must name its evidence. Public links to private repositories resolve only for authorized readers. Do not run GitHub Actions or publish a site as an incidental side effect. Git is source authority; deployment is separately authorized and verified.

Created 2026-10-21. © Fountain Coach contributors; rights of source materials and dependencies remain with their respective owners. No blanket code/media licence is granted by repository visibility.
