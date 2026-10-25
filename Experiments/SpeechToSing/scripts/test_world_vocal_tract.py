#!/usr/bin/env python3
"""Offline WORLD source-filter research tests; no lyrics, voices or media release.

Tests distinguish production source safety, voiced-only decomposition,
frozen vs evolving spectral trajectories, pitch targets, deterministic PCM,
the native Sing default, and explicit acoustic NON-qualification.
"""
import copy
import hashlib
import json
import math
from pathlib import Path
import sys
import tempfile
import unittest

import numpy as np

sys.path.insert(0,str(Path(__file__).resolve().parent))
from vowel_anchor import CandidateError, read_wav, render, write_wav
from world_vocal_tract import (
    REQUIRED, FRAME_PERIOD_MS, analyze_source, make_trajectories,
    retime_vowel_world, verify_installed_engine
)
from test_vowel_anchor import simple_fixture, SCORE


class WorldSpectralTests(unittest.TestCase):

    def setUp(self):
        verify_installed_engine()
        self.audio,self.sr,self.digest,self.manifest,self.score=simple_fixture()

    def private_kathy(self):
        speech=Path("/tmp/sing-vocal-Kathy.wav")
        manifest=Path("/tmp/sing-vocal-Kathy.json")
        if not speech.exists() or not manifest.exists():
            self.skipTest("Private Kathy source unavailable")
        audio,rate,digest=read_wav(str(speech))
        m=json.loads(manifest.read_text())
        self.assertEqual(m["sourceWavSHA256"],digest)
        return audio,rate,digest,m

    def test_dependency_and_frame_period_pinned(self):
        self.assertEqual(REQUIRED,{"numpy":"2.3.4",
                                   "pyworld-prebuilt":"0.3.6.post1"})
        self.assertEqual(FRAME_PERIOD_MS,5.0)

    def test_world_source_analysis_is_audio_only(self):
        import inspect
        params=inspect.signature(analyze_source).parameters
        self.assertEqual(list(params),["vowel","sample_rate"])
        for name in ("lyrics","phonemes","score","midi","speaker"):
            self.assertNotIn(name,params)

    def test_frozen_and_evolving_same_target_f0_different_spectra(self):
        audio,rate,digest,m=self.private_kathy()
        region=m["regions"][0]
        vowel=audio[region["vowelStartFrame"]:region["vowelEndFrame"]-round(rate*.07)]
        plan=[(0,261.6256),(round(.99*rate),329.6276)]
        f0a,spa,apa,ra=make_trajectories(vowel,rate,round(1.89*rate),plan,
                                          mode="frozen")
        f0b,spb,apb,rb=make_trajectories(vowel,rate,round(1.89*rate),plan,
                                          mode="evolving")
        self.assertTrue(np.array_equal(f0a,f0b))
        self.assertTrue(np.array_equal(spa[0],spa[-1]))
        self.assertTrue(np.array_equal(apa[0],apa[-1]))
        self.assertEqual(ra["sourceSpectralLogEndToStartDistance"],0)
        self.assertGreater(rb["sourceSpectralLogEndToStartDistance"],.5)
        self.assertFalse(np.array_equal(spa,spb))
        self.assertFalse(np.array_equal(apa,apb))
        self.assertEqual(len(f0a),spa.shape[0])

    def test_source_relative_pitch_shift_fails_closed(self):
        sr=self.sr
        vowel=[.2*math.sin(2*math.pi*110*i/sr)
               for i in range(int(sr*.24))]
        with self.assertRaisesRegex(CandidateError,"pitch shift"):
            retime_vowel_world(vowel,sr,int(sr*.6),[(0,392.0)])

    def test_noise_is_refused_as_vowel(self):
        rng=np.random.default_rng(12345)
        noise=rng.uniform(-.1,.1,12000).tolist()
        with self.assertRaises(CandidateError):
            retime_vowel_world(noise,48000,24000,[(0,330.)])

    def test_world_rejects_invalid_mode(self):
        audio,rate,digest,m=self.private_kathy()
        reg=m["regions"][1]
        segment=audio[reg["vowelStartFrame"]:reg["vowelEndFrame"]-int(rate*.07)]
        with self.assertRaisesRegex(CandidateError,"trajectory"):
            retime_vowel_world(segment,rate,rate,[(0,392.)],mode="target-trained")

    def test_world_rejects_out_of_order_pitch_events(self):
        audio,rate,digest,m=self.private_kathy()
        reg=m["regions"][1]
        segment=audio[reg["vowelStartFrame"]:reg["vowelEndFrame"]-int(rate*.07)]
        with self.assertRaisesRegex(CandidateError,"boundaries"):
            make_trajectories(segment,rate,rate,
                              [(0,392.),(12000,392.),(12000,392.)])

    def test_world_native_speech_source_frame_shape_and_melisma(self):
        audio,rate,digest,m=self.private_kathy()
        import functools
        render_vowel=functools.partial(retime_vowel_world,mode="evolving")
        sound,report=render(audio,rate,digest,m,self.score,
                            release_style="natural-vowel",
                            vowel_renderer=render_vowel)
        self.assertEqual(len(sound),249600)
        self.assertEqual([len(x["notes"])for x in report["syllables"]],[2,1,1])
        self.assertEqual([s["spectralTrajectory"]for s in report["syllables"]],
                         ["evolving"]*3)
        self.assertFalse(report["newMIDITransport"])
        self.assertFalse(report["vocalIntelligibilityQualified"])
        self.assertFalse(report["mediaPublished"])
        self.assertTrue(all(s["sourceSpectralLogEndToStartDistance"]>.3
                            for s in report["syllables"]))

    def test_world_deterministic_private_sha(self):
        audio,rate,digest,m=self.private_kathy()
        import functools
        fn=functools.partial(retime_vowel_world,mode="evolving")
        a,ra=render(audio,rate,digest,m,self.score,vowel_renderer=fn)
        b,rb=render(audio,rate,digest,m,self.score,vowel_renderer=fn)
        self.assertEqual(a,b)
        self.assertEqual(ra,rb)
        with tempfile.TemporaryDirectory(dir="/tmp",prefix="sing-world-test-") as root:
            first=write_wav(Path(root)/"first.wav",a,rate)
            second=write_wav(Path(root)/"second.wav",b,rate)
            self.assertEqual(first,second)

    def test_anchor_default_has_unmodified_original_sha(self):
        audio,rate,digest,m=self.private_kathy()
        expected="3edb992bae53c2f638a77761c6e0c9474a4dec1edc9275715463482ba4b9ebf5"
        original,report=render(audio,rate,digest,m,self.score)
        with tempfile.TemporaryDirectory(dir="/tmp",prefix="sing-native-default-") as root:
            actual=write_wav(Path(root)/"original.wav",original,rate)
        self.assertEqual(actual,expected)

    def test_wrong_source_sha_or_score_is_not_admitted(self):
        audio,rate,digest,m=self.private_kathy()
        m["sourceWavSHA256"]="0"*64
        with self.assertRaisesRegex(CandidateError,"authority"):
            render(audio,rate,digest,m,self.score,
                   vowel_renderer=retime_vowel_world)
        m["sourceWavSHA256"]=digest
        altered=copy.deepcopy(self.score)
        altered["performance"]["notes"][0]["id"]="alternate-score"
        with self.assertRaisesRegex(CandidateError,"four-note"):
            render(audio,rate,digest,m,altered,
                   vowel_renderer=retime_vowel_world)

    def test_world_no_claim_of_phonemes_from_pitch_spectrum(self):
        audio,rate,digest,m=self.private_kathy()
        reg=m["regions"][2]
        source=audio[reg["vowelStartFrame"]:reg["vowelEndFrame"]-round(rate*.07)]
        sound,r=retime_vowel_world(source,rate,round(rate*.5),[(0,329.63)])
        self.assertFalse(r["phonemesRecognized"])
        self.assertFalse(r["voicePreservedOrPerceptuallyQualified"])
        self.assertLessEqual(max(abs(i) for i in sound),.85)
        self.assertGreater(r["sourceVoicedFrames"],10)


if __name__=="__main__":
    unittest.main()
