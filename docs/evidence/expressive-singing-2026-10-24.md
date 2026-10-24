# sing — native expressive-singing evidence, 24 October 2026

**Evidence status:** a verified, original procedural voice; successfully executed typed MIDI 2.0 synthetic expression, reproducible PCM, and an actual macOS audio-engine processing witness. **No independent human verdict that the syllables are intelligible; no analogue capture; no music or editorial release.**

## Architectural cut (authority and boundaries)

- sing owns phoneme/voice state, source/filter excitation, fixed formant coefficients, additive breath noise, optional vibrato, waveform and witness data.
- Imported **Fountain-Coach/midi2, release 0.12.8** owns the typed 64-bit Universal MIDI Packet message definitions. New real instrument events are Note On/Off, Polyphonic Pressure, channel Pitch Bend and **standard Control Change 2 (breath)**. Text/phonemes and licensing are never encoded as fake MIDI note events.
- Bend range is explicitly ±2 semitones, centered at MIDI 2.0 0x80000000. Bend moves fundamental frequency without shifting vowel formant coefficients. Note-off and new-note handling remain independent from phoneme identity.
- Breath CC2 carries 32-bit controller values. The voice filters the control with a 25 ms smoothing constant and adds seeded deterministic high-frequency airflow noise, not simply a volume adjustment. This is **a synthetic acoustic model, not a sampled human voice or proven natural breath sound**.
- Vibrato is an independent, author-selected synthesis setting, 5.3 Hz, rising after 180 ms with a 200 ms fade, with a bounded 0...50-cent configured depth; the comparison scenario uses 24 cents.
- SyntheticSingRehearsal is the single shared **synthetic audition scenario** used by the offline WAV program and macOS output host. It is neither a new instrument transport nor editorial authority.
- **CoreMIDI remains prohibited.** SingVoice and SingMIDI2 are transport-independent. The separate sing-macos-output executable only hosts the generated Float32 PCM with AVAudioEngine, at reduced mixer volume. No CoreMIDI, MIDI 1.0 fallback, vendor voicebank, website, or autonomous release is introduced.

## Synthetic source and generated output

- Fixture: examples/sustained-melisma.json, **original synthetic** 3 syllables la/mi/na mapped to 4 notes. First two notes share the same syllable with advanceSyllable=false on the second; only **three** onset articulations are expected.
- Fixture SHA-256: c56a0c95222e4229d75c44ec3e8f98542559afd633aac5e66b9772fd16983bdd.
- Expression includes two 32-bit MIDI 2.0 Pitch Bend messages and two standard CC2 breath messages; with 4 Note On and 4 Note Off packets the source score has **12 typed events**. Vibrato is voice state rather than a fake MIDI message.
- Private audition: /tmp/sing-sustained-expressive-2026-10-24.wav on the connected Mac; **48 kHz, 16-bit signed PCM, mono, 249,600 frames = 5.2 seconds**. Peak 0.505872, RMS 0.134288 (linear full scale).
- WAV SHA-256: 756c8acdebf1829d4b5d24f65f1f98454d5c6eae13fdd30c67199ea5f0a49152. Media is **not** checked into the public repository or admitted to Satzfunk.
- Existing 1.88-second control with zero expression retains SHA-256 688f402b537b79448ef346572591e7221246ab76a818f4fdf69c30c1eec0e7e7.

## Code and runtime verification

- **21 local Swift XCTest cases passed, 0 failed**, on Apple Silicon macOS, Swift 6.3.3, after new expression, packet-reserved-field and bounded-capacity tests. Tests verify a bend changes the measured fundamental by the expected semitone ratio while keeping the voice's formant coefficients independent, breath changes signal samples and is invariant across buffer sizes, optional vibrato is reproducible, melisma does not repeat the onset, and malformed/oversized packet streams fail closed. The decode preflight caps the scenario at 16,384 UMP messages.
- **5 existing Python authored-phrase tests passed, 0 failed.** The sustained melisma source passed the extra Python phrase validator (4 notes, 3 syllables, 1 melisma). The optional full JSON Schema library was missing, so the complete external JSON Schema check is **not** claimed.
- A real macOS AVAudioEngine probe returned a **48 kHz stereo** output contract with 12 scheduled events, but did not yet start the physical engine.
- sing-macos-output with --play --expressive --vibrato successfully started the PCM output engine; **249,600 audio frames** were consumed, and the RealtimeSinger callback reported **3 syllable articulations**. Gain stayed at the prior cautious mixer value of 0.15. The engine stopped normally.
- **This audio-engine execution is not a hearing test.** The callback's execution does not prove analogue delivery, acoustic clarity, output-device speaker presence, latency budget, underrun-free heavy load, or that the author heard the intended phonemes.
- The local Linux sandbox could not resolve github.com, so a **fresh Linux checkout/build of this revision was not verified**. Do not transfer the earlier Linux test result to this revision.

## Reproduction (locally on the authorized Mac)

    cd ~/Developer/sing
    swift test -j 4
    python3 -m unittest discover -s tests -q
    python3 tools/check_phrase.py examples/sustained-melisma.json
    swift run -c release sing-midi2-rehearsal examples/sustained-melisma.json /tmp/sing-sustained-expressive-2026-10-24.wav --realtime --expressive --vibrato
    shasum -a 256 examples/sustained-melisma.json /tmp/sing-sustained-expressive-2026-10-24.wav
    swift run sing-macos-output examples/sustained-melisma.json --probe --expressive --vibrato
    # --play is an actual audio output action, not a passive test
    swift run sing-macos-output examples/sustained-melisma.json --play --expressive --vibrato

## Remaining acceptance

1. Independent human listening and recognizable la/mi/na syllables; do not infer human perception from spectral metrics.
2. Improved plosives, fricatives, breathy phonation, vowel transitions and explicit moving-formant controls; the present formants are fixed and the onset crossfade is synthetic.
3. A bounded non-CoreMIDI live UMP input path, independently authorized and witnessed rather than substituted with a simulated packet stream.
4. Extended real-device measurement of callback timing, fault containment, allocations, underruns and sample-rate changes.
5. Only author-controlled Teatro/Satzfunk audition, rights review and separately authorized estate publication.
