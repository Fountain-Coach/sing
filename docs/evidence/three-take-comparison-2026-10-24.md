# Three-take listening comparison — 24 October 2026

## What was implemented

A single rights-free synthetic score, `examples/sustained-melisma.json`, now supports three distinct, reproducible performances through the **same** Fountain Coach SingVoice instrument. A user-visible comparison is part of the current conversation, without publishing media into Git, EstatePublisher, or Satzfunk.

- **Plain:** normal independent vowel/formant synthesis, four notes across three syllables, no synthetic expression events, no added onset articulation.
- **Articulated:** the same score/notes, but longer voiced /m/ and /n/ onsets, a shorter transition to the vowel, and a bounded deterministic nasal release transient. This is a prototype of nasal articulation, not a claim of comprehensible speech.
- **Expressive:** the articulated mode plus two typed MIDI 2.0 channel pitch-bend packets (±2-semitone range), two standard 32-bit Breath Controller CC2 packets and 24-cent 5.3 Hz vibrato. Four notes remain three syllables: the first vowel persists through the melisma without consonant retriggering.

The native path remains **Fountain-Coach/midi2 v0.12.8 typed Universal MIDI Packets → SingMIDI2 preflight → RealtimeSinger PCM**. CoreMIDI, MIDI 1.0 fallback, DAW and proprietary sample voices are absent. The separate macOS AVAudioEngine adapter is an **audio host**, not a MIDI transport.

## Mac native artifacts — private, not in repository

| Mode | Local native WAV | SHA-256 |
| --- | --- | --- |
| Plain | `/tmp/sing-plain-compare.wav` | `f4826365089889eafef579f5e0b3cf6f77d7bf570fcc0fa6e1d5f85ef191cf24` |
| Articulated | `/tmp/sing-articulated-compare.wav` | `1d285c6b0a9dd2f7b7be58aac1509b5f55bcac5e3636c530cbec25f20db8f505` |
| Expressive | `/tmp/sing-expressive-compare.wav` | `b7390503bdcb4669235fc417e0d21f8008c578f59228ab7ee0817e3df3ff8d27` |

Every file is **249,600 frames, 48,000 Hz, 16-bit PCM mono, 5.2 seconds**. Native compiler reports linear full-scale RMS / peak: plain 0.132041 / 0.378954, articulated 0.132780 / 0.378954, expressive 0.135014 / 0.505872. All have a low-amplitude note-release tail. These numbers do **not** prove human intelligibility.

The same three bitstreams were independently reconstructed in the local chat container from a small portable reference calculation of the original source/filter DSP. **All three full-file WAV SHA-256 digests matched their native Mac outputs exactly**, including pitch-bend quantization. This is an output parity witness, not a new product runtime or duplicate MIDI architecture. M4A/AAC 48 kHz mono derivatives and a ZIP with all three were separately created for in-chat playback and checked with ffprobe and zip integrity. The lossless Mac-source WAV checksums are authoritative; lossy M4A byte identity is not asserted.

## Test and execution witness

On Apple Silicon macOS with Swift 6.3.3, `swift test -j 4` completed **22 Swift XCTest cases with zero failures**, alongside **five original Python phrase tests**. The additional case `testPlainArticulatedExpressiveSameScoreThreeDifferentPCM` proves all three variants share one authored score, yield different waveform samples, affect the /m/ onset interval, and have repeatable expressive PCM across differently sized audio buffers. The host also supports `--articulated`, allowing an exact apples-to-apples macOS output comparison. The full external JSON Schema check was not witnessed because its optional Python dependency was absent.

### Reproduce on the authorized Mac

    cd ~/Developer/sing
    swift test -j 4
    python3 -m unittest discover -s tests -q
    python3 tools/check_phrase.py examples/sustained-melisma.json
    swift run -c release sing-midi2-rehearsal examples/sustained-melisma.json /tmp/sing-plain-compare.wav --realtime
    swift run -c release sing-midi2-rehearsal examples/sustained-melisma.json /tmp/sing-articulated-compare.wav --realtime --articulated
    swift run -c release sing-midi2-rehearsal examples/sustained-melisma.json /tmp/sing-expressive-compare.wav --realtime --articulated --expressive --vibrato
    shasum -a 256 /tmp/sing-{plain,articulated,expressive}-compare.wav
    swift run sing-macos-output examples/sustained-melisma.json --probe --articulated
    # Actual audio output action, not passive:
    swift run sing-macos-output examples/sustained-melisma.json --play --articulated --expressive --vibrato

## Not admitted

No author listening verdict was recorded, no validated naturalistic singing, physical microphone/analogue loopback, under-load callback jitter or external MIDI 2.0 transport was witnessed, and **no public First Hearing** was approved. Listener recognition of la/mi/na, naturalness of the synthesized nasal consonants, and editorial admission remain separate outstanding gates.
