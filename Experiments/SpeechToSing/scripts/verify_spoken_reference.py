#!/usr/bin/env python3
"""Independent spoken source admission EVIDENCE for Sing; fail closed.

Lexical Apple ASR happens BEFORE this scorer, without lyrics, phone labels,
candidate spellings or score. Evaluation is explicitly *not* an independent
phoneme recognition or verified consonant/vowel boundary. Identical PCM from
different TTS spellings is ONE acoustic witness. Source quality and typed
MIDI2 pitch bounds remain independent of the lexical comparator.
"""
from __future__ import annotations
from collections import defaultdict
import hashlib
import importlib.util
import json
from pathlib import Path
import re

from vowel_anchor import CandidateError, f0, midi_hz, private, read_wav

SOURCE_BASE=Path("/tmp/sing-spoken-reference-cohort-20261025")
HIGH_BASE=Path("/tmp/sing-high-register-control-20261025")
STRICT_TARGET=frozenset(("la me na","la mi na","lah me nah"))
RATIO_MIN=.67
RATIO_MAX=1.90


def ear_canonical_lexical_contract():
    # Read Ear's actual owning comparator, NOT a copied/relaxed alias
    # list in Sing. Never edit another repository to turn failures green.
    ear_file=Path(__file__).resolve().parents[4]/"teatro.fountain.coach"/"scripts"/"ear_private_lexical_gate.py"
    if not ear_file.is_file():
        raise ValueError("Ear's canonical lexical contract is inaccessible")
    spec=importlib.util.spec_from_file_location("ear_canonical_source_lexical_contract",ear_file)
    if spec is None or spec.loader is None:
        raise ValueError("Ear lexical comparator could not be inspected")
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return {
        "accepted":frozenset(module.normalized(x)for x in module.POSITIVE_ALIASES),
        "source":str(ear_file),
        "sourceSHA256":digest(ear_file.read_bytes()),
    }


def normalized(value):
    if not isinstance(value,str):
        raise ValueError("Untrusted independent transcript type")
    return " ".join(re.findall(r"[a-z]+",value.lower()))


def get_json(path):
    return json.loads(private(str(path)).read_text())


def digest(data):
    return hashlib.sha256(data).hexdigest()


def evaluate(cohort_path=None, apple_path=None, high_source=None,
             high_transcript=None, sound_events=None, render_asr=None,
             render_sound=None):
    cohort_path=cohort_path or SOURCE_BASE/"cohort.json"
    apple_path=apple_path or SOURCE_BASE/"apple-source-blind-lexical.json"
    high_source=high_source or HIGH_BASE/"karen-pbas240.json"
    high_transcript=high_transcript or HIGH_BASE/"transcripts.json"
    sound_events=sound_events or HIGH_BASE/"sound-events.json"
    render_asr=render_asr or HIGH_BASE/"render-transcripts.json"
    render_sound=render_sound or HIGH_BASE/"render-vocal-events.json"
    plan_file=SOURCE_BASE/"plan.json"

    plan=get_json(plan_file)
    cohort=get_json(cohort_path)
    apple=get_json(apple_path)
    if (plan["schema"]!="sing.private-speech-source-search.v1"
        or plan["acceptedStrictLexicalForms"]!=sorted(STRICT_TARGET)
        or plan["plannedBeforeAcousticInference"] is not True
        or plan["sourceTextNotSuppliedToSpeechRecognizer"] is not True
        or plan["noHumanPhonemeTruthClaim"] is not True
        or cohort.get("schema")!="sing.private-speech-source-cohort.v1"
        or cohort["planSHA256"]!=digest(private(str(plan_file)).read_bytes())
        or apple.get("schema")!="sing.private-blind-lexical-cohort.v1"
        or apple["sourceCohortSHA256"]!=cohort["planSHA256"]):
        raise ValueError("Untrusted pre-registered source cohort/lexical plan")
    rows=cohort["recordings"]
    if (cohort["candidateCount"]!=len(rows)
        or cohort["plannedCombinationCount"]!=60
        or cohort["sourceQualityDropoutsAreNotRelaxed"] is not True
        or cohort["privateMediaOnly"] is not True):
        raise ValueError("Source corpus coverage or predeclared quality drift")
    by_id={}
    groups=defaultdict(list)
    for row in rows:
        path=private(row["audioPath"])
        source_manifest=private(row["manifestPath"])
        manifest=json.loads(source_manifest.read_text())
        if (path.name!=row["candidateId"]+".wav"
            or digest(path.read_bytes())!=row["audioSHA256"]
            or digest(source_manifest.read_bytes())!=row["manifestSHA256"]
            or manifest["sourceWavSHA256"]!=row["audioSHA256"]
            or manifest["sourceText"]!="la mi na"
            or manifest["spokenSpellingAttempts"]!=row["spokenSpellings"]
            or manifest["alignmentStatus"]!="provisional"
            or manifest["release"]!="not-admitted"):
            raise ValueError("Source SHA, naming, alignment or media provenance drift")
        if row["candidateId"] in by_id:
            raise ValueError("Duplicate candidate ID")
        by_id[row["candidateId"]]=row
        groups[row["audioSHA256"]].append(row)
    asr_rows=apple.get("results",[])
    if (apple.get("resultCount")!=len(rows)
        or len(asr_rows)!=len(rows)
        or "NO score" not in apple["inference"]):
        raise ValueError("Incomplete source-blind Apple transcript cohort")
    transcriptions={}
    for rec in asr_rows:
        identifier=rec.get("sourceId")
        if not isinstance(identifier,str) or not identifier.endswith(".wav"):
            raise ValueError("Bad source-blind result identity")
        sid=identifier[:-4]
        if sid not in by_id or sid in transcriptions:
            raise ValueError("Foreign/repeated source-blind transcript")
        transcriptions[sid]=normalized(rec["recognizedText"])
    if set(transcriptions)!=set(by_id):
        raise ValueError("Missing source-blind witness")
    unique_witness=[]
    for wav_sha,related in sorted(groups.items()):
        text_values={transcriptions[r["candidateId"]] for r in related}
        if len(text_values)!=1:
            raise ValueError("Identical audio yielded contradictory speech transcripts")
        unique_witness.append({
            "SHA256":wav_sha,
            "voice":related[0]["voice"],
            "duplicateFileVariants":len(related),
            "normalizedTranscript":next(iter(text_values)),
            "strictLexicalMatch":next(iter(text_values)) in STRICT_TARGET,
        })
    total_matches=sum(r["strictLexicalMatch"] for r in unique_witness)
    ear_policy=ear_canonical_lexical_contract()
    ear_cohort_matches=sum(
        r["normalizedTranscript"] in ear_policy["accepted"] for r in unique_witness
    )

    high=get_json(high_source)
    private_wav=HIGH_BASE/"karen-pbas240.wav"
    audio,rate,actual_sha=read_wav(str(private_wav))
    if (high["schema"]!="sing.speech-source.v1"
        or high["sourceWavSHA256"]!=actual_sha
        or high["sourceText"]!="la mi na"
        or high["alignmentStatus"]!="provisional"
        or high["release"]!="not-admitted"
        or high.get("pitchControlTag")!="[[pbas 240]]"
        or high.get("sourceModelOrVoice")!="macOS say / Karen / explicit pbas 240"
        or rate!=48000):
        raise ValueError("Untrusted provisional high-register input source")
    source_rec=get_json(high_transcript)
    expected_asr={r["sourceId"]:normalized(r["recognizedText"])
                  for r in source_rec["results"]}
    if set(expected_asr)!={"samantha-pbas240.wav","karen-pbas240.wav"}:
        raise ValueError("Preliminary source registered without control")
    source_matches=expected_asr[private_wav.name] in STRICT_TARGET
    source_ear_matches=expected_asr[private_wav.name] in ear_policy["accepted"]
    independent_voice=get_json(sound_events)
    if (independent_voice["phonemeRecognitionQualified"] is not False
        or independent_voice["classEvidenceIsNotPhonemeConfidence"] is not True):
        raise ValueError("Vocal evidence was falsely promoted")
    original_observations={
        x["source"]:x for x in independent_voice["observations"]}
    if private_wav.name not in original_observations:
        raise ValueError("Missing original acoustic source sound check")
    voice=original_observations[private_wav.name]
    if voice["sha256"]!=actual_sha or voice["expectedTestRole"]!="candidate":
        raise ValueError("Source independent sound witness SHA mismatch")
    vocal=voice["voiceEvidencePass"]
    note_assignment=((60,64),(67,),(64,))
    pitch_evidence=[]
    if len(high["regions"])!=3:
        raise ValueError("Expected original three separate syllable regions")
    for row,pitches in zip(high["regions"],note_assignment):
        a,b=row["vowelStartFrame"],row["vowelEndFrame"]
        if not(0<=row["onsetStartFrame"]<a<b<=len(audio)):
            raise ValueError("Source vowel region outside original waveform")
        nucleus=audio[a:b-round(rate*.07)]
        hz,corr=f0(nucleus[:round(.09*rate)],rate)
        eligible=all(RATIO_MIN<=midi_hz(n)/hz<=RATIO_MAX for n in pitches)
        pitch_evidence.append({
            "syllableId":row["syllableId"],
            "sourceEarlyHz":round(hz,3),
            "sourcePeriodicity":round(corr,4),
            "scoreNotes":list(pitches),
            "boundedPitchEligible":eligible
        })

    comparison=get_json(render_asr)
    accepted_render={x["sourceId"]:normalized(x["recognizedText"])
                     for x in comparison["results"]}
    if set(accepted_render)!={"karen-pbas240.wav",
                              "sing-karen240-world-frozen.wav",
                              "sing-karen240-world-evolving.wav"}:
        raise ValueError("Frozen/evolving lexical comparison incomplete")
    rendered_vocal=get_json(render_sound)
    observations={x["source"]:x for x in rendered_vocal["observations"]}
    if set(observations)!=set(accepted_render):
        raise ValueError("Frozen/evolving vocal witness missing")
    output=[]
    for mode in ("frozen","evolving"):
        basename=f"sing-karen240-world-{mode}.wav"
        candidate=Path("/tmp")/basename
        raw=private(str(candidate)).read_bytes()
        receipt=get_json(f"/tmp/sing-karen240-world-{mode}.json")
        if (receipt.get("trajectory")!=mode
            or receipt.get("sourceSpeechSHA256")!=actual_sha
            or receipt.get("outputSHA256")!=digest(raw)
            or observations[basename]["sha256"]!=digest(raw)
            or observations[basename]["phoneSequenceRecognized"] is not False):
            raise ValueError("Frozen/evolving SHA or vocal inference changed")
        output.append({
            "mode":mode,
            "SHA256":digest(raw),
            "independentWords":accepted_render[basename],
            "localPlanLexicalMatch":accepted_render[basename] in STRICT_TARGET,
            "earCanonicalLexicalMatch":accepted_render[basename] in ear_policy["accepted"],
            "vocalEvidencePass":observations[basename]["voiceEvidencePass"],
            "vocalEvidenceWindows":observations[basename]["vocalEvidenceWindows"],
            "soundEventWindows":observations[basename]["windows"],
        })
    actual_ear=[]
    for row in output:
        mode=row["mode"]
        receipt=get_json(f"/tmp/ear-karen240-world-{mode}-full-20261025.json")
        lexical=receipt["lexical"]
        if (receipt["browser"]["status"]!="passed"
            or lexical["sourceReferencePassed"] is not False
            or lexical["acceptedLexicalVariants"]!=sorted(ear_policy["accepted"])
            or receipt["status"]!="lexical-gate-blocked"
            or receipt["phonemeRecognition"]!="RAW_ALLPHONE_HYPOTHESES_NOT_QUALIFIED"
            or receipt["testServicesTerminated"] is not True
            or receipt["publication"]!="not-admitted"):
            raise ValueError("Ear source-only rejection must not be rewritten")
        actual_ear.append({
            "mode":mode,
            "status":receipt["status"],
            "sourceEarLexicalMatch":lexical["sourceReferencePassed"],
            "renderEarLexicalMatch":lexical["candidateLexicallyMatched"],
            "browser":receipt["browser"]["status"],
            "phonemeRecognition":receipt["phonemeRecognition"],
        })
    # Strict truth: even a pitch-safe, independently speech-transcribed
    # *synthetic* source retains provisional phone timing and zero independent
    # accepted phoneme identity; it CANNOT be promoted as a singer source.
    return {
        "schema":"sing.private-source-admission-witness.v1",
        "cohortFilesAttempted":cohort["plannedCombinationCount"],
        "cohortFilesGenerated":len(rows),
        "sourceQualityRejectedSyllables":cohort["rejectedSourceSyllables"],
        "distinctAudioSHA256Witnesses":len(groups),
        "localPlanLexicalMatchDistinctRecordings":total_matches,
        "earCanonicalLexicalMatchDistinctRecordings":ear_cohort_matches,
        "earCanonicalLexicalPolicy":sorted(ear_policy["accepted"]),
        "earLexicalPolicySourceSHA256":ear_policy["sourceSHA256"],
        "identicalAudioSpellingVariationsAreIndependent":False,
        "uniqueSources":unique_witness,
        "highRegisterSourceSHA256":actual_sha,
        "highRegisterSourceChosenAfterExploratoryPitchProbe":True,
        "highRegisterSourceRecognizedWords":expected_asr[private_wav.name],
        "highRegisterSourceLocalPlanLexicalMatch":source_matches,
        "highRegisterSourceEarCanonicalLexicalMatch":source_ear_matches,
        "highRegisterSourceVocalEvidence":vocal,
        "highRegisterSourcePitchEvidence":pitch_evidence,
        "highRegisterSourcePitchEligible":all(x["boundedPitchEligible"]for x in pitch_evidence),
        "sourcePhonemeTimes":"PROVISIONAL_NOT_VERIFIED",
        "sourcePhonemeIdentity":"NOT_QUALIFIED",
        "renderCandidates":output,
        "realEarOwnerRunResults":actual_ear,
        "phonemeRecognitionQualified":False,
        "sourceIndependentlyAnnotatedHumanReference":False,
        "voicebankRightsGranted":False,
        "mediaPublished":False,
        "admissionStatus":"DEVELOPMENT_ONLY_EAR_SOURCE_LEXICAL_AND_PHONE_ADMISSION_BLOCKED"
    }


def main():
    import argparse
    p=argparse.ArgumentParser()
    p.add_argument("--report",default="/tmp/sing-source-admission-witness-20261025.json")
    a=p.parse_args()
    receipt=evaluate()
    report=private(a.report,False)
    report.write_text(json.dumps(receipt,sort_keys=True,indent=2)+"\n")
    print(json.dumps({
        "distinctRecordedSources":receipt["distinctAudioSHA256Witnesses"],
        "localPlanLexicalMatches":receipt["localPlanLexicalMatchDistinctRecordings"],
        "earCanonicalLexicalMatches":receipt["earCanonicalLexicalMatchDistinctRecordings"],
        "provisionalLocallyMatchedPitchAndVocalSource":(
            receipt["highRegisterSourceLocalPlanLexicalMatch"]
            and receipt["highRegisterSourcePitchEligible"]
            and receipt["highRegisterSourceVocalEvidence"]),
        "sourceEarLexicalMatch":receipt["highRegisterSourceEarCanonicalLexicalMatch"],
        "sourcePhonemes":receipt["sourcePhonemeIdentity"],
        "renderComparison":receipt["renderCandidates"],
        "realEarOwnerRunResults":receipt["realEarOwnerRunResults"],
        "admissionStatus":receipt["admissionStatus"],
        "mediaPublished":False},indent=2))


if __name__=="__main__":
    main()
