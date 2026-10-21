"""Synthetic phrase-only tests; no audio synthesis or publication claims."""
import copy
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from check_phrase import verify, PhraseError

FIXTURE = json.loads((ROOT / "examples" / "three-syllables.json").read_text(encoding="utf-8"))


class PhraseIntegrityTests(unittest.TestCase):
    def test_three_syllable_fixture(self):
        result = verify(copy.deepcopy(FIXTURE))
        self.assertEqual((result["syllables"], result["notes"], result["melismaNotes"]), (3, 3, 0))

    def test_unknown_syllable_rejected(self):
        case = copy.deepcopy(FIXTURE)
        case["performance"]["notes"][1]["syllableId"] = "missing"
        with self.assertRaises(PhraseError):
            verify(case)

    def test_invalid_timing_rejected(self):
        case = copy.deepcopy(FIXTURE)
        case["performance"]["notes"][0]["offMs"] = -1
        with self.assertRaises(PhraseError):
            verify(case)

    def test_melisma_same_syllable_does_not_retrigger(self):
        case = copy.deepcopy(FIXTURE)
        case["performance"]["notes"].insert(1, {
            "id": "n1b", "syllableId": "s1", "pitch": 64,
            "onMs": 410, "offMs": 430, "velocity16": 30000,
            "advanceSyllable": False})
        self.assertEqual(verify(case)["melismaNotes"], 1)
        case["performance"]["notes"][1]["advanceSyllable"] = True
        with self.assertRaises(PhraseError):
            verify(case)

    def test_render_fraud_rejected(self):
        case = copy.deepcopy(FIXTURE)
        case["renderIntent"]["state"] = "rendered"
        with self.assertRaises(PhraseError):
            verify(case)


if __name__ == "__main__":
    unittest.main()
