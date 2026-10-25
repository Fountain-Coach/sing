#!/usr/bin/env python3
"""Private source-admission tests, no fabricated phoneme or singer truth."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parent))
from make_speech_reference_cohort import OUTPUT, plan, VOICES, SYLLABLES
from make_provisional_pitch_source import generate, DEFAULT_PREFIX
from verify_spoken_reference import (
    evaluate, ear_canonical_lexical_contract, normalized, STRICT_TARGET,
    SOURCE_BASE, HIGH_BASE
)
from vowel_anchor import read_wav


class SourceReferenceGateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        for file in (
            SOURCE_BASE/"cohort.json",SOURCE_BASE/"plan.json",
            SOURCE_BASE/"apple-source-blind-lexical.json",
            HIGH_BASE/"transcripts.json",
            HIGH_BASE/"sound-events.json",
            HIGH_BASE/"render-transcripts.json",
            HIGH_BASE/"render-vocal-events.json"
        ):
            if not file.exists():
                raise unittest.SkipTest("Private speech-reference evidence unavailable")

    def modified_receipt(self,path,edit,key):
        original=json.loads(Path(path).read_text())
        edited=json.loads(json.dumps(original))
        edit(edited)
        with tempfile.TemporaryDirectory(dir="/tmp",prefix="sing-source-gate-test-") as folder:
            file=Path(folder)/"changed.json"
            file.write_text(json.dumps(edited))
            return evaluate(**{key:str(file)})

    def test_locked_plan_is_not_ear_current_policy(self):
        source=plan()
        self.assertEqual(source["voices"],list(VOICES))
        self.assertEqual(source["utteranceSpellingOptions"],list(map(list,SYLLABLES)))
        local=frozenset(source["acceptedStrictLexicalForms"])
        self.assertEqual(local,STRICT_TARGET)
        ear=ear_canonical_lexical_contract()["accepted"]
        self.assertNotEqual(local,ear)
        self.assertIn("la me nah",ear)
        self.assertNotIn("la me na",ear)

    def test_corpus_54_files_but_only_8_unique_witnesses(self):
        result=evaluate()
        self.assertEqual(result["cohortFilesAttempted"],60)
        self.assertEqual(result["cohortFilesGenerated"],54)
        self.assertEqual(result["distinctAudioSHA256Witnesses"],8)
        self.assertEqual(len(result["sourceQualityRejectedSyllables"]),1)
        self.assertEqual(result["localPlanLexicalMatchDistinctRecordings"],0)
        self.assertEqual(result["earCanonicalLexicalMatchDistinctRecordings"],2)
        self.assertFalse(result["identicalAudioSpellingVariationsAreIndependent"])

    def test_karen_pbas_source_lexically_matches_only_local_exploratory_plan(self):
        r=evaluate()
        self.assertEqual(r["highRegisterSourceRecognizedWords"],"la me na")
        self.assertTrue(r["highRegisterSourceLocalPlanLexicalMatch"])
        self.assertFalse(r["highRegisterSourceEarCanonicalLexicalMatch"])
        self.assertTrue(r["highRegisterSourceVocalEvidence"])
        self.assertTrue(r["highRegisterSourcePitchEligible"])
        self.assertEqual([x["syllableId"]for x in r["highRegisterSourcePitchEvidence"]],
                         ["s1","s2","s3"])
        self.assertEqual(r["sourcePhonemeTimes"],"PROVISIONAL_NOT_VERIFIED")

    def test_render_winner_must_not_be_selected_from_one_source(self):
        r=evaluate()
        a,b=r["renderCandidates"]
        self.assertEqual(a["mode"],"frozen")
        self.assertEqual(a["independentWords"],"la me nah")
        self.assertTrue(a["earCanonicalLexicalMatch"])
        self.assertEqual(b["mode"],"evolving")
        self.assertEqual(b["independentWords"],"la me no")
        self.assertFalse(b["earCanonicalLexicalMatch"])
        self.assertFalse(a["vocalEvidencePass"])
        self.assertFalse(b["vocalEvidencePass"])

    def test_unmodified_ear_runs_are_both_lexically_blocked(self):
        r=evaluate()
        self.assertEqual([x["status"]for x in r["realEarOwnerRunResults"]],
                         ["lexical-gate-blocked"]*2)
        self.assertTrue(all(x["browser"]=="passed" for x in r["realEarOwnerRunResults"]))
        self.assertTrue(all(x["sourceEarLexicalMatch"] is False
                            for x in r["realEarOwnerRunResults"]))
        self.assertTrue(all("NOT_QUALIFIED" in x["phonemeRecognition"]
                            for x in r["realEarOwnerRunResults"]))
        self.assertFalse(r["phonemeRecognitionQualified"])
        self.assertFalse(r["mediaPublished"])
        self.assertFalse(r["voicebankRightsGranted"])

    def test_cannot_claim_unique_audio_from_duplicate_spellings(self):
        r=evaluate()
        groups=[x["duplicateFileVariants"]for x in r["uniqueSources"]]
        self.assertEqual(sum(groups),54)
        self.assertGreater(max(groups),1)
        self.assertEqual(len(groups),8)

    def test_spoken_wav_and_manifest_reproduce_exact_input(self):
        result=generate(DEFAULT_PREFIX)
        self.assertTrue(result["sourceSelectedAfterExploratoryPitchTrial"])
        self.assertFalse(result["phoneTimingIndependentlyVerified"])
        self.assertEqual(result["sourceSHA256"],
                         "5b9622bc6e0127e1e4c14904fb1859826bdcd8f9204d7c54ac80d318fc9c9533")
        audio,rate,sha=read_wav(result["source"])
        self.assertEqual(rate,48000)
        self.assertEqual(sha,result["sourceSHA256"])

    def test_source_manifest_sha_forgery_rejected(self):
        def edit(j):
            j["recordings"][0]["audioSHA256"]="0"*64
        with self.assertRaisesRegex(ValueError,"Source SHA"):
            self.modified_receipt(SOURCE_BASE/"cohort.json",edit,"cohort_path")

    def test_source_plan_tamper_rejected(self):
        def edit(j):
            j["planSHA256"]="0"*64
        with self.assertRaisesRegex(ValueError,"source cohort"):
            self.modified_receipt(SOURCE_BASE/"cohort.json",edit,"cohort_path")

    def test_fabricated_speech_transcript_rejected(self):
        def edit(j):
            j["results"].pop()
        with self.assertRaisesRegex(ValueError,"Incomplete"):
            self.modified_receipt(SOURCE_BASE/"apple-source-blind-lexical.json",
                                  edit,"apple_path")

    def test_voice_label_overclaim_rejected(self):
        def edit(j):
            j["phonemeRecognitionQualified"]=True
        with self.assertRaisesRegex(ValueError,"Vocal evidence"):
            self.modified_receipt(HIGH_BASE/"sound-events.json",edit,"sound_events")

    def test_missing_ear_contract_blocks_instead_of_copying_aliases(self):
        ear=ear_canonical_lexical_contract()
        self.assertEqual(len(ear["sourceSHA256"]),64)
        self.assertEqual(ear["accepted"],frozenset((
            "la mi na","la me nah","lah me nah"
        )))
        self.assertEqual(normalized("Law, me, nah."),"law me nah")

    def test_not_a_human_speech_reference(self):
        r=evaluate()
        self.assertFalse(r["sourceIndependentlyAnnotatedHumanReference"])
        self.assertEqual(r["sourcePhonemeIdentity"],"NOT_QUALIFIED")
        self.assertIn("BLOCKED",r["admissionStatus"])


if __name__=="__main__":
    unittest.main()
