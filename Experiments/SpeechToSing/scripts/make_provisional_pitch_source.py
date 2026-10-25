#!/usr/bin/env python3
"""Private macOS high-register source, not a phoneme-qualified reference.

The local source target was chosen during exploratory development AFTER the
first lexical cohort; never misrepresent as a held-out witness. An embedded
macOS Speech Synthesis pitch-base control is local source production, not a
new MIDI2 voice transport or a model to distribute. Ear must still assess
the actual PCM, without receiving the tag or intended phrase.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import tempfile

from make_speech_reference_cohort import (
    RATE, REGION_PADDING, isolate_activity, load_pcm16, write_wav, sha
)
from vowel_anchor import private

VOICE="Karen"
PITCH_BASE=240
SPEECH_RATE=125
SPEAK=("la","me","na")
IDS=("s1","s2","s3")
DEFAULT_PREFIX="/tmp/sing-high-register-control-20261025/karen-pbas240"


def generate(prefix: str):
    path=private(prefix+".wav",False)
    meta=private(prefix+".json",False)
    if path.parent!=meta.parent:
        raise ValueError("Provenance files must stay together")
    assembled=[]
    regions=[]
    with tempfile.TemporaryDirectory(prefix="sing-private-pbas-",dir="/tmp") as tmp:
        for index,spelling in enumerate(SPEAK):
            base=Path(tmp)/str(index)
            tag=f"[[pbas {PITCH_BASE}]] "+spelling
            subprocess.run(
                ["/usr/bin/say","-v",VOICE,"-r",str(SPEECH_RATE),
                 "-o",str(base)+".aiff",tag],capture_output=True,
                check=True,timeout=35
            )
            subprocess.run(
                ["/usr/bin/afconvert","-f","WAVE","-d","LEI16@48000",
                 "-c","1",str(base)+".aiff",str(base)+".wav"],
                capture_output=True,check=True,timeout=30
            )
            trimmed=isolate_activity(load_pcm16(Path(str(base)+".wav")))
            onset=len(assembled)
            attack=min(int(.10*RATE),max(int(.025*RATE),len(trimmed)//4))
            assembled.extend(trimmed)
            regions.append({
                "syllableId":IDS[index],
                "onsetStartFrame":onset,
                "vowelStartFrame":onset+attack,
                "vowelEndFrame":len(assembled),
            })
            assembled.extend([0]*REGION_PADDING)
    if len(regions)!=3:
        raise ValueError("Incomplete original source phrase")
    if path.exists():
        # Verify an already selected private reference is reproducible,
        # never rewrite its original waveform without a new identity.
        import wave, struct
        with tempfile.TemporaryDirectory(dir="/tmp",prefix="sing-pbas-proof-")as directory:
            other=Path(directory)/"candidate.wav"
            new_digest=write_wav(other,assembled)
        if sha(path.read_bytes())!=new_digest:
            raise ValueError("Original private speech control drifted; fail closed")
        digest=new_digest
    else:
        digest=write_wav(path,assembled)
    manifest={
        "schema":"sing.speech-source.v1",
        "sourceKind":"macos-system-speech-pitch-baseline-control-not-openai",
        "sourceModelOrVoice":"macOS say / Karen / explicit pbas 240",
        "sourceText":"la mi na",
        "spokenSpellingAttempts":list(SPEAK),
        "pitchControlTag":"[[pbas 240]]",
        "sampleRate":RATE,
        "sourceWavSHA256":digest,
        "alignmentStatus":"provisional",
        "release":"not-admitted",
        "rightsDeclaration":"Local macOS speech research only, no voice-bank or media release",
        "regions":regions,
    }
    if meta.exists() and json.loads(meta.read_text())!=manifest:
        raise ValueError("Original provisional source manifest identity drifted")
    meta.write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n")
    return {"sourceSHA256":digest,"source":str(path),
            "manifestSHA256":sha(meta.read_bytes()),
            "manifest":str(meta),
            "sourceSelectedAfterExploratoryPitchTrial":True,
            "candidateAudioPublished":False,
            "phoneTimingIndependentlyVerified":False}


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--prefix",default=DEFAULT_PREFIX)
    args=parser.parse_args()
    print(json.dumps(generate(args.prefix),indent=2,sort_keys=True))


if __name__=="__main__":
    main()
