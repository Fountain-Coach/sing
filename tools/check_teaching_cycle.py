#!/usr/bin/env python3
"""Validate a design-only Sing teaching cycle; does not listen, synthesize or train."""
import argparse
import json
from pathlib import Path


class TeachingCycleError(ValueError):
    """Unsafe or malformed authored exercise."""


TRADITIONS = {
    "italian-bel-canto": ("direct-vocal-study", "it", "ipa-planned"),
    "german-lyric-declamation": ("direct-vocal-study", "de", "ipa-planned"),
    "spanish-zarzuela": ("direct-vocal-study", "es", "ipa-planned"),
    "north-indian-tabla": ("teaching-method-transfer", "und", "tabla-bols"),
    "hindustani-vocal-riyaz": ("direct-vocal-study", "und", "sargam"),
}
STEPS = {
    "teacher-demonstrate", "listen-to-drone", "echo-spoken",
    "recite-on-pulse", "recite-bols", "clap-cycle", "echo-sung",
    "play-rhythm", "contrast", "correct", "repeat", "vary",
}
AUTHORITY = {
    "teacherAudio": "none",
    "humanAnnotations": "none",
    "independentInference": "not-run",
    "singerQualification": "blocked",
    "publication": "not-admitted",
}
EVALUATION = {
    "scope": "coaching-design-only",
    "inferenceLabelAccess": "forbidden",
    "heldoutEvaluation": "separate-repository-owner",
}


def require(ok, message):
    if not ok:
        raise TeachingCycleError(message)


def exact_keys(value, keys, kind):
    require(isinstance(value, dict) and set(value) == set(keys),
            kind + " has missing, extra or unsupported fields")


def verify(data):
    exact_keys(data, {"schema", "status", "sessions"}, "teaching cycle")
    require(data["schema"] == "sing.teaching-cycle.v1" and
            data["status"] == "design-only", "no executable or qualified teaching claim")
    sessions = data["sessions"]
    require(isinstance(sessions, list) and sessions, "at least one session required")
    seen = set()
    for entry in sessions:
        exact_keys(entry, {"id", "tradition", "relation", "languageTag",
                           "symbolSystem", "material", "focus", "steps",
                           "authority", "evaluation"}, "session")
        sid = entry["id"]
        require(isinstance(sid, str) and sid and sid not in seen, "missing/duplicate session id")
        seen.add(sid)
        tradition = entry["tradition"]
        require(tradition in TRADITIONS, "unknown tradition cannot default to opera IPA")
        require((entry["relation"], entry["languageTag"], entry["symbolSystem"]) ==
                TRADITIONS[tradition], "tradition/language/notation boundary mismatch")
        material = entry["material"]
        exact_keys(material, {"kind", "text", "rights"}, "material")
        require(material["kind"] == "original-text-only" and
                isinstance(material["text"], str) and material["text"].strip() and
                isinstance(material["rights"], str) and material["rights"].strip(),
                "only rights-scoped, text-only original teaching prompts are allowed")
        focus, steps = entry["focus"], entry["steps"]
        require(isinstance(focus, list) and bool(focus) and
                all(isinstance(x, str) and x.strip() for x in focus) and
                len(set(focus)) == len(focus), "distinct focus skills required")
        require(isinstance(steps, list) and len(steps) >= 5 and
                all(x in STEPS for x in steps) and len(set(steps)) == len(steps),
                "known, distinct teaching stages required")
        require(steps[0] == "teacher-demonstrate", "teacher example must precede pupil attempt")
        require(all(x in steps for x in ("contrast", "correct", "repeat")),
                "feedback and an actual correction/retry plan required")
        require(steps.index("contrast") < steps.index("correct") <
                steps.index("repeat"), "do not correct before independent comparison")
        if tradition == "north-indian-tabla":
            require(all(x in steps for x in ("recite-bols", "clap-cycle", "play-rhythm")) and
                    "echo-sung" not in steps, "tabla is rhythmic spoken-bol pedagogy, not opera phone training")
        else:
            require("echo-sung" in steps and
                    not any(x in steps for x in ("play-rhythm", "recite-bols", "clap-cycle")),
                    "vocal study requires sung imitation, not tabla stroke transcriptions")
        if tradition == "hindustani-vocal-riyaz":
            require("listen-to-drone" in steps, "sargam exercise requires drone listening")
        exact_keys(entry["authority"], AUTHORITY, "authority")
        require(entry["authority"] == AUTHORITY, "no evidence/qualification/release is admitted")
        exact_keys(entry["evaluation"], EVALUATION, "evaluation")
        require(entry["evaluation"] == EVALUATION,
                "never expose expected labels during future blind inference")
    return {"sessions": len(sessions), "traditions": sorted({s["tradition"] for s in sessions}),
            "status": "authored-practice-contract-only", "independentRecognition": "not-run"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("fixture", type=Path)
    args = parser.parse_args()
    fixture = json.loads(args.fixture.read_text(encoding="utf-8"))
    report = verify(fixture)
    schema = Path(__file__).resolve().parents[1] / "schemas/sing-teaching-cycle-v1.schema.json"
    report["fullJsonSchemaValidated"] = False
    try:
        import jsonschema
    except ImportError:
        pass
    else:
        jsonschema.validate(fixture, json.loads(schema.read_text(encoding="utf-8")))
        report["fullJsonSchemaValidated"] = True
    print(json.dumps(report, sort_keys=True))


if __name__ == "__main__":
    main()
