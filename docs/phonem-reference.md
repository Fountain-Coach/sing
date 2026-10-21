# PPG Phonem for iPad — second singing-synthesis lineage

**Historical source note · 21 October 2026 · Fountain Coach / sing**

## Author testimony and evidence level

The author reports using **Wolfgang Palm's PPG Phonem for iPad extensively** and identifies the [Unpopular Electronics Bandcamp material](https://unpopular-electronics.bandcamp.com/video), including the historical 7VST context, as material in which Phonem may be heard. This is a newly recorded **first-person historical account**, not a measured audio attribution or evidence that Phonem generated every 7VST track.

Previously recovered 2017 Plogue Alter/Ego Bidule/ARIA files independently document **Alter/Ego** in specific historic sessions; they **do not exclude Phonem** from the wider performance. No original Phonem iPad preset/session, routed input, track stem, inter-app capture, timestamped application inventory or match to a particular Bandcamp track has yet been recovered and identified in the current source audit. Keep these levels of evidence separate.

Crosslinks:
- [Satzfunk's private 7VST restored edition](https://github.com/Fountain-Coach/Satzfunk/blob/main/docs/archaeology/2026-10-21-7vst-restored-private-edition.md)
- [Satzfunk private 7VST listening-browser source](https://github.com/Fountain-Coach/Satzfunk/blob/main/archive/browser/7vst-originals.html)
- [Satzfunk 7VST performance archaeology](https://github.com/Fountain-Coach/Satzfunk/blob/main/docs/archaeology/2026-10-21-7vst-original-performance-recovery.md)
- [Satzfunk archive Bandcamp-video source manifest](https://github.com/Fountain-Coach/Satzfunk/blob/main/archive/observations/unpopular-electronics-bandcamp-videos-2026-10-19.json)
- [Public artist's Bandcamp video page](https://unpopular-electronics.bandcamp.com/video)

The first three Satzfunk links above lead to a **private repository**. The locally playable restored archive is further restricted by its author-only LAN browser; this public document does not bypass its access controls.

## The instrument: not Plogue's Phoneme Sequencer

**PPG Phonem**, released for iPad in 2016 by Wolfgang Palm, is a distinct commercial vocal synthesizer, not the `com.Plogue.Sequencer.Phoneme` ARIA module. Its documented acoustic architecture is particularly relevant to sing:

- A **12-resonator** vocal-formant/filter bank, under full programmable control.
- Flexible **excitation** from a voice/glottal-like source, wavetables or time-corrected samples; voiced/noisy spectral energy can be sculpted independently.
- A phoneme inventory and editable articulation trajectories; a **pitch track** and control track provide two separable performance dimensions.
- Phrase/song mode, multi-parameter modulation, expressive vibrato/flutter/growl, glides, stretches/freezing/reversing.
- The 2016 iPad product supported an **Audio Unit extension**, Inter-App Audio, MIDI modes, and multiple instances in an AU host. These are historical product features, **not evidence of present-day installation, compatibility or source recovery**.

Public historical references:
- [MusicRadar 2016 — iPad features and modes](https://www.musicradar.com/news/tech/mobile-phonem-wolfgang-palms-ppg-vocal-synth-comes-to-ipad-641106)
- [Create Digital Music 2016 — resonator filter and singing architecture](https://cdm.link/ppg-phonem-now-also-ipad-synthesizes-sound-like-voice/)
- [Synth Anatomy 2016 — excitation, wavetable and sample systems](https://synthanatomy.com/2016/08/my-impressions-ppg-phonem-for-ipad.html)
- [Wolfgang Palm interview — development of voice analysis and synthesis](https://www.amazona.de/interview-wolfgang-palm-der-mann-der-ppg-erfand/)

These public descriptions document the commercial system's **observable design**, not its source code. Do not assert a precise DSP algorithm or reverse-engineered internal implementation without independent evidence.

## What Phonem teaches sing

Our initial Alter/Ego-centered architecture gave a strong place to licensed **recorded voices**. Phonem demonstrates a complementary singer architecture: a largely **procedural, source–filter instrument** capable of an intentionally synthetic voice without a sampled human identity. It therefore justifies two **equal native backends** behind one phrase performance contract:

1. **Sample / resynthesis voice:** consented phonetic corpus, sustained vowel loops, pitch/formant separation, transitions, native midi2sampler processing.
2. **Procedural resonator voice:** excitation oscillator + controllable harmonic/noise spectrum + resonator/formant trajectories + phoneme sequencer + continuous pitch and expression.

The phrase/phoneme score, Note On/Off schedule, melisma and author approval must remain common, **not** hardcoded to either vendor's internal preset representation. The new procedural backend should share actual midi2sampler DSP primitives where they apply; it does **not** require a voice bank or pretend to reproduce Phonem's proprietary implementation.

In the voice model, represent formant frequencies and bandwidths, excitation type, voicing and noise mix, aspiration, nasal resonance, consonant onset/release, vibrato and timing as controllable values. Each future MIDI 2.0 profile advertises exactly which of these are implemented, including intensity, vowel hold, per-note timbral expression and phase/legato continuity. Never claim full Phonem feature parity from a formant-filter proof of concept.

## Historic listening / forensics tasks

- Compare the [33-source Bandcamp video manifest](https://github.com/Fountain-Coach/Satzfunk/blob/main/archive/observations/unpopular-electronics-bandcamp-videos-2026-10-19.json) with the privately restored 18-part 7VST media. Do not silently replace historic source masters with playback captures.
- Use the private Satzfunk 7VST browser to listen for potentially recognisable Phonem passages **with the author**; note a candidate part and timecode, then seek confirming project/preset/stem evidence. Voice likeness alone is suggestive, not an instrument ID.
- Search surviving iPad backups, Audio Unit state, Inter-App Audio/Audiobus sessions, host files and preserved exports for Phonem state or render evidence **without changing archives**; report absence as unverified.
- Record individual track findings as `author-recollection`, `audio-candidate`, or `session-confirmed` alongside track ID, source export hashes and, where established, timecodes. Do not auto-tag all parts.
- A new `sing.resonator` scenario can demonstrate a self-contained procedural voice and compare it against the existing Plogue Marie Ork compatibility renderer as different **instrument designs**, not as imitations.

## Rights and status

PPG Phonem is proprietary. The application, banks, presets, brand identity and original code are not sing assets. The user-authored historic work and publicly documented signal principles can guide a **new, independently implemented** resonator singer; no copying code, licensed preset material or inaccessible iPad assets into Git. Current evidence in sing is **documentary**; no Phonem instrument or audio has been rebuilt, installed or independently heard for this revision.
