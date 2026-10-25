#!/usr/bin/env python3
"""Finite, PREDECLARED local speech-source acceptance candidates for Sing.

No lyrics, phoneme labels, or score enter Apple/PocketSphinx inference.
This creator records intended score text separately for AFTER decoding,
the literal local TTS spellings, source PCM hashes and provisional timing.
A matching transcript is a *lexical witness only*, never a recognized
phoneme, independent human listener, singer identity, or public voice.
"""
from __future__ import annotations

import hashlib
import itertools
import json
import math
from pathlib import Path
import struct
import subprocess
import tempfile
import wave

OUTPUT=Path("/tmp/sing-spoken-reference-cohort-20261025")
VOICES=("Kathy","Samantha","Karen","Kate (Enhanced)","Moira")
SYLLABLES=(("la","lah"),("mi","me","mee"),("na","nah"))
SYLLABLE_IDS=("s1","s2","s3")
RATE=48000
RATE_SPEECH=125
REGION_PADDING=7200
MAX_SOURCE_BYTES=2_000_000


def sha(data):
    return hashlib.sha256(data).hexdigest()


def load_pcm16(path):
    with wave.open(str(path),"rb") as src:
        if (src.getnchannels(),src.getsampwidth(),src.getframerate(),src.getcomptype())!=(1,2,RATE,"NONE"):
            raise ValueError("Local synthesis failed PCM16 48kHz constraint")
        pcm=src.readframes(src.getnframes())
    if len(pcm)>MAX_SOURCE_BYTES:
        raise ValueError("Unbounded generated reference")
    return list(struct.unpack("<"+"h"*(len(pcm)//2),pcm))


def isolate_activity(pcm):
    hop=480
    rms=[]
    for i in range(0,len(pcm),hop):
        b=pcm[i:i+hop]
        rms.append(math.sqrt(sum(float(x)*x for x in b)/len(b)))
    peak=max(rms,default=0)
    if peak<100:raise ValueError("TTS candidate has no audible signal")
    active=[i for i,x in enumerate(rms) if x>max(80,peak*.06)]
    if not active:raise ValueError("TTS candidate contains no speech activity")
    lo=max(0,active[0]*hop-960)
    hi=min(len(pcm),(active[-1]+1)*hop+960)
    if hi-lo<.20*RATE or hi-lo>2*RATE:
        raise ValueError("Bad synthetic syllable duration")
    return pcm[lo:hi]


def write_wav(path,pcm):
    with wave.open(str(path),"wb") as out:
        out.setnchannels(1);out.setsampwidth(2);out.setframerate(RATE)
        out.writeframes(struct.pack("<"+"h"*len(pcm),*pcm))
    return sha(path.read_bytes())


def plan():
    return {
        "schema":"sing.private-speech-source-search.v1",
        "plannedBeforeAcousticInference":True,
        "voices":list(VOICES),
        "utteranceSpellingOptions":list(map(list,SYLLABLES)),
        "utteranceIDs":list(SYLLABLE_IDS),
        "speechRate":RATE_SPEECH,
        "sourceScoreIntendedText":"la mi na",
        "acceptedStrictLexicalForms":["la me na","la mi na","lah me nah"],
        "equivalencePolicy":"only literal separately predeclared phrases; no variants added after ASR",
        "admissionRequirement":"independent lexical match AND measured phone boundary AND independent phone identity; lexical match alone not qualification",
        "noHumanPhonemeTruthClaim":True,
        "rawAudioPublishingAuthorized":False,
        "macOSVoicesMayBeUsedPrivatelyNotAsVoicebank":True,
        "sourceTextNotSuppliedToSpeechRecognizer":True
    }


def main():
    OUTPUT.mkdir(parents=True,exist_ok=True)
    conf=plan()
    plan_bytes=(json.dumps(conf,indent=2,sort_keys=True)+"\n").encode()
    plan_file=OUTPUT/"plan.json"
    if plan_file.exists() and plan_file.read_bytes()!=plan_bytes:
        raise ValueError("Cannot change predeclared speech search plan")
    plan_file.write_bytes(plan_bytes)
    rows=[]
    rejected=[]
    with tempfile.TemporaryDirectory(prefix="sing-spoken-corpus-source-",dir="/tmp") as staging:
        cache={}
        for voice in VOICES:
            for position,words in enumerate(SYLLABLES):
                for spelling in words:
                    aid=f"{VOICES.index(voice):02d}-{position}-{words.index(spelling)}"
                    aiff=Path(staging)/(aid+".aiff")
                    wav=Path(staging)/(aid+".wav")
                    subprocess.run(["/usr/bin/say","-v",voice,"-r",str(RATE_SPEECH),
                                    "-o",str(aiff),spelling],check=True,
                                   stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,timeout=35)
                    subprocess.run(["/usr/bin/afconvert","-f","WAVE","-d","LEI16@48000",
                                    "-c","1",str(aiff),str(wav)],check=True,
                                   capture_output=True,timeout=30)
                    try:
                        cache[(voice,position,spelling)]=isolate_activity(load_pcm16(wav))
                        print("SYNTHESIZED",voice,position,spelling,flush=True)
                    except ValueError as e:
                        # This is an independently predeclared SOURCE QUALITY
                        # criterion, never tuned after word recognition. Reject
                        # the syllable and every combination that needs it.
                        cache[(voice,position,spelling)]=None
                        rejected.append({
                            "voice":voice,"position":position,
                            "spokenSpelling":spelling,
                            "reason":str(e)
                        })
                        print("REJECTED_UNQUALIFIED_INPUT",voice,position,
                              spelling,str(e),flush=True)
        for voice in VOICES:
            for indices in itertools.product(*(range(len(opts))for opts in SYLLABLES)):
                spellings=tuple(SYLLABLES[j][idx]for j,idx in enumerate(indices))
                cid=f"v{VOICES.index(voice):02d}-"+ "".join(str(i)for i in indices)
                if any(cache[(voice,k,spelling)] is None
                       for k,spelling in enumerate(spellings)):
                    continue
                assembled=[]
                regions=[]
                for k,spelling in enumerate(spellings):
                    seq=cache[(voice,k,spelling)]
                    onset=len(assembled)
                    attack=min(int(.10*RATE),max(int(.025*RATE),len(seq)//4))
                    assembled.extend(seq)
                    regions.append({
                        "syllableId":SYLLABLE_IDS[k],
                        "onsetStartFrame":onset,
                        "vowelStartFrame":onset+attack,
                        "vowelEndFrame":len(assembled)
                    })
                    assembled.extend([0]*REGION_PADDING)
                wav=OUTPUT/(cid+".wav")
                proposed=Path(staging)/(cid+"-new.wav")
                digest=write_wav(proposed,assembled)
                if wav.exists():
                    if sha(wav.read_bytes())!=digest:
                        raise ValueError("Existing private cohort WAV drift: refusing to overwrite "+cid)
                else:
                    wav.write_bytes(proposed.read_bytes())
                manifest={
                    "schema":"sing.speech-source.v1",
                    "sourceKind":"macos-system-speech-local-control-not-openai",
                    "sourceModelOrVoice":"macOS say / "+voice,
                    "sourceText":"la mi na",
                    "spokenSpellingAttempts":list(spellings),
                    "sampleRate":RATE,
                    "sourceWavSHA256":digest,
                    "alignmentStatus":"provisional",
                    "release":"not-admitted",
                    "rightsDeclaration":"Private system voice test only; no cloning, public media or voice-bank rights",
                    "regions":regions,
                }
                m=OUTPUT/(cid+".json")
                manifest_text=json.dumps(manifest,indent=2,sort_keys=True)+"\n"
                if m.exists() and m.read_text()!=manifest_text:
                    raise ValueError("Existing private cohort manifest drift: refusing to overwrite "+cid)
                if not m.exists():
                    m.write_text(manifest_text)
                rows.append({
                    "candidateId":cid,"voice":voice,"spokenSpellings":list(spellings),
                    "audioPath":str(wav),"audioSHA256":digest,
                    "manifestPath":str(m),"manifestSHA256":sha(m.read_bytes()),
                    "sourcePhonemeTiming":"provisional",
                    "published":False
                })
    result={
        "schema":"sing.private-speech-source-cohort.v1",
        "planSHA256":sha(plan_bytes),
        "targetScoreText":"la mi na",
        "plannedCombinationCount":len(VOICES)*math.prod(len(x) for x in SYLLABLES),
        "candidateCount":len(rows),
        "rejectedSourceSyllables":rejected,
        "sourceQualityDropoutsAreNotRelaxed":True,
        "recordings":rows,
        "acceptance":"UNASSESSED: no reference has passed independent inference",
        "privateMediaOnly":True
    }
    dest=OUTPUT/"cohort.json"
    if dest.exists() and json.loads(dest.read_text())!=result:
        raise ValueError("Predeclared source cohort is not byte-identical on replay")
    dest.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print("PRIVATE_COHORT",str(dest),"count",len(rows),
          "planSHA",result["planSHA256"],flush=True)


if __name__=="__main__":
    main()
