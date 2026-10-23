# Real-time PCM boundary: MIDI 2.0 → singing voice → macOS output (23 October 2026)

## Scope and architectural rule

This stage follows Fountain Coach's explicit **no CoreMIDI** direction. No CoreMIDI, virtual MIDI driver, MIDI 1.0 conversion or Apple MIDI endpoint is used. Existing Fountain-Coach/midi2 version 0.12.8 supplies real typed UMP Note On / Note Off / PolyPressure packets. SingMIDI2 decodes the packets during off-thread preflight, retaining lyrics and phonemes only in the independently authored source. A bounded, frame-addressed event schedule drives **RealtimeSinger**.

The output adapter is a separate macOS executable, sing-macos-output. It uses AVFoundation's AVAudioEngine / AVAudioSourceNode only to deliver Float32 PCM to a system audio output. Its audio callback receives a preallocated output buffer and runs the same RealtimeSinger PCM loop used for deterministic offline rehearsal. SingVoice and SingMIDI2 import no host audio or MIDI APIs. The main Swift package has no new audio server, service process, MIDI transport or Creative Coding framework.

## Local acceptance evidence

On the connected Apple Silicon Mac, Swift 6.3.3, on 23 October 2026:

- **15 Swift tests passed, zero failed**, including original SingVoice regression tests, authentic typed UMP packets, note lifecycle and validation, pressure expression, source prohibition of CoreMIDI, deterministic callback-size comparisons, melisma without consonant retrigger, and low-amplitude release tail.
- **5 original Python phrase-contract tests passed**, zero failed. Optional Python jsonschema was unavailable in the local environment; full external JSON Schema validation was not witnessed here.
- A 48 kHz monophonic private audio fixture through RealtimeSinger produced 90,240 frames / 1.88 seconds. Rendering in 37-frame and 1024-frame blocks yielded exactly identical Float32 samples; repeated reset/rerender also agreed.
- The synthetic four-note melisma test spans two notes on the first syllable, without a new consonant; the observable articulation count is **3**, not 4.
- In-process polyphonic-key-pressure UMP measurably changed generated audio amplitude.
- Baseline 16-bit WAV SHA-256: **688f402b537b79448ef346572591e7221246ab76a818f4fdf69c30c1eec0e7e7**.
- Pressure WAV SHA-256: **54ed4c5b492e46039b43b58372d87d3859a0511071499868e442b7b5c98461ff**.
- Offline rehearsal unnormalized output peak 0.3540 full scale; largest consecutive normalized PCM sample change 0.09317; RMS of last 100 ms of tail 0.000725. These are **technical diagnostics**, not perceptual singing-quality conclusions.
- macOS system_profiler reported PreSonus AudioBox iTwo as the default USB audio output, 48 kHz and two output channels at test time.
- sing-macos-output --probe reported 48,000 Hz stereo compatibility without starting an audio engine.
- sing-macos-output --play **successfully started AVAudioEngine and completed**, with RealtimeSinger reporting 90,240 source frames rendered, 6 source UMP events and 3 syllable articulations. Playback gain was intentionally reduced via AVAudioMixerNode outputVolume = 0.15.

## Exact commands

    cd ~/Developer/sing
    swift test -j 4
    python3 -m unittest discover -s tests -q
    python3 tools/check_phrase.py examples/three-syllables.json
    swift run -c release sing-midi2-rehearsal examples/three-syllables.json /tmp/sing-realtime-ump.wav --realtime
    swift run -c release sing-midi2-rehearsal examples/three-syllables.json /tmp/sing-realtime-ump-pressure.wav --realtime --pressure
    shasum -a 256 /tmp/sing-realtime-ump.wav /tmp/sing-realtime-ump-pressure.wav
    swift run sing-macos-output examples/three-syllables.json --probe
    swift run sing-macos-output examples/three-syllables.json --play

The --play mode actually uses the machine's default audio output. It is not a passive test. Do not run it as an automated background task or in a quiet environment without the author's express instruction.

## What this proves — and what it does NOT prove

**Proven:** the actual midi2 typed in-process Universal MIDI Packet event plane, preflighted timestamp schedule, bounded mono procedural voice, deterministic variable-block PCM engine, melisma support without duplicated consonants, expressive pressure, macOS AVAudioSourceNode and AVAudioEngine successful start and execution. The playback engine reported all expected samples processed.

**Not proven:** the author actually heard or recognized la mi na, analogue speaker/headphone loopback, acoustic capture, underrun-free output under stress, bounded worst-case callback latency, verified zero heap allocations across the Swift runtime, live transport or externally delivered MIDI packets, hardware MIDI 2.0 interoperability, consented human-voice performance or authorized publication. Real-time **architecture** is implemented; hard real-time worst-case performance is not certified.

## Next acceptance

1. Have the author listen and explicitly judge intelligibility and vocal character. Do not call non-silent waveforms meaningful singing.
2. Add controlled independent pitch/formant motion, breath/noise consonants, vowel stamina and longer melisma.
3. Witness non-CoreMIDI transport ingestion of real MIDI 2.0 packets in a separately authorized environment.
4. Test long-running callback jitter, memory allocations, fault containment and engine reset independently from the small offline fixtures.
5. Admit auditions to Teatro / Satzfunk only by those owning editorial and rights contracts. Keep raw private audio out of public Git.
