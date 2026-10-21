#!/usr/bin/env python3
"""Check sing.phrase.v1 synthetic fixture integrity; does not synthesize audio.

When jsonschema is installed, additionally validate against the full published
JSON Schema. Without it, basic structural and semantic checks still run.
"""
import argparse
import json
from pathlib import Path


class PhraseError(ValueError):
    pass


def require(ok, reason):
    if not ok:
        raise PhraseError(reason)


def verify(data):
    require(isinstance(data, dict), "phrase must be an object")
    require(data.get("schema") == "sing.phrase.v1", "unsupported schema")
    source = data.get("source")
    phrase = data.get("phrase")
    performance = data.get("performance")
    voice = data.get("voiceSelection")
    render = data.get("renderIntent")
    require(isinstance(source, dict) and source.get("text") and source.get("rights"), "source text and rights required")
    require(isinstance(phrase, dict) and isinstance(phrase.get("syllables"), list) and phrase["syllables"], "syllables required")
    require(isinstance(performance, dict) and performance.get("timebase") == "milliseconds", "timebase must be milliseconds")
    require(isinstance(voice, dict) and voice.get("status") in ("unbound", "selected"), "voice state required")
    if voice["status"] == "selected":
        require(bool(voice.get("voiceId")), "selected voice needs an ID")
    require(isinstance(render, dict) and render.get("state") == "not-rendered"
            and render.get("release") == "not-admitted", "authored fixture cannot claim rendering or release")

    syllables = phrase["syllables"]
    ids = []
    for syllable in syllables:
        require(isinstance(syllable, dict) and syllable.get("id") and syllable.get("text"), "syllable identity/text required")
        ps = syllable.get("phonemes")
        require(isinstance(ps, list) and ps, "nonempty phoneme list required")
        require(sum(p.get("role") == "nucleus" for p in ps if isinstance(p, dict)) == 1,
                "one vowel nucleus required per example syllable")
        ids.append(syllable["id"])
    require(len(ids) == len(set(ids)), "duplicate syllable ID")
    notes = performance.get("notes")
    require(isinstance(notes, list) and notes, "notes required")
    seen_notes, seen_syllables = set(), set()
    previous_on = -1
    for note in notes:
        require(isinstance(note, dict) and note.get("id") not in seen_notes and note.get("id"),
                "duplicate/missing note ID")
        seen_notes.add(note["id"])
        sid = note.get("syllableId")
        require(sid in ids, "note references missing syllable")
        on, off = note.get("onMs"), note.get("offMs")
        require(type(on) is int and type(off) is int and 0 <= on < off and on >= previous_on,
                "invalid/out-of-order note timing")
        previous_on = on
        require(type(note.get("pitch")) is int and 0 <= note["pitch"] <= 127,
                "invalid MIDI pitch")
        require(type(note.get("velocity16")) is int and 0 <= note["velocity16"] <= 65535,
                "invalid velocity")
        require(type(note.get("advanceSyllable")) is bool, "explicit syllable advance required")
        if sid not in seen_syllables:
            require(note["advanceSyllable"], "first note of syllable must advance it")
            seen_syllables.add(sid)
        else:
            require(not note["advanceSyllable"],
                    "same syllable repeated across notes must not retrigger onset (melisma)")
    return {"syllables": len(syllables), "notes": len(notes), "melismaNotes": len(notes) - len(seen_syllables),
            "status": "authored-data-verified-not-rendered"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phrase", type=Path)
    args = parser.parse_args()
    data = json.loads(args.phrase.read_text(encoding="utf-8"))
    schema_path = Path(__file__).resolve().parents[1] / "schemas" / "sing-phrase-v1.schema.json"
    used_schema = False
    try:
        import jsonschema
    except ImportError:
        pass
    else:
        jsonschema.validate(data, json.loads(schema_path.read_text(encoding="utf-8")))
        used_schema = True
    report = verify(data)
    report["fullJsonSchemaValidated"] = used_schema
    print(json.dumps(report, sort_keys=True))


if __name__ == "__main__":
    main()
