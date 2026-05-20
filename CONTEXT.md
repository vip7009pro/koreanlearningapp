# CONTEXT

Last updated: 2026-05-20

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
- Upgraded `speech_to_text` to `^7.3.0` to resolve compilation errors (unresolved reference `Registrar` on Flutter 3.35.5).
- Upgraded `firebase_core` to `^3.0.0` and `firebase_auth` to `^5.0.0` to maintain compatibility with updated dependency requirements.

## Current Task
- Completed all Interactive AI Dialogue & Speaking Practice features:
  - Added a prominent "Bắt đầu" splash UI to `DialoguePracticeScreen` when starting a new session to avoid polluting session history with empty trials.
  - Implemented dynamic session creation, delaying network instantiation until the "Bắt đầu" button is clicked.
  - Added an "Auto-reply" Switch toggle in the input panel allowing users to choose whether their spoken replies are auto-sent.
  - Increased speech-to-text pause duration to 4 seconds inside `SpeechListenOptions` to give users breathing/thinking room before concluding their turn.
  - Added session deletion support (`ApiClient.deleteDialogueSession`), prompting confirmation dialog and deleting targeted sessions from the history sheet on the fly.
  - Cleaned up unused elements and deprecated lints (`_isCreatingSession`, `withOpacity`, `activeColor` in Switch, direct `pauseFor` params) to pass `flutter analyze` with 0 warnings/errors.
- Added AI Tickets Balance in Personal Profile Page:
  - Designed and added a modern Ticket Balance card inside `ProfileScreen` using Riverpod state provider.
  - Linked the "Mua thêm" (Buy more) button to direct the user to the store page `/store`.
- Monorepo Admin CRUD:
  - Built full CRUD capabilities for AI Dialogue scenarios on both backend (`AIDialoguesService` & `AIDialoguesController`) and React Admin Panel (`DialogueScenariosPage.tsx`).
- Configured forced model overriding on NestJS backend:
  - Added environment variable configuration support for `FORCE_AI_MODEL` and `DEFAULT_AI_MODEL`.
  - Implemented automatic resolution of the underlying AI provider based on the model name format (e.g. `models/...` targets Google Gemini directly, slashes resolve to OpenRouter).
  - Updated all JSON/text generation calls and the writing correction service to force the environment-specified model name whenever `FORCE_AI_MODEL=true` is set.
  - Added dedicated console logs (`[AI Call]`) printing the active model name and clearly highlighting if it was forced.
- Fixed AI Writing analysis language to enforce Vietnamese responses:
  - Updated `SYSTEM_PROMPT` in `AIService` to strictly require that overall feedback, explanations, and instructions must be returned in Vietnamese, reserving Korean exclusively for corrections and grammar examples.
- Implemented AI Dialogue ticket decrementing and client-side balance controls:
  - Added user ticket check and ticket decrement logic in `submitTurn` inside `AIDialoguesService` on backend.
  - Added out-of-tickets dialog and checks to `_startPractice` and `_sendTurn` in `DialoguePracticeScreen` on mobile app.
  - Added `refreshProfile` trigger in `ProfileScreen`'s data load to ensure ticket balance is fetched correctly when user navigates to the page.
- AI Writing History & UX Improvements:
  - Added `correctedText` (String) and `errors` (Json) to the database schema for `AIWritingPractice` and successfully updated the database via `npx prisma db push`.
  - Saved corrected text and the errors list returned by the AI into the database during writing correction.
  - Modified the mobile app's `WritingDetailScreen` to correctly render the corrected text and errors list sections if they are present in the history item.
  - Displayed remaining AI tickets on the home screen next to Streak and XP chips, with horizontal scrolling to prevent layout overflows.
  - Resolved `GoRouter` routing lint error in `DialoguePracticeScreen` by importing `package:go_router/go_router.dart`.
  - Refactored `HomeScreen` to feature custom decorated, border-radius 16 container-based cards with theme-matching vibrant gradient backgrounds (using `theme.gradient` for Courses and a blue-indigo gradient for TOPIK exams), white text colors, and translucent inner badges to harmonize perfectly with the premium widgets at the top.
- Subscription Check Refinement:
  - Corrected `isPremium` checks in `home_screen.dart`, `store_screen.dart`, `dialogue_practice_screen.dart`, and `ai_writing_screen.dart` to check `user?['subscription']?['planType'] != 'FREE'`. This resolves the bug where non-admin users with a FREE plan subscription (which is created by default upon registration) were falsely shown as having unlimited "Vô hạn AI" access while their profile screen showed the correct ticket counts.
- Root AGENTS.md remains in place to enforce CONTEXT.md maintenance.