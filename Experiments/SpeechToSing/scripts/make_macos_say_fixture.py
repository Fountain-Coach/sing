#!/usr/bin/env python3
"""Private, OFFLINE, explicitly provisional local speech fixture.

This uses macOS 'say', never OpenAI, and does not supply recognized phonemes.
It proves capture/PCM/provenance plumbing while the OpenAI adapter and
independent phoneme recognizer remain separately qualified dependencies.
No output is written into Git.
"""
import argparse
import hashlib
import json
import math
import struct
import subprocess
import tempfile
import wave
from pathlib import Path


def load_pcm16(path: Path):
    with wave.open(str(path), "rb") as source:
        if (source.getnchannels(), source.getsampwidth(), source.getframerate()) != (1, 2, 48000):
            raise ValueError("afconvert did not produce 48kHz mono PCM16")
        return list(struct.unpack("<" + "h" * source.getnframes(), source.readframes(source.getnframes())))


def isolate_activity(samples):
    frame = 480
    rms = []
    for pos in range(0, len(samples), frame):
        block = samples[pos : pos + frame]
        rms.append(math.sqrt(sum(float(v) * v for v in block) / max(1, len(block))))
    peak = max(rms, default=0.0)
    if peak < 100:
        raise ValueError("macOS speech fixture is silent")
    active = [i for i, value in enumerate(rms) if value > max(80.0, peak * 0.06)]
    if not active:
        raise ValueError("no active speech segment")
    start = max(0, active[0] * frame - 960)
    end = min(len(samples), (active[-1] + 1) * frame + 960)
    return start, end


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--voice", default="Samantha")
    parser.add_argument("--prefix", default="/tmp/sing-speech-macos")
    args = parser.parse_args()
    prefix = Path(args.prefix).expanduser().resolve()
    if not (str(prefix).startswith("/tmp/") or str(prefix).startswith("/private/tmp/")):
        parser.error("Private speech fixtures must remain in /tmp")
    prefix.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="sing-say-", dir="/tmp") as temporary:
        tmp = Path(temporary)
        assembled = []
        regions = []
        # Isolated utterances offer explicit segmentation boundaries;
        # this is NOT evidence that the internal consonant/vowel split is right.
        for index, (spelling, name) in enumerate((("la", "s1"), ("me", "s2"), ("na", "s3"))):
            source = tmp / f"{name}.aiff"
            converted = tmp / f"{name}.wav"
            subprocess.run(["say", "-v", args.voice, "-r", "125", "-o", str(source), spelling], check=True)
            subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16@48000", "-c", "1",
                            str(source), str(converted)], check=True)
            pcm = load_pcm16(converted)
            start, end = isolate_activity(pcm)
            active = pcm[start:end]
            # Speech onset-to-vowel timing is a heuristic, NOT phoneme recognition.
            # The project must later replace this with independently verified alignment.
            onset = len(assembled)
            onset_duration = min(int(0.10 * 48000), max(int(0.025 * 48000), len(active) // 4))
            if len(active) < int(0.21 * 48000):
                raise ValueError(f"{name}: vowel too short for pitch-synchronous synthesis")
            assembled.extend(active)
            regions.append({
                "syllableId": name,
                "onsetStartFrame": onset,
                "vowelStartFrame": onset + onset_duration,
                "vowelEndFrame": len(assembled),
            })
            assembled.extend([0] * 7200)  # 150ms isolation without reinterpretation as score rests
    path = Path(str(prefix) + ".wav")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(48000)
        output.writeframes(struct.pack("<" + "h" * len(assembled), *assembled))
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    manifest = {
        "schema": "sing.speech-source.v1",
        "sourceKind": "macos-system-speech-local-control-not-openai",
        "sourceModelOrVoice": "macOS say / " + args.voice,
        "sourceText": "la mi na",
        "sampleRate": 48000,
        "sourceWavSHA256": digest,
        "rightsDeclaration": "Private local system speech test only; no redistribution or voice bank rights implied",
        "alignmentStatus": "provisional",
        "release": "not-admitted",
        "regions": regions,
    }
    manifest_path = Path(str(prefix) + ".json")
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps({"speechWav": str(path), "manifest": str(manifest_path),
                      "sourceSHA256": digest, "regions": regions,
                      "status": "local-speech-only; not OpenAI; no independently validated phonemes"}, indent=2))


if __name__ == "__main__":
    main()
