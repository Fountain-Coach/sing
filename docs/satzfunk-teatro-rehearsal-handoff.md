# sing → Teatro → Satzfunk: instrument rehearsal handoff

**Date:** 2026-10-21. **Status:** proposed typed integration; NOT a working public web remix tool.

## One performance identity, multiple ways of hearing

Source/work identity and edition (Reframe/Works) → selected phonetic excerpt → author-approved musical/expressive score (Teatro, ScoreKit, AudioTalk) → renderer (sing, licensed Alter/Ego reference, OpenAI generated *speech*, or Csound) → private render receipt and comparison (Satzfunk) → independently admitted First Hearing publication.

The author explicitly wants to **develop and enliven** the existing Satzfunk web-based listening archive and First Hearings, not replace it. The existing Bandcamp and restored 7VST playback history, timed text and rights records are the reference. See [Satzfunk additive listening/rehearsal direction](https://github.com/Fountain-Coach/Satzfunk/blob/main/docs/scenarios/2026-10-21-public-hearing-reel-and-teatro-remix-growth.md).

## Handoff fields (proposal)

A private author rehearsal proposal should bind: `workId`, `sourceEditionId`, `sourceRevisionHash`, `albumId`, `trackId`, `sourceTimeRangeMs`, optional `passageId`, `authoredScoreRevision`, `renderer`, `voiceId`, `instrumentProfile`, `performerGrant` metadata (never a secret), and `candidateOnly:true`. All references must be asserted and authorized by the owning domain. No source MP4, lyrics of unlicensed translations, host credentials or phonetic bank are embedded in a link.

An immutable proposal can be opened in an actual Teatro receiving adapter **once that adapter is implemented and tested**. Do not publish a decorative or broken “Remix” link in the public station today. The author's own private rehearsal surface may store a *pending proposal* until the adapter is real.

## The distinct sound lanes

- **sing:** audio precisely performed to pitched MIDI 2.0 notes, phoneme alignment, melisma, vibrato, pressure and continuous articulatory changes. Procedural PPG Phonem-inspired resonator instruments and corpus-based singers are interchangeable under the same performance score; no copying of proprietary plugin banks.
- **OpenAI voice:** natural spoken interpretation and interactive spoken stage direction; requires paid and bounded host grant. OpenAI's `gpt-4o-mini-tts` is deprecated and scheduled for shutdown 2027-01-06; its recommended successor `gpt-realtime-2.1-mini` uses Realtime, not `/v1/audio/speech`. Validate real voice quality and avoid claims of deterministic note-per-syllable singing.
- **Teatro/Csound:** spatial/instrumental score plus clock/physical execution witness.
- **Historical media:** comparison/reference listening without changing 2017 sources; new derived editions must retain original credits and independently cleared transformation rights.

## UI / provenance

The listener sees original and author-approved hearing. The author sees **listen → select → direct → audition alternate → compare → accept** in the contextual space, then publication as a separate transaction. Public readers do not receive an unchecked general-purpose asset editing capability.

Each renderer must produce hashes, executable source revisions, instrument/provenance metadata, acoustic witness and voice-origin/AI disclosure. A candidate recording is not a released version. No direct public repository deployment or new paid API requests are authorized here.

## First test

Take `examples/three-syllables.json` (original synthetic data, no third-party voice), compile its phonetic plan and MIDI2 note schedule, and produce real isolated audio; next link a permitted small excerpt of a privately restored 7VST part as *reference only*, and render a separately authored and rights-cleared alternate performance. Confirm author-controlled hearing comparison in the existing Satzfunk browser before attempting a public maker feature.
