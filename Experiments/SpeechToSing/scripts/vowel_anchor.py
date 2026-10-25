#!/usr/bin/env python3
"""Sing PRIVATE vowel-anchor research renderer, side-by-side with native Swift.

Source: an immutable SHA-verified spoken WAV plus existing provisional regions.
Direction: the SAME Sing typed-MIDI2 phrase score, no new transport or MIDI1.
Keep source attack and coda samples intact; overlap-add retunes the vowel only.
Never classify phonemes or publish media. Independent Teatro/Ear judges output.
"""
from __future__ import annotations
from array import array
from bisect import bisect_left
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import wave


class CandidateError(ValueError):
    pass


def private(path, must_exist=True):
    p = Path(path).expanduser().resolve()
    if not p.is_relative_to(Path("/tmp").resolve()):
        raise CandidateError("Private research files must remain under /tmp")
    if must_exist and not p.is_file():
        raise CandidateError("Private research file not found")
    if not must_exist and not p.parent.is_dir():
        raise CandidateError("Output directory does not exist")
    return p


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read_wav(filename):
    path = private(filename)
    raw = path.read_bytes()
    if len(raw) > 30_000_000:
        raise CandidateError("Input WAV exceeds size bound")
    with wave.open(str(path), "rb") as r:
        if r.getnchannels() != 1 or r.getsampwidth() != 2 or r.getcomptype() != "NONE":
            raise CandidateError("Only uncompressed mono PCM16 source is accepted")
        rate = r.getframerate()
        if not 16000 <= rate <= 96000:
            raise CandidateError("Unexpected source sample rate")
        values = array("h")
        values.frombytes(r.readframes(r.getnframes()))
        if sys.byteorder != "little":
            values.byteswap()
    return [float(x) / 32768 for x in values], rate, sha(raw)


def write_wav(path, audio, rate):
    data = array("h", (max(-32768, min(32767, round(x * 32767))) for x in audio))
    if sys.byteorder != "little":
        data.byteswap()
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(data.tobytes())
    return sha(path.read_bytes())


def f0(source, rate, min_hz=85, max_hz=500):
    length = min(len(source), round(.09 * rate))
    if length < round(.055 * rate):
        raise CandidateError("Vowel too short for periodicity estimate")
    start = (len(source) - length) // 2
    raw = source[start:start + length]
    avg = sum(raw) / length
    x = [(v-avg) * (.5 - .5 * math.cos(2*math.pi*i/(length-1)))
         for i,v in enumerate(raw)]
    if sum(v*v for v in x)/length < 1e-7:
        raise CandidateError("No audible source vowel center")
    lower = max(2, int(rate/max_hz))
    upper = min(int(rate/min_hz),length//2)
    best_lag, best = 0, -1.0
    for lag in range(lower, upper + 1):
        ab=aa=bb=0.0
        for i in range(length-lag):
            a,b=x[i],x[i+lag]
            ab+=a*b
            aa+=a*a
            bb+=b*b
        value = ab / math.sqrt(aa*bb) if aa > 0 and bb > 0 else 0
        if value > best:
            best_lag, best = lag, value
    if best_lag < 1 or best < .40:
        raise CandidateError("Source vowel periodicity unqualified")
    return rate / best_lag, best


def pitch_marks(vowel, period):
    if len(vowel) < round(4*period):
        raise CandidateError("Voiced source nucleus too short")
    middle = len(vowel)//2
    radius = max(2,round(period*.47))
    origin = max(range(max(0,middle-radius),
                       min(len(vowel),middle+radius+1)),
                 key=lambda i:abs(vowel[i]))
    marks=[origin]
    for direction in (-1,1):
        p=origin
        for unused in range(5000):
            expected=p+direction*period
            lo=max(0,round(expected-.16*period))
            hi=min(len(vowel)-1,round(expected+.16*period))
            if expected<0 or expected>=len(vowel) or lo>hi:
                break
            nxt=max(range(lo,hi+1), key=lambda i:abs(vowel[i]))
            if nxt==p:break
            marks.append(nxt)
            p=nxt
    return sorted(set(marks))


def nearest(sorted_marks, position):
    j=bisect_left(sorted_marks,position)
    if j==0:return sorted_marks[0]
    if j==len(sorted_marks):return sorted_marks[-1]
    return min((sorted_marks[j-1],sorted_marks[j]),key=lambda v:abs(v-position))


def midi_hz(midi_pitch):
    if not isinstance(midi_pitch,int) or not 0 <= midi_pitch <= 127:
        raise CandidateError("Invalid MIDI 2.0 performance pitch")
    return 440.0 * 2 ** ((midi_pitch - 69)/12)


def retime_vowel(vowel, rate, target_frames, note_positions):
    # Spoken pitch routinely falls sharply across a vowel. The original
    # prototype estimated F0 at the *middle* (Kathy: already substantially
    # lower), even though this pitch was not representative of the grains
    # used to begin the melody. Limit the pitch anchor and its pulse marks
    # to the SAME early stable nucleus: never select by the target note.
    first=round(rate*.09)
    last=min(len(vowel),round(rate*.14))
    if last<first:raise CandidateError("Source vowel lacks a stable early nucleus")
    original_hz, corr = f0(vowel[:first],rate)
    anchor=vowel[:last]
    period=rate/original_hz
    marks=pitch_marks(anchor,period)
    inner=[m for m in marks if m>=period and m+period<len(anchor)]
    if len(inner)<3:
        raise CandidateError("No stable complete pitch grains")
    if not note_positions or note_positions[0][0]!=0:
        raise CandidateError("Target MIDI2 note plan missing at vowel entry")
    for _,target_hz in note_positions:
        if not (80 <= target_hz <= 750 and .67 <= target_hz/original_hz <= 1.9):
            raise CandidateError("Pitch shift outside bounded voice-preservation ratio")
    n=max(4,round(period*2))
    accumulated=[0.0]*target_frames
    weights=[0.0]*target_frames
    pos=rate/(2*note_positions[0][1])
    cursor=0
    while pos<target_frames:
        while cursor+1<len(note_positions) and pos>=note_positions[cursor+1][0]:
            cursor+=1
        goal=note_positions[cursor][1]
        src_pos=inner[0]+(pos/max(1,target_frames))*(inner[-1]-inner[0])
        mark=nearest(inner,src_pos)
        dest=round(pos)
        for j in range(n):
            si=mark+j-n//2
            di=dest+j-n//2
            if 0<=si<len(anchor) and 0<=di<target_frames:
                w=.5-.5*math.cos(2*math.pi*j/(n-1))
                accumulated[di]+=anchor[si]*w
                weights[di]+=w
        pos+=rate/goal
    out=[x/w if w>1e-7 else 0.0 for x,w in zip(accumulated,weights)]
    uncovered=sum(w<=1e-7 for w in weights)/max(1,target_frames)
    if uncovered>.10:
        raise CandidateError("No reliable overlap-add coverage")
    return out,{"originalHz":round(original_hz,2),
                "sourcePeriodicity":round(corr,4),
                "sourcePitchMarks":len(inner),
                "uncoveredFraction":round(uncovered,5)}


def crossfade(a,b,overlap):
    if overlap<1 or overlap>=len(a) or overlap>=len(b):
        raise CandidateError("Crossfade shorter than source attack/release")
    join=[(1-(i+.5)/overlap)*a[-overlap+i]+((i+.5)/overlap)*b[i]
          for i in range(overlap)]
    return a[:-overlap]+join+b[overlap:]


def source_regions(source_manifest,rate,total_frames,release_style="natural-vowel"):
    items=source_manifest["regions"]
    regions=[]
    for idx,r in enumerate(items):
        s,a,b = (r[k] for k in ("onsetStartFrame","vowelStartFrame","vowelEndFrame"))
        next_onset=items[idx+1]["onsetStartFrame"] if idx+1<len(items) else total_frames
        if release_style=="source-gap":
            # Historical source-only prototype: often a digital silence
            # after a syllable. Retain as a negative comparison fixture.
            available=max(0,next_onset-b)
            tail=min(round(rate*.08),max(0,available-round(rate*.015)))
            release_start,e=b,min(total_frames,b+tail)
        elif release_style=="natural-vowel":
            # Preserve final 70ms of the ACTUALLY VOICED source as natural
            # release. This is a provisional EDIT, not a recognized phone.
            release_start,e=b-round(rate*.07),b
            if release_start-a<round(rate*.14):
                raise CandidateError("Insufficient stable vowel before natural release")
        else:
            raise CandidateError("Unknown private release style")
        if not (0<=s<a<release_start<e<=next_onset<=total_frames):
            raise CandidateError("Invalid source region or missing release")
        if a-s<round(rate*.04) or e-release_start<round(rate*.04):
            raise CandidateError("Must preserve at least 40ms source attack/release")
        regions.append((r["syllableId"],s,a,release_start,e))
    return regions


def render(source,rate,source_sha,source_manifest,score,release_style="natural-vowel",
           vowel_renderer=None):
    if score.get("schema")!="sing.phrase.v1":
        raise CandidateError("Required existing Sing score schema")
    if (source_manifest.get("schema")!="sing.speech-source.v1"
        or source_manifest.get("sourceWavSHA256")!=source_sha
        or source_manifest.get("sampleRate")!=rate
        or source_manifest.get("release")!="not-admitted"
        or source_manifest.get("alignmentStatus") not in ("provisional","independently-verified")
        or source_manifest.get("sourceText")!=score.get("source",{}).get("text")):
        raise CandidateError("Speech source authority, alignment or score mismatch")
    syllables=score["phrase"]["syllables"]
    regions=source_regions(source_manifest,rate,len(source),release_style)
    if [r[0] for r in regions] != [s["id"] for s in syllables]:
        raise CandidateError("Source syllable IDs disagree with typed MIDI2 score")
    if (score["phrase"].get("id")!="sustained-melisma-01"
        or score["performance"].get("timebase")!="milliseconds"
        or [x["id"]for x in score["performance"]["notes"]]!=
           ["long-la-1","long-la-2","long-mi","long-na"]):
        raise CandidateError("This research renderer only accepts the existing four-note Sing MIDI2 rehearsal scenario")
    notes=score["performance"]["notes"]
    if not notes or len(notes)>32 or len(regions)>16:
        raise CandidateError("Unbounded MIDI2 performance")
    expected_ids={r[0]for r in regions}
    if any(n["syllableId"] not in expected_ids for n in notes):
        raise CandidateError("Unknown MIDI2 note syllable")
    previous=0
    for n in notes:
        if (not isinstance(n["onMs"],int) or not isinstance(n["offMs"],int)
            or n["onMs"]<previous or n["offMs"]<=n["onMs"]
            or n["onMs"]>20000 or n["offMs"]>20000):
            raise CandidateError("Invalid or overlapping MIDI2 note timing")
        midi_hz(n["pitch"])
        previous=n["offMs"]
    # Same 5.2s phrase duration as existing Swift rehearsal.
    total=round((notes[-1]["offMs"]+400)*rate/1000)
    if total>rate*30:
        raise CandidateError("Output longer than private research bound")
    result=[0.0]*total
    evidence=[]
    for syllable,s,a,b,e in regions:
        group=[n for n in notes if n["syllableId"]==syllable]
        if not group or not group[0].get("advanceSyllable",False):
            raise CandidateError("MIDI2 onset is not independently present")
        if any(n.get("advanceSyllable",True)for n in group[1:]):
            raise CandidateError("Melisma must not repeat consonant attack")
        target_start=round(group[0]["onMs"]*rate/1000)
        target_end=round(group[-1]["offMs"]*rate/1000)
        length=target_end-target_start
        attack=source[s:a]
        coda=source[b:e]
        overlap=round(rate*.012)
        vowel_frames=length-len(attack)-len(coda)+2*overlap
        if vowel_frames<round(rate*.08):
            raise CandidateError("Insufficient target vowel duration")
        # All note changes occur in the sustain interval, following the
        # ORIGINAL score: no duplicated score or new event transport.
        note_plan=[]
        begin_vowel_ms=group[0]["onMs"]+(len(attack)-overlap)*1000/rate
        for i,n in enumerate(group):
            boundary=max(0,round((n["onMs"]-begin_vowel_ms)*rate/1000))
            if i==0:boundary=0
            note_plan.append((min(vowel_frames,boundary),midi_hz(n["pitch"])))
        if any(b2<b1 for (b1,_),(b2,_) in zip(note_plan,note_plan[1:])):
            raise CandidateError("Nonmonotonic vowel note pitch plan")
        # The native source/score/attack/release authority stays unchanged.
        # A research vocoder may replace ONLY the sustained-vowel renderer;
        # the original default remains byte-for-byte reproducible.
        renderer = vowel_renderer if vowel_renderer is not None else retime_vowel
        vowel,stats=renderer(source[a:b],rate,vowel_frames,note_plan)
        block=crossfade(crossfade(attack,vowel,overlap),coda,overlap)
        if len(block)!=length:
            raise CandidateError("Syllable frame count mismatch")
        if block[:len(attack)-overlap]!=attack[:-overlap]:
            raise CandidateError("Original attack PCM not preserved")
        if block[-(len(coda)-overlap):]!=coda[overlap:]:
            raise CandidateError("Original release PCM not preserved")
        # Natural source release is lightly faded for the scored silence.
        # Historical source-gap already ends digitally silent; keep bit
        # exact to the prior prototype so Ear comparisons remain repeatable.
        fade=(min(round(rate*.01),len(coda)-overlap-1)
              if release_style=="natural-vowel" else 0)
        for i in range(fade):
            p=len(block)-fade+i
            block[p]*=(fade-i-1)/max(1,fade)
        result[target_start:target_end]=block
        stats.update({
            "syllableId":syllable,
            "sourceStartFrame":s,"vowelStartFrame":a,
            "sourceReleaseStartFrame":b,"sourceReleaseEndFrame":e,
            "outputStartFrame":target_start,"outputEndFrame":target_end,
            "attackSamplesPreserved":len(attack)-overlap,
            "codaSamplesPreserved":len(coda)-overlap-fade,
            "naturalReleaseSamples":len(coda),
            "releaseFadeSamples":fade,
            "sourceVowelSamplesUsed":b-a,
            "notes":[{"id":n["id"],"pitch":n["pitch"],
                      "targetHz":round(midi_hz(n["pitch"]),2)}for n in group],
        })
        evidence.append(stats)
    peak=max(abs(x)for x in result)
    if not math.isfinite(peak) or peak<=.001:
        raise CandidateError("Silent or invalid output")
    if peak>.95:
        # A safety attenuation is disclosed and leaves individual onset
        # structure intact; do not infer exact PCM bit equality thereafter.
        result=[x*(.95/peak) for x in result]
    return result,{
        "schema":"sing.private-vowel-anchor-render.v2",
        "engine":"sing.private.vowel-anchor.research.not-accepted",
        "sourceSHA256":source_sha,"sourceAlignmentStatus":source_manifest["alignmentStatus"],
        "sourceKind":source_manifest["sourceKind"],
        "sampleRate":rate,"frames":len(result),"durationSeconds":round(len(result)/rate,5),
        "sourcePeak":round(peak,5),"releaseStyle":release_style,
        "syllables":evidence,
        "scorePlane":"same source phrase as compiled by native Sing MIDI2; this offline Python reference consumes original score JSON, not UMP packets",
        "newMIDITransport":False,"coreMIDI":False,
        "originalSwiftBaselineReplaced":False,
        "sourcePhonemeRecognitionPerformed":False,
        "sungWordsRecognized":False,"vocalIntelligibilityQualified":False,
        "humanIntelligibility":"NOT_MEASURED","mediaPublished":False,
    }


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--source",required=True)
    parser.add_argument("--source-manifest",required=True)
    parser.add_argument("--score",required=True)
    parser.add_argument("--output",required=True)
    parser.add_argument("--receipt",required=True)
    parser.add_argument("--release-style",
                        choices=("natural-vowel","source-gap"),
                        default="natural-vowel")
    args=parser.parse_args()
    src=private(args.source)
    manifest_path=private(args.source_manifest)
    score=Path(args.score).expanduser().resolve()
    if not score.is_file():
        parser.error("Existing Sing score file not found")
    dest=private(args.output,False)
    receipt=private(args.receipt,False)
    if len({src,manifest_path,dest,receipt,score})!=5:
        parser.error("Cannot overwrite source, score or manifest")
    audio,rate,digest=read_wav(src)
    signal,metrics=render(audio,rate,digest,json.loads(manifest_path.read_text()),
                          json.loads(score.read_text()),
                          release_style=args.release_style)
    metrics["outputSHA256"]=write_wav(dest,signal,rate)
    receipt.write_text(json.dumps(metrics,indent=2,sort_keys=True)+"\n")
    print(json.dumps({"sourceSHA256":digest,"outputSHA256":metrics["outputSHA256"],
                      "candidate":str(dest),"receipt":str(receipt),
                      "sourceNotes":sum(len(s["notes"])for s in metrics["syllables"]),
                      "durationSeconds":metrics["durationSeconds"],
                      "published":False,"qualified":False},indent=2))


if __name__=="__main__":
    main()
