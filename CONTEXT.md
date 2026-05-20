# CONTEXT

Last updated: 2026-05-19

## Persistent Rules
- Check this file before responding when it exists.
- Update this file after completing each prompt.

## Workspace
- Monorepo root: g:/NODEJS/koreanlearningapp
- Main areas: apps/admin-web, apps/api, apps/mobile, packages/*

## Notes
- Mobile offline ONNX TTS uses Sherpa vits-mimic3-ko_KO-kss_low assets (removed)
- Keep the startup copy behavior as overwrite to avoid stale runtime models.
- Mobile now uses Google Mobile Ads banner placements on browsing, profile, settings, and result/review screens.
- Subscription UI now sells monthly/yearly ad-free access; active quiz/TOPIK take flows stay ad-free by design.
- Mobile ad layer now also includes app-open ads on resume/startup, interstitials on list-to-detail taps, and larger banner placements on selected browsing/profile screens.
- Visible admin/backend copy uses ad-free wording where practical; internal compatibility names like `isPremium` and `PREMIUM` remain in place.
- `google_mobile_ads` 7.0.0 `AppOpenAd.load` does not accept an `orientation` argument; keep app-open loading on the current signature.

## Current Task
- Completed Giai đoạn 3 sub-feature **Hội thoại Tương tác AI (Interactive AI Dialogue Tutor & Speaking Practice)**:
  - **Prisma & DB**: Appended `DialogueScenario`, `DialogueSession`, and `DialogueTurn` models and successfully synchronized the schema using `npx prisma db push`.
  - **Backend API**: Developed `ai-dialogues` NestJS module exposing scenarios fetching, session initiation, and turn evaluation. Seeding default roleplays (Job Interview, Restaurant Ordering, Train Directions) is fully automated.
  - **Gemini Evaluation**: Instructed Gemini to yield structured JSON evaluating user grammar, score performance (0-100), offer native phrasing recommendations, and prompt the next character reply.
  - **Mobile UI**:
    - Add `speech_to_text` dependency to Flutter mobile workspace.
    - Set up permissions for recording audio in `AndroidManifest.xml`.
    - Created `DialogueListScreen` to browse roleplays by difficulty, and `DialoguePracticeScreen` presenting a dynamic chat bubble stream, audio transcription using Speech-to-Text, playback using Flutter TTS, and expandable Shadowing Evaluation drawers.
    - Added routes to `router.dart` and navigation cards to `HomeScreen`.
  - **Verification**: Ran NestJS compiler checks and mobile static analyses (`flutter analyze`), yielding zero errors/warnings.
- Root AGENTS.md remains in place to enforce CONTEXT.md maintenance.