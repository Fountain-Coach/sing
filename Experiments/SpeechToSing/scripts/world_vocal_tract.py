#!/usr/bin/env python3
"""Private, bounded time-VARYING spectral-envelope research renderer for Sing.

WORLD is a source-filter *acoustic approximation*, not an anatomical vocal
tract, phoneme recognizer, trained voice, or publisher. Native Sing compiles
the original MIDI2 score. This file receives the SAME source score JSON only
for offline rehearsal and does not implement a second MIDI or sound transport.

A single source-selected vowel spectrum is the frozen WORLD control.
An interpolated, time-evolving SOURCE vowel spectrum plus source aperiodicity
is the candidate. Input SHA, attack, natural release, timing, and target
MIDI pitches are identical. Evaluate both with independent Ear; NEVER choose
winners from self-measured pitch/spectrum proxies.
"""
from __future__ import annotations

from functools import partial
import argparse
import hashlib
import importlib.metadata
import json
import math
from pathlib import Path

import numpy as np
import pyworld as pw

from vowel_anchor import (
    CandidateError, f0, private, read_wav, render, write_wav,
)

REQUIRED = {
    "numpy": "2.3.4",
    "pyworld-prebuilt": "0.3.6.post1",
}
FRAME_PERIOD_MS = 5.0
WORLD_ANALYSIS_F0_MIN = 85.0
WORLD_ANALYSIS_F0_MAX = 500.0
MIN_PITCH_RATIO = 0.67
MAX_PITCH_RATIO = 1.90


def verify_installed_engine():
    for distribution, version in REQUIRED.items():
        actual = importlib.metadata.version(distribution)
        if actual != version:
            raise CandidateError(
                f"Private WORLD environment drift: {distribution} {actual} != {version}"
            )
    if not all(hasattr(pw, item) for item in (
        "dio", "stonemask", "cheaptrick", "d4c", "synthesize"
    )):
        raise CandidateError("Missing pinned WORLD acoustic analysis or synthesis API")


def safe_rms(x):
    return math.sqrt(float(np.mean(np.square(x))))


def analyze_source(vowel, sample_rate):
    """Source-only WORLD decomposition; neither score nor candidate in analysis."""
    verify_installed_engine()
    if sample_rate != 48000 or not .19 <= len(vowel)/sample_rate <= 8:
        raise CandidateError("WORLD analysis expects bounded 48kHz voice nucleus")
    source = np.asarray(vowel, dtype=np.float64)
    if not np.all(np.isfinite(source)) or safe_rms(source) < .008:
        raise CandidateError("Source vowel is silent or contains invalid samples")
    early_hz, periodicity = f0(vowel[:int(sample_rate*.09)], sample_rate)
    f0_track, time_axis = pw.dio(
        source, sample_rate, f0_floor=WORLD_ANALYSIS_F0_MIN,
        f0_ceil=WORLD_ANALYSIS_F0_MAX, frame_period=FRAME_PERIOD_MS
    )
    f0_track = pw.stonemask(source, f0_track, time_axis, sample_rate)
    spectral = pw.cheaptrick(source, f0_track, time_axis, sample_rate)
    aperiodic = pw.d4c(source, f0_track, time_axis, sample_rate)
    if spectral.shape != aperiodic.shape or len(f0_track) != len(spectral):
        raise CandidateError("WORLD source dimensions are inconsistent")
    if (not np.isfinite(spectral).all() or not np.isfinite(aperiodic).all()
        or len(f0_track) < 15 or (f0_track > 0).sum() < .65*len(f0_track)):
        raise CandidateError("No reliable continuously voiced source")
    if not (np.isfinite(early_hz) and .40 <= periodicity <= 1.0):
        raise CandidateError("Unstable early voice anchor")
    voiced_indices = np.flatnonzero(f0_track > 0)
    lo = max(int(voiced_indices[0])+1, round(.06*len(f0_track)))
    hi = min(int(voiced_indices[-1])-1, round(.80*len(f0_track)))
    if hi - lo < 8:
        raise CandidateError("Source vowel evolution too short")
    return {
        "source": source, "sourceHz": early_hz,
        "sourcePeriodicity": periodicity,
        "trackedF0": f0_track, "spectral": spectral,
        "aperiodic": aperiodic, "startIndex": lo, "endIndex": hi
    }


def make_trajectories(vowel, rate, target_frames, note_positions, mode="evolving"):
    """Create source-blind WORLD spectra, independently scored target F0 frames."""
    if mode not in ("frozen", "evolving"):
        raise CandidateError("Unknown WORLD trajectory mode")
    if not note_positions or note_positions[0][0] != 0:
        raise CandidateError("Missing target score note at vowel start")
    if target_frames > rate * 12 or target_frames < rate*.08:
        raise CandidateError("Unbounded WORLD note duration")
    analysis = analyze_source(vowel, rate)
    source_hz = analysis["sourceHz"]
    for offset, target_hz in note_positions:
        if (not isinstance(offset, int) or offset < 0 or offset > target_frames
            or not math.isfinite(target_hz) or not 80 <= target_hz <= 750
            or not MIN_PITCH_RATIO <= target_hz/source_hz <= MAX_PITCH_RATIO):
            raise CandidateError("World pitch shift outside voice preservation bound")
    if any(a[0] >= b[0] for a,b in zip(note_positions,note_positions[1:])):
        raise CandidateError("Score note boundaries must increase strictly")
    stride = rate * FRAME_PERIOD_MS / 1000
    nframes = int(math.ceil(target_frames / stride)) + 1
    time_out = np.arange(nframes, dtype=np.float64) * stride
    note_starts = [n[0] for n in note_positions]
    frequencies = [n[1] for n in note_positions]
    f0_out = np.array(
        [frequencies[max(0, int(np.searchsorted(note_starts, sample, side="right")-1))]
         for sample in time_out], dtype=np.float64
    )
    lo, hi = analysis["startIndex"], analysis["endIndex"]
    if mode == "evolving":
        # Traverse original time-varying source tract envelopes only ONCE
        # over the much longer note. It is source-informed, NOT target-informed.
        position = np.linspace(float(lo), float(hi), nframes)
    else:
        # Freeze at one SOURCE-defined voiced time, not one target-determined
        # value, for a controlled test of time variation itself.
        position = np.full(nframes, (lo + hi)/2, dtype=np.float64)
    low = np.floor(position).astype(int)
    high = np.ceil(position).astype(int)
    frac = (position - low)[:, None]
    source_sp = analysis["spectral"]
    source_ap = analysis["aperiodic"]
    # Log-spectral interpolation maintains positivity and smoothness of
    # power-envelope trajectories across source frames.
    small = 1e-12
    spectral = np.exp(
        (1-frac)*np.log(np.maximum(source_sp[low], small))
        + frac*np.log(np.maximum(source_sp[high], small))
    )
    aperiodic = np.clip(
        (1-frac)*source_ap[low] + frac*source_ap[high],
        0.001, 0.999999
    )
    variation = float(np.sqrt(np.mean(
        np.square(
            np.log(np.maximum(spectral[-1],small))
            - np.log(np.maximum(spectral[0],small))
        )
    )))
    if not (np.isfinite(spectral).all() and np.isfinite(aperiodic).all()
            and (spectral >= 0).all()):
        raise CandidateError("Invalid time-varying WORLD spectrum")
    return f0_out, spectral, aperiodic, {
        "sourceHz": round(source_hz, 3),
        "sourcePeriodicity": round(analysis["sourcePeriodicity"],5),
        "sourceWorldFrames": len(analysis["trackedF0"]),
        "sourceVoicedFrames": int(np.count_nonzero(analysis["trackedF0"])),
        "sourceSpectralStartFrame": lo,
        "sourceSpectralEndFrame": hi,
        "outputWorldFrames": nframes,
        "targetPitchSequenceHz": [round(x,3) for x in frequencies],
        "sourceSpectralLogEndToStartDistance": round(variation,6),
        "spectralTrajectory": mode,
        "sourceSpectralFramesEvolve": mode == "evolving",
    }


def retime_vowel_world(vowel, rate, target_frames, note_positions,
                       mode="evolving"):
    f0_out, sp_out, ap_out, receipt = make_trajectories(
        vowel,rate,target_frames,note_positions,mode
    )
    audio = pw.synthesize(
        f0_out,sp_out,ap_out,rate,frame_period=FRAME_PERIOD_MS
    )
    if len(audio) < target_frames:
        audio = np.pad(audio,(0,target_frames-len(audio)),mode="constant")
    audio = audio[:target_frames]
    if not np.isfinite(audio).all():
        raise CandidateError("Invalid synthesized WORLD PCM")
    src = np.asarray(vowel,dtype=np.float64)
    pre_rms = safe_rms(audio)
    if pre_rms < .00001:
        raise CandidateError("WORLD output is silent")
    # One source-only, bounded calibration, independent of Ear's decision.
    # It is not a volume trick to make a recognizer pass.
    source_rms = safe_rms(src)
    gain = min(4.0,max(.25,source_rms/pre_rms))
    audio *= gain
    peak = float(np.max(np.abs(audio)))
    if peak > .84:
        audio *= .84/peak
    receipt.update({
        "sourceRms": round(source_rms,6),
        "worldRawRms": round(pre_rms,6),
        "gainBeforePeakSafety": round(gain,6),
        "worldFinalRms": round(safe_rms(audio),6),
        "worldFinalPeak": round(float(np.max(np.abs(audio))),6),
        "phonemesRecognized":False,
        "voicePreservedOrPerceptuallyQualified":False
    })
    return audio.tolist(),receipt


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--source",required=True)
    parser.add_argument("--source-manifest",required=True)
    parser.add_argument("--score",required=True)
    parser.add_argument("--trajectory",choices=("frozen","evolving"),required=True)
    parser.add_argument("--output",required=True)
    parser.add_argument("--receipt",required=True)
    args=parser.parse_args()
    source_file=private(args.source)
    manifest_file=private(args.source_manifest)
    out=private(args.output,False)
    receipt_path=private(args.receipt,False)
    score_path=Path(args.score).expanduser().resolve()
    if not score_path.is_file():
        raise CandidateError("Missing original Sing score")
    if len(set((source_file,manifest_file,out,receipt_path,score_path)))!=5:
        raise CandidateError("Research render must not overwrite existing source")
    verify_installed_engine()
    source,rate,digest=read_wav(str(source_file))
    manifest=json.loads(manifest_file.read_text())
    score=json.loads(score_path.read_text())
    fn=partial(retime_vowel_world,mode=args.trajectory)
    samples,stats=render(source,rate,digest,manifest,score,
                         release_style="natural-vowel",vowel_renderer=fn)
    stats.update({
        "schema":"sing.private-world-voice-spectrum.v1",
        "engine":"sing.private.world-vocoder-source-filter.research-not-qualified",
        "trajectory":args.trajectory,
        "sourceSpeechSHA256":digest,
        "sourceManifestSHA256":hashlib.sha256(manifest_file.read_bytes()).hexdigest(),
        "scoreSHA256":hashlib.sha256(score_path.read_bytes()).hexdigest(),
        "model":"WORLD DIO + StoneMask + CheapTrick + D4C + synthesis",
        "dependencyVersions":REQUIRED,
        "sourceTractSpectraAreAnAcousticProxyNotAnatomicalMeasurement":True,
        "phoneRecognition":"NOT_QUALIFIED",
        "perceptualNaturalness":"NOT_TESTED",
        "publisherAuthorization":False,"mediaPublished":False,
    })
    stats["outputSHA256"]=write_wav(out,samples,rate)
    receipt_path.write_text(json.dumps(stats,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "sourceSHA256":digest, "candidateSHA256":stats["outputSHA256"],
        "mode":args.trajectory,"out":str(out),"receipt":str(receipt_path),
        "noteCount":sum(len(x["notes"]) for x in stats["syllables"]),
        "seconds":stats["durationSeconds"],"qualified":False,
        "mediaPublished":False
    },indent=2))


if __name__ == "__main__":
    main()
