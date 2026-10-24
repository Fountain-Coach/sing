#!/usr/bin/env python3
"""Source-only unit tests for experimental voice-preserving MIDI2 score render.

Synthetic signals are NOT human speech, Ear judgments or candidate approval.
"""
import hashlib
import json
import math
import os
from pathlib import Path
import struct
import sys
import tempfile
import unittest
import wave

sys.path.insert(0,str(Path(__file__).resolve().parent))
from vowel_anchor import (
    CandidateError, f0, midi_hz, private, read_wav, render, retime_vowel, sha,
    source_regions, write_wav
)

SCORE = Path(__file__).resolve().parents[3] / "examples/sustained-melisma.json"


def simple_fixture():
    rate=48000
    sound=[]
    regions=[]
    for idx,hz in enumerate((240,244,238),start=1):
        onset=len(sound)
        for k in range(round(rate*.09)):
            t=k/rate
            sound.append(.13*math.sin(2*math.pi*hz*t))
        vowel_start=len(sound)
        for k in range(round(rate*.23)):
            t=k/rate
            sound.append(.24*math.sin(2*math.pi*hz*t)+
                         .09*math.sin(2*math.pi*hz*2*t))
        vowel_end=len(sound)
        sound.extend([0.0]*round(rate*.15))
        regions.append({
            "syllableId":"s"+str(idx), "onsetStartFrame":onset,
            "vowelStartFrame":vowel_start, "vowelEndFrame":vowel_end
        })
    digest="a"*64
    manifest={
        "schema":"sing.speech-source.v1",
        "sourceKind":"original-synthetic-test-only",
        "sourceText":"la mi na",
        "sampleRate":rate,
        "sourceWavSHA256":digest,
        "release":"not-admitted",
        "alignmentStatus":"provisional",
        "regions":regions,
    }
    score=json.loads(SCORE.read_text())
    return sound,rate,digest,manifest,score


class VocalAnchorTests(unittest.TestCase):
    def test_existing_four_notes_on_single_score(self):
        _,rate,sha_id,manifest,score=simple_fixture()
        self.assertEqual([n["pitch"]for n in score["performance"]["notes"]],
                         [60,64,67,64])
        self.assertEqual(score["performance"]["notes"][1]["advanceSyllable"],False)
        self.assertEqual(round(midi_hz(67),2),392.0)

    def test_source_renders_preserved_attack_and_coda_without_second_midi_plane(self):
        audio,rate,sha_id,manifest,score=simple_fixture()
        result,receipt=render(audio,rate,sha_id,manifest,score)
        self.assertEqual(len(result),249600)
        self.assertEqual(len(receipt["syllables"]),3)
        self.assertEqual([len(x["notes"])for x in receipt["syllables"]],[2,1,1])
        self.assertFalse(receipt["newMIDITransport"])
        self.assertFalse(receipt["originalSwiftBaselineReplaced"])
        self.assertFalse(receipt["sungWordsRecognized"])
        self.assertFalse(receipt["mediaPublished"])
        for r in receipt["syllables"]:
            originalAttack=audio[r["sourceStartFrame"]:r["vowelStartFrame"]]
            noFade=r["attackSamplesPreserved"]
            self.assertEqual(result[r["outputStartFrame"]:r["outputStartFrame"]+noFade],
                             originalAttack[:noFade])
            originalTail=audio[r["sourceReleaseStartFrame"]:r["sourceReleaseEndFrame"]]
            releaseLength=r["codaSamplesPreserved"]
            releaseFade=r["releaseFadeSamples"]
            codaStart=r["outputEndFrame"]-releaseFade-releaseLength
            self.assertEqual(result[codaStart:r["outputEndFrame"]-releaseFade],
                             originalTail[round(rate*.012):-releaseFade])

    def test_source_gap_historical_variant_is_explicit_not_a_vocal_release(self):
        audio,rate,sha_id,manifest,score=simple_fixture()
        natural,nr=render(audio,rate,sha_id,manifest,score,release_style="natural-vowel")
        earlier,er=render(audio,rate,sha_id,manifest,score,release_style="source-gap")
        self.assertEqual(nr["releaseStyle"],"natural-vowel")
        self.assertEqual(er["releaseStyle"],"source-gap")
        self.assertNotEqual(natural,earlier)
        self.assertEqual(len(natural),len(earlier))
        self.assertEqual(sum(r["releaseFadeSamples"] for r in er["syllables"]),0)
        with self.assertRaisesRegex(CandidateError,"release style"):
            render(audio,rate,sha_id,manifest,score,release_style="fake")

    def test_source_gap_reproduces_original_private_kathy_sha_if_present(self):
        spoken=Path("/tmp/sing-vocal-Kathy.wav")
        manifest=Path("/tmp/sing-vocal-Kathy.json")
        if not spoken.exists() or not manifest.exists():
            self.skipTest("Authorized local high-pitch speech source absent")
        audio,rate,digest=read_wav(str(spoken))
        candidate,receipt=render(audio,rate,digest,json.loads(manifest.read_text()),
                                 json.loads(SCORE.read_text()),release_style="source-gap")
        with tempfile.TemporaryDirectory(prefix="sing-anchor-bitmatch-",dir="/tmp") as tmp:
            output=Path(tmp)/"replay.wav"
            output_sha=write_wav(output,candidate,rate)
            self.assertEqual(output_sha,
                "56229b206cd0b3c6ba8794c24cb1e314df1534176dcc6c9e4246cca385c986ae")

    def test_source_render_deterministic(self):
        audio,rate,sha_id,manifest,score=simple_fixture()
        a,ar=render(audio,rate,sha_id,manifest,score)
        b,br=render(audio,rate,sha_id,manifest,score)
        self.assertEqual(a,b)
        self.assertEqual(ar,br)

    def test_early_stable_pitch_anchor_uses_real_voiced_period(self):
        rate=48000
        x=[.22*math.sin(2*math.pi*244*k/rate) for k in range(round(rate*.16))]
        output,receipt=retime_vowel(x,rate,round(rate*.65),[(0,392.0)])
        self.assertAlmostEqual(receipt["originalHz"],244,delta=3)
        self.assertGreater(receipt["sourcePeriodicity"],.75)
        self.assertGreater(receipt["sourcePitchMarks"],8)
        self.assertEqual(len(output),round(rate*.65))

    def test_source_sha_cannot_be_changed_by_score(self):
        audio,rate,sha_id,manifest,score=simple_fixture()
        manifest["sourceWavSHA256"]="0"*64
        with self.assertRaisesRegex(CandidateError,"authority"):
            render(audio,rate,sha_id,manifest,score)

    def test_source_boundary_outside_private_root_rejected(self):
        with self.assertRaisesRegex(CandidateError,"under /tmp"):
            private("/Users/unknown/voice.wav",False)

    def test_legacy_low_f0_source_is_not_forced_through_extreme_shift(self):
        sr=48000
        vowel=[.2*math.sin(2*math.pi*110*i/sr)for i in range(round(.2*sr))]
        with self.assertRaisesRegex(CandidateError,"ratio"):
            retime_vowel(vowel,sr,round(sr*.5),[(0,392)])

    def test_noise_cannot_be_forced_into_a_singing_vowel(self):
        sr=48000
        import random
        rng=random.Random(4)
        vowel=[rng.uniform(-.07,.07)for _ in range(round(sr*.22))]
        with self.assertRaisesRegex(CandidateError,"periodicity"):
            retime_vowel(vowel,sr,round(sr*.6),[(0,330)])

    def test_score_inverted_melisma_onset_rejected(self):
        audio,rate,sha_id,manifest,score=simple_fixture()
        score["performance"]["notes"][1]["advanceSyllable"]=True
        with self.assertRaisesRegex(CandidateError,"repeat consonant"):
            render(audio,rate,sha_id,manifest,score)

    def test_overlapping_source_boundaries_rejected(self):
        audio,rate,sha_id,manifest,score=simple_fixture()
        manifest["regions"][1]["onsetStartFrame"]=manifest["regions"][0]["vowelStartFrame"]
        with self.assertRaisesRegex(CandidateError,"source region"):
            render(audio,rate,sha_id,manifest,score)

    def test_private_wav_input_sha_and_file_roundtrip(self):
        rate=48000
        with tempfile.TemporaryDirectory(dir="/tmp",prefix="sing-anchor-test-") as root:
            dest=Path(root)/"signal.wav"
            sound=[.11*math.sin(2*math.pi*230*i/rate)for i in range(rate//3)]
            identifier=write_wav(dest,sound,rate)
            again,sr,real=read_wav(str(dest))
            self.assertEqual(sr,rate)
            self.assertEqual(real,identifier)
            self.assertEqual(sha(dest.read_bytes()),identifier)
            self.assertEqual(len(again),len(sound))

    def test_real_mac_source_preserved_and_unchanged_after_denial(self):
        source=Path("/tmp/sing-speech-macos.wav")
        manifest=Path("/tmp/sing-speech-macos.json")
        if not source.exists() or not manifest.exists():
            self.skipTest("Original immutable private macOS speech control absent")
        audio,rate,digest=read_wav(str(source))
        source_config=json.loads(manifest.read_text())
        score=json.loads(SCORE.read_text())
        with self.assertRaisesRegex(CandidateError,"ratio"):
            render(audio,rate,digest,source_config,score)
        self.assertEqual(sha(source.read_bytes()),digest)


if __name__ == "__main__":
    unittest.main()
