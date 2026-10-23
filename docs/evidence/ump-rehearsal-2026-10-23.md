# Sing MIDI 2.0 UMP, no CoreMIDI — local execution witness (23 October 2026)

## Decision
The author explicitly rejected CoreMIDI as a dependency or route for sing. The authoritative interface uses the existing Fountain-Coach/midi2 **MIDI2 library target**, pinned to release 0.12.8, for typed 64-bit Universal MIDI Packets. **No CoreMIDI**, Apple Audio Unit, TeatroAppleBridge, MIDI 1.0 fallback, new transport, or vendor voicebank is admitted to this sing slice.

## What was actually executed
- Swift library target **SingMIDI2** creates MIDI 2.0 channel-voice Note On / Note Off via MIDI2 typed message types and reads the resulting UmpPacket64 packets back through the imported typed parser.
- Validated monotonic millisecond-timestamped in-process packet sequence -> authored syllable assignment held outside MIDI -> procedural SingVoice rendering -> 48,000 Hz, 16-bit mono PCM WAV.
- A typed 32-bit PolyPressure UMP applied at 650 milliseconds to the second syllable changes measured acoustic output through 12 ms amplitude smoothing.
- The original 6-packet UMP roundtrip produces exactly the same audio bytes as the original non-MIDI fixture. The expressive variant contains 7 packets. A negative test rejects malformed packet type, out-of-order packets, wrong MIDI group, unmatched Note Off, and incomplete note streams. Unsupported events fail closed.
- There is **no live endpoint, network transport, hardware event delivery, real-time audio callback, ear witness, actual intelligibility verdict or approved release**. This is not a claim of CoreMIDI-free physical transport.

## Local commands (Apple Silicon macOS)
    swift package resolve
    swift test -j 4
    python3 -m unittest discover -s tests -q
    python3 tools/check_phrase.py examples/three-syllables.json
    swift run -c release sing-midi2-rehearsal examples/three-syllables.json /tmp/sing-midi2-ump-native.wav
    swift run -c release sing-midi2-rehearsal examples/three-syllables.json /tmp/sing-midi2-ump-pressure.wav --pressure
    shasum -a 256 /tmp/sing-midi2-ump-native.wav /tmp/sing-midi2-ump-pressure.wav

## Outputs — NOT tracked in public Git
- Source fixture: 3 authored notes / 3 source syllables.
- Nonexpressive: 6 MIDI 2.0 UMP packets, 75,120 audio frames, 1.565 s, peak 0.580, RMS 0.24071. SHA-256: 5bd2ada8a22bb0cfbb861f6d94231fe0e521edeb9eeadd501b105e5870ff6bc9.
- PolyPressure variant: 7 packets, 75,120 frames, peak 0.580, RMS 0.21058. SHA-256: f8073dd7ae02e31638498454ea21e1b66986e609dc7333c04fdc.
- Neither variant has been judged intelligible by a human listener; they have no authorized publication status.

## Current limitations / deliberate rejections
- This rehearsal is **monophonic**, one advancing note per syllable. Melisma and legato remain pending.
- UMP events are timestamped in whole milliseconds in a local test harness, not scheduled from external clocks or sample-accurate live device I/O.
- Amplitude pressure is tested; continuous MIDI 2.0 pitch, timbre and live per-note controls remain pending.
- Normalization is for a private audition, not a mastered release; acoustic quality cannot be judged by numeric RMS alone.
- No new transport layer; no assumed use of Apple CoreMIDI under the guise of native MIDI 2.0.
- A real transport must be chosen and witnessed separately under FCIS one-MIDI-plane governance, and never added as a hidden prerequisite to the singer.
