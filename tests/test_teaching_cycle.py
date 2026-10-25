"""Teaching-method data integrity only; no audio and no recognition inference."""
import copy
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from check_teaching_cycle import verify, TeachingCycleError

FIXTURE = json.loads((ROOT / "examples" / "teaching-traditions-v1.json").read_text())


class TeachingContractTests(unittest.TestCase):
    def change(self, mutate):
        candidate = copy.deepcopy(FIXTURE)
        mutate(candidate)
        with self.assertRaises(TeachingCycleError):
            verify(candidate)

    def test_five_distinct_culturally_scoped_exercises(self):
        result = verify(copy.deepcopy(FIXTURE))
        self.assertEqual(result["sessions"], 5)
        self.assertEqual(result["independentRecognition"], "not-run")

    def test_rejects_imaginary_teacher_audio(self):
        self.change(lambda x: x["sessions"][0]["authority"].__setitem__("teacherAudio", "captured"))

    def test_rejects_claimed_qualified_singer(self):
        self.change(lambda x: x["sessions"][1]["authority"].__setitem__("singerQualification", "passed"))

    def test_rejects_automatic_publication(self):
        self.change(lambda x: x["sessions"][2]["authority"].__setitem__("publication", "approved"))

    def test_rejects_extra_reference_annotation_field(self):
        self.change(lambda x: x["sessions"][0].__setitem__("expectedPhones", ["m", "a"]))

    def test_rejects_annotation_leak_to_inference(self):
        self.change(lambda x: x["sessions"][1]["evaluation"].__setitem__("inferenceLabelAccess", "allowed"))

    def test_rejects_mislabeled_tabla_as_italian_ipa(self):
        self.change(lambda x: x["sessions"][3].__setitem__("symbolSystem", "ipa-planned"))

    def test_rejects_tabla_as_operatic_singing(self):
        self.change(lambda x: x["sessions"][3]["steps"].append("echo-sung"))

    def test_rejects_mismatched_german_language(self):
        self.change(lambda x: x["sessions"][1].__setitem__("languageTag", "it"))

    def test_rejects_unlicensed_reference(self):
        self.change(lambda x: x["sessions"][2]["material"].__setitem__("rights", ""))

    def test_rejects_feedback_before_comparison(self):
        self.change(lambda x: x["sessions"][0]["steps"].__setitem__(slice(4, 6), ["correct", "contrast"]))

    def test_rejects_missing_drone_in_hindustani_vocal_study(self):
        self.change(lambda x: x["sessions"][4]["steps"].remove("listen-to-drone"))

    def test_rejects_reused_session_id(self):
        self.change(lambda x: x["sessions"][1].__setitem__("id", x["sessions"][0]["id"]))

    def test_rejects_unknown_tradition(self):
        self.change(lambda x: x["sessions"][1].__setitem__("tradition", "one-universal-opera-voice"))

    def test_rejects_target_hidden_inside_text_source(self):
        self.change(lambda x: x["sessions"][0]["material"].__setitem__("privateAudioSha256", "0" * 64))


if __name__ == "__main__":
    unittest.main()
