#!/usr/bin/env python3
"""Opt-in private OpenAI Realtime speech capture. NOT a singing recognizer.

A current supported Realtime API supplies *spoken* syllables; no OpenAI
API is part of the performance engine. Needs OPENAI_API_KEY and the optional
websockets Python package, only when actually capturing. Dry-run is offline.
Public Git never contains input PCM, output PCM, credentials, or manifests.
"""
import argparse
import asyncio
import base64
import hashlib
import json
import os
import struct
import subprocess
import tempfile
import wave
from pathlib import Path

from make_macos_say_fixture import isolate_activity, load_pcm16

MODEL = "gpt-realtime-2.1-mini"
VOICE = "marin"
SOURCE_TEXT = "la mi na"
SYLLABLES = (
    ("s1", "la", "Pronounce the single sung-text syllable 'la' as spoken 'lah'."),
    ("s2", "mi", "Pronounce the single sung-text syllable 'mi' as spoken 'mee'."),
    ("s3", "na", "Pronounce the single sung-text syllable 'na' as spoken 'nah'."),
)


def response_event(target: str, voice: str):
    return {
        "type": "response.create",
        "response": {
            "conversation": "none",
            "output_modalities": ["audio"],
            "audio": {
                "output": {
                    "voice": voice,
                    "format": {"type": "audio/pcm", "rate": 24000}
                }
            },
            "instructions": (
                "Provide naturalistic SPOKEN speech only, NOT singing. "
                "Speak exactly the requested syllable once, slightly slowly, "
                "with a distinct consonant and a stable natural vowel. "
                "No extra commentary, no other word, no background sound."
            ),
            "input": [{
                "type": "message", "role": "user",
                "content": [{"type": "input_text", "text": target}],
            }],
        },
    }


async def wait_type(websocket, types):
    while True:
        message = json.loads(await asyncio.wait_for(websocket.recv(), timeout=25))
        kind = message.get("type")
        if kind == "error":
            raise RuntimeError("Realtime API reported an error; no media will be saved")
        if kind in types:
            return message


async def capture_one(websocket, instructions, voice):
    await websocket.send(json.dumps(response_event(instructions, voice)))
    pieces = []
    transcript = []
    completed = None
    while completed is None:
        message = json.loads(await asyncio.wait_for(websocket.recv(), timeout=40))
        kind = message.get("type")
        if kind == "error":
            raise RuntimeError("Realtime API returned an error during speech capture")
        if kind == "response.output_audio.delta":
            pieces.append(base64.b64decode(message["delta"], validate=True))
        elif kind == "response.output_audio_transcript.done":
            transcript.append(str(message.get("transcript", "")))
        elif kind == "response.done":
            completed = message.get("response", {}).get("status")
    if completed != "completed" or not pieces:
        raise RuntimeError("Realtime response is incomplete or contains no PCM audio")
    pcm = b"".join(pieces)
    if len(pcm) < 24000 or len(pcm) % 2:
        raise RuntimeError("Invalid or implausibly short 24kHz 16-bit mono speech response")
    return pcm, " ".join(transcript)


async def capture(args):
    try:
        import websockets
    except ImportError as exc:
        raise RuntimeError(
            "Optional capture dependency missing: install 'websockets>=14,<17' "
            "in a local Python virtualenv; never install a service") from exc
    token = os.getenv("OPENAI_API_KEY")
    if not token:
        raise RuntimeError("OPENAI_API_KEY unavailable: no OpenAI capture attempted")
    headers = {"Authorization": "Bearer " + token}
    url = "wss://api.openai.com/v1/realtime?model=" + MODEL
    results = []
    async with websockets.connect(url, additional_headers=headers, open_timeout=20,
                                  max_size=10_000_000) as connection:
        await wait_type(connection, {"session.created"})
        await connection.send(json.dumps({
            "type": "session.update",
            "session": {
                "type": "realtime",
                "output_modalities": ["audio"],
                "audio": {"output": {"voice": args.voice,
                                     "format": {"type": "audio/pcm", "rate": 24000}}},
            },
        }))
        await wait_type(connection, {"session.updated"})
        for name, label, instruction in SYLLABLES:
            pcm, transcript = await capture_one(connection, instruction, args.voice)
            results.append((name, label, pcm, transcript))
    return results


def persist_private(results, prefix: Path, voice: str):
    with tempfile.TemporaryDirectory(prefix="sing-openai-", dir="/tmp") as temp:
        folder = Path(temp)
        assembled, regions, transcripts = [], [], []
        for name, label, raw, transcript in results:
            original = folder / (name + "-24k.wav")
            converted = folder / (name + "-48k.wav")
            with wave.open(str(original), "wb") as output:
                output.setnchannels(1)
                output.setsampwidth(2)
                output.setframerate(24000)
                output.writeframes(raw)
            subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16@48000", "-c", "1",
                            str(original), str(converted)], check=True)
            pcm = load_pcm16(converted)
            start, end = isolate_activity(pcm)
            active = pcm[start:end]
            if len(active) < 10080:
                raise ValueError("Speech source too short to admit stable vowel for " + name)
            onset = len(assembled)
            onset_frames = min(4800, max(1200, len(active) // 4))
            assembled.extend(active)
            regions.append({
                "syllableId": name,
                "onsetStartFrame": onset,
                "vowelStartFrame": onset + onset_frames,
                "vowelEndFrame": len(assembled),
            })
            assembled += [0] * 7200
            transcripts.append({"syllableId": name, "target": label,
                                "unverifiedModelTranscript": transcript})
        wav_path = Path(str(prefix) + ".wav")
        with wave.open(str(wav_path), "wb") as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(48000)
            output.writeframes(struct.pack("<" + "h" * len(assembled), *assembled))
        digest = hashlib.sha256(wav_path.read_bytes()).hexdigest()
        manifest = {
            "schema": "sing.speech-source.v1",
            "sourceKind": "openai-realtime-api-private-capture",
            "sourceModelOrVoice": MODEL + " / " + voice,
            "sourceText": SOURCE_TEXT,
            "sampleRate": 48000,
            "sourceWavSHA256": digest,
            "rightsDeclaration": (
                "OpenAI-generated private research only. Reuse, derivation, "
                "distribution, watermark treatment, and licensing require explicit review."
            ),
            "alignmentStatus": "provisional",
            "release": "not-admitted",
            "regions": regions,
        }
        Path(str(prefix) + ".json").write_text(json.dumps(manifest, indent=2) + "\n")
        Path(str(prefix) + ".capture.json").write_text(json.dumps({
            "capture": "OpenAI Realtime WebSocket audio-only generation",
            "model": MODEL, "voice": voice,
            "sourceSHA256": digest,
            "unverifiedTranscripts": transcripts,
            "status": "not-phoneme-verified; not-singing; not-published",
        }, indent=2) + "\n")
        print(json.dumps({
            "speechWav": str(wav_path),
            "manifest": str(prefix) + ".json",
            "captureReceipt": str(prefix) + ".capture.json",
            "sourceSHA256": digest,
            "status": "private captured speech; not independent phonetic recognition",
        }, indent=2))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--voice", default=VOICE,
                        choices=["alloy", "ash", "ballad", "coral", "echo",
                                 "sage", "shimmer", "verse", "marin", "cedar"])
    parser.add_argument("--prefix", default="/tmp/sing-openai-speech")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--private-research", action="store_true")
    args = parser.parse_args()
    prefix = Path(args.prefix).expanduser().resolve()
    if not (str(prefix).startswith("/tmp/") or str(prefix).startswith("/private/tmp/")):
        parser.error("Private sources may only be saved under /tmp")
    if args.dry_run:
        print(json.dumps({
            "model": MODEL, "voice": args.voice, "api": "Realtime WebSocket",
            "sourceText": SOURCE_TEXT,
            "exampleFirstResponse": response_event(SYLLABLES[0][2], args.voice),
            "network": False, "mediaCaptured": False,
        }, indent=2))
        return
    if not args.private_research:
        parser.error("Explicit --private-research required before a billable network call")
    prefix.parent.mkdir(parents=True, exist_ok=True)
    captured = asyncio.run(capture(args))
    persist_private(captured, prefix, args.voice)


if __name__ == "__main__":
    main()
