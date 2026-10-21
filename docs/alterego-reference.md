# Alter/Ego: reference backbone, not a proprietary fork

**21 October 2026.** Alter/Ego is the first compatibility target and practical acoustic reference for sing. We do **not** claim access to its synthesis algorithms, internals or rights to redistribute its voice banks.

## Verified recent history in the existing private project

[Satzfunk's instrument scenario](https://github.com/Fountain-Coach/Satzfunk/blob/main/docs/scenarios/2026-10-21-alterego-source-controlled-instrument.md) establishes:

- Official signed and notarized Plogue Alter/Ego 1.981, with arm64 Audio Unit and standalone components, installed on M2 macOS via the correct vendor package.
- Licensed Marie Ork 2.000 *clean* voice bank installed and retained (not the historical Daisy voice).
- Successful Audio Unit validation and an exact CoreMIDI AlterEgo destination.
- Repeatable MIDI-triggered non-silent captured **system-mix** audio at 48 kHz following a C4 note; this is **not** isolated offline Audio Unit capture, demonstrated phoneme synchronization, or recovered 2017 playback.
- A separate [ARIA state adapter](https://github.com/Fountain-Coach/Satzfunk/blob/main/scripts/alterego-state.py) that validates product 1019 and `com.Plogue.Sequencer.Phoneme` custom data (htype 9073), checks exact UTF-8 size and content hash, and derives private separate ARIA XML state without mutating the input. Nine synthetic cases passed on macOS and Ubuntu.
- Private original 2017 Vuo/Bidule source evidence for Daisy Star and Bones Basic; historic audio engine/preset identity is not inferred from the present Marie Ork result.

## What to reverse engineer *legitimately*

Treat the vendor plug-in as a black box: inspect documented preset serialization, MIDI input, timing, phonetic/lyric cursor behavior, output audio and plugin-state life cycle. Test precisely when state changes take effect, how note-on advances or holds phonemes, what note-off/legato means, how vibrato/formants behave, and how preset reloads reset state. Keep a reproducible observation table linking tested vendor version, voice and evidence.

Do not decompile or alter signed vendor binaries, evade licence protection, publish extracted proprietary voice material or represent reverse-engineered guesses as verified facts. Inspect licences before embedding the engine in a distributable product.

## Renderer adapter acceptance path

1. Generate one synthetic (not 7VST-copyrighted) lyric in an independent sing phrase contract.
2. Derive a **separate** private ARIA state from a validated original voice state via the existing Satzfunk tool; test import/preset recall and listen to the lyric.
3. Supply a three-note event sequence using a real CoreMIDI/Audio Unit route. Document MIDI2→MIDI1 loss at the final adapter, especially absent per-note control.
4. Capture isolated Audio Unit audio (not a system mix), record sample rate, sample count, hashes, renderer and voice-version references. Produce a no-note negative control and repeated event-capture test.
5. Compare this result with a separately implemented native sing renderer using exactly the same authored phrase and note schedule. Do not assume timbral equivalence.

This compatibility renderer is an **on-ramp** for a completely independent MIDI 2.0 singer. No need to model Plogue's private code to achieve an equivalent *workflow*.
