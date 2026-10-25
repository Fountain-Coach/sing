# Ear and Sing: teaching traditions as an executable learning protocol
25 October 2026. Research and typed *design-only* curriculum; NOT an admitted singer, tutor, recognizer, or recording.

## Thesis
Teach the *relationship* between example, imitation, correction and variation—not the false premise that reading an aligned phoneme file is equivalent to hearing a singer. Traditional training distinguishes knowing words, producing vocal gestures, sustaining notes, interpreting dramatic text, and learning by listening. Use expert-confirmed examples when legally admitted; never let the student synthesizer silently grade itself.

## Reference owner and present blocker
Teatro/Ear commit `2821242f66075fbb7633fbfb490493a0aae4a3c1` preserves the PJS Japanese sung source and second, independently produced human phone/timing revision: https://github.com/Fountain-Coach/teatro.fountain.coach/blob/main/docs/evidence/ear-pjs-independent-manual-reference-2026-10-25.md .
PJS labels are in a case-sensitive Japanese inventory. Ear's English PocketSphinx all-phone experiment cannot evaluate them. The prior vocalist-event classifier passes its Japanese source but does not recognize its phones. No source-blind Japanese phone model, singer-disjoint qualification or independently adjudicated phone truth is established. **Do not tune a recognizer or vocabulary using held-out annotation labels.** The first engineering gate remains a language-compatible source-blind Japanese phone decoder, predeclared evaluation and negatives.

## A teacher–student–listener protocol
1. **Demonstration**: versioned, rights-authorized teacher reference or an expressly original *synthetic* cue; identify tradition, language/inventory, dialect, repertoire rights, timing/pulse and source SHA when real audio exists.
2. **Imitation**: Sing creates a candidate from the same lesson but its own independent performer identity and MIDI 2.0 score. A recorded human student's attempt would require consent. No automatic voice clone.
3. **Listening and diagnosis**: Ear receives ONLY the candidate audio and the predeclared language/model contract. Recognition (phones, times, alternatives, calibrated abstention) is blind to lyrics, score, teacher correction and reference phone labels. Acoustic and rhythmic measurements remain separate from inferred phonemes and cultural artistry.
4. **Correction**: only after source-blind inference, compare to lesson target or independently reviewed annotation. Log `cause hypothesis` distinctly from established evidence; propose one bounded change (e.g., onset length, voiced consonant, legato gap) rather than silently changing correctness thresholds.
5. **Repetition and transfer**: rerender, compare the *new* output using frozen criteria, then rehearse a new exercise. The evaluator's later examination corpus must be held out by singer, session and text; no feedback from the examination leaks into teaching.

**Two separate data planes**: teaching material may disclose words, models and target goals to the coach; the examination runner cannot read them until after inference. Practice success is not independent qualification. Diction, vocal comfort/physiology, artistic interpretation, singer identity and release are distinct judgments.

## What to study from each tradition
| Tradition / corpus | Lesson movement | Ear's eventual objective | Sing's expressive control |
| --- | --- | --- | --- |
| Italian bel canto, recitative and later opera | Speak Italian text; sustain open/closed vowels; keep a legato line; then practice consonant doubling, agility, messa di voce and phrasing | Italian phone identity and word stress; duration of geminates, vowel transitions, gaps/legato, note motion and dynamics | Source-filter control, smooth transitions, dynamic arc, pitch-portamento and syllable-safe melisma |
| German Lied, Singspiel and operatic declamation (not one uniform style) | First speak the line meaningfully; align long/short vowels and consonant clusters to musical stress; alternate spoken and sung diction | German-specific phoneme inventory, consonant intelligibility, schwa, phrase timing and intentional declamation | Language-aware consonant scheduling, stress and phrase-level dynamics; preserve /ç/, /x/ contrasts when sources permit |
| Spanish lyric theatre, especially zarzuela (and separately Spanish-language opera) | Speak the dramatic exchange, then sing it; preserve lexical stress, vowel clarity and idiomatic rhythm; specify dialect, not generic "Spanish" | Dialect-appropriate consonants, vowels, speech/singing boundary and stress | Scene-aware dialogue-to-song switching, flexible rhythmic phrasing without assuming all zarzuela is a single technique |
| North Indian tabla teaching, as a **methodological analogy**, not a European vocal style | Vocalize named bols; clap/mark the tala; imitate the teacher; vary a permitted phrase; only then play | Spoken bol/cycle alignment and placement of sam/khali as *rhythmic* evidence, NOT IPA phone truth for opera | Score/pulse alignment, recitation before execution, repeat/variation, explicit memory of rhythmic pattern and correction |
| Hindustani vocal pedagogy, kept distinct from tabla | Listen to drone; echo swara/sargam; practice sustained intonation, raga-dependent movement and daily riyaz under teacher guidance | Swara, tonal stability, permitted ornament and tala relations *only with an admitted tradition-specific annotation and expert* | Pitch continuum and timing vocabulary independent of Western equal-tempered note labels when a qualified model exists |

*Important distinction*: Opera languages are not interchangeable phoneme dictionaries. "Italian/German/Spanish opera" names multiple performing histories; zarzuela is not just "Spanish bel canto". Tabla bols are rhythmic/motor syllables, not an importable sung-phone inventory. Hindustani vocal/raga knowledge must not be reduced to tabla recitation or translated to Western operatic pitch/notation by default.

## First authored rehearsals, strictly no audio
`examples/teaching-traditions-v1.json` records five authored *text-only* classroom exercises: Italian `mamma` (gemination and sustained vowel), German `Licht` (text/consonant), Spanish `luna` (accent and spoken-to-sung transition), an invented four-bol tabla teaching fragment (recitation/cycle; **not** a full theka), and abstract `Sa Re Ga` swara rehearsal (not a raga). No singer source, true transcription, timing, pitch measurement, consent grant or released audio is claimed. `schemas/sing-teaching-cycle-v1.schema.json` and `tools/check_teaching_cycle.py` provide *authored-data* integrity only.

## Protocol acceptance conditions
- **Ear P0**: Japanese-model language inventory compatible with PJS; sealed original/revised human label manifest; no label or lyric enters inference; independent negative/near-phone controls and multi-singer heldout; publish error rates, timing distributions and abstentions; retain blocked status until actually passed.
- **Sing P1**: five lesson manuscripts validate with distinct tradition/language/symbol-system roles. Add a versioned teacher–learner exchange *only after* an authorized reference exists; no source audio or token labels published by this test fixture.
- **Ear/Sing P2**: private, source-addressed listen–imitate–compare–correct–repeat session with immutable candidate hashes and before/after diagnostic receipts. The teacher criterion is frozen before the candidate is rendered.
- **MIDI 2.0/midi2sampler P3**: keep the single existing typed Universal MIDI Packet plane for performance; use sampler DSP only if compiled/qualified. Symbolic text, bol names, phoneme inventories, edition and voice provenance remain in separate typed instrument state. No CoreMIDI, no GitHub CI, no new transport.
- **Release P4**: independent human experts may review diction or tradition suitability; teaching feedback is not permission to synthesize a known performer or release a recording. Only existing editorial/rights authorities can publish.

## Sources and scope
- OPERA America, *Essential Skills and Training for Classical Singers* (2024): https://www.operaamerica.org/media/nhol4igk/essential-skills-and-training-for-classical-singers_rev0827.pdf
- Kurt Adler, *Phonetics and Diction in Singing* (Italian, German, Spanish and French): https://www.upress.umn.edu/9780816604463/phonetics-and-diction-in-singing/
- David Adams, *A Handbook of Diction for Singers*: https://academic.oup.com/book/44059
- Escuela Superior de Canto de Madrid, lyric phonetic resources, including original Spanish conventions: https://escm.es/recursos-foneticos-musicales/
- Teatro de la Zarzuela / INAEM, genre context: https://teatrodelazarzuela.inaem.gob.es/es/quienes-somos/genero
- CBSE Hindustani percussion syllabus, recitation with hand beats: https://cbseacademic.nic.in/web_material/Curriculum16/Secondary/Secondary%20School%20Curriculum%20Vol%201.pdf
- Tabla training progression (theka and solo repertoire): https://www.tablaglen.com/teaching
- Dhrupad teaching ethnography, demonstration/emulation/gesture: https://www.mdpi.com/2227-7102/14/2/203
- Real singer coaching: https://www.operaamerica.org/industry-resources/2025/oral-history-project/opera-america-onstage-an-oral-history-with-isabel-leonard/

No library or web text is copied into a training corpus and no third-party audio has been obtained for these new lessons.