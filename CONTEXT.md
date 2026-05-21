# CONTEXT

Last updated: 2026-05-21

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
- Fixed TOPIK exam screen question layout:
  - Added HTML break tag parsing (`_parseQuestionText` RegExp utility) to both [topik_take_screen.dart](file:///g:/NODEJS/koreanlearningapp/apps/mobile/lib/screens/topik_take_screen.dart) and [topik_review_screen.dart](file:///g:/NODEJS/koreanlearningapp/apps/mobile/lib/screens/topik_review_screen.dart).
  - Split the question content into two parts: instruction (rendered in bold, size 16) and question/paragraph body (rendered in normal weight, size 16), separated by a vertical spacer to make paragraphs highly legible.
- Seeded 500 leaderboard users:
  - Created [seed_leaderboard.ts](file:///g:/NODEJS/koreanlearningapp/apps/api/prisma/seed_leaderboard.ts) to generate 500 random users with standard Vietnamese names, realistic emails, random XP, and random streak counts.
  - Successfully executed the script via `npx ts-node prisma/seed_leaderboard.ts` to populate the database for high-fidelity Leaderboard tab testing.
  - Updated [gamification.service.ts](file:///g:/NODEJS/koreanlearningapp/apps/api/src/modules/gamification/gamification.service.ts) to parse query limit parameters safely and increased the default leaderboard response size from `20` to `100` so that the mobile app shows a vibrant top 100 list out-of-the-box.
- Fixed Admin Web User list limit:
  - Added server-side pagination with page size dropdown (10, 20, 50, 100) and page selection buttons to [UsersPage.tsx](file:///g:/NODEJS/koreanlearningapp/apps/admin-web/src/pages/UsersPage.tsx).
  - Admins can now view, browse, and paginate through all 500+ users dynamically.
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
- Home Screen & SilverAppBar Branding Redesign:
  - Completely redesigned `SliverAppBar` in `home_screen.dart` to emphasize the "Tiếng Hàn FDI" brand.
  - Implemented a custom `flexibleSpace` using `LayoutBuilder` that computes a progress ratio dynamically.
  - Added smooth cross-fading animations: when expanded, displays a large personalized greeting, a premium "TIẾNG HÀN FDI" brand row with a tagline ("Học tiếng Hàn, chạm ngàn cơ hội FDI"), and streak/XP/ticket chips; when collapsed, exhibits a centered, elegant, smaller "TIẾNG HÀN FDI" logo row.
  - Added background glassmorphic/glowing circular gradient visual accents for a state-of-the-art aesthetic.
  - Integrated the profile avatar button as a persistent action item in the top-right corner of the app bar, resolving all related Dart analyzer nullability errors.
  - Cleaned up deprecated `withOpacity` calls inside `home_screen.dart` to use `withValues(alpha: ...)`.
- Root AGENTS.md remains in place to enforce CONTEXT.md maintenance.
- TOPIK Exam Image Support:
  - Added `imageUrl` (String?) and `imagePrompt` (String?) columns to `TopikQuestion` model in `schema.prisma` and pushed to database.
  - Updated `CreateTopikQuestionDto` and `UpdateTopikQuestionDto` in `topik.dto.ts` to accept the new fields.
  - Updated `adminCreateQuestion` and `adminImportExam` in `topik.service.ts` to persist `imageUrl` and `imagePrompt`.
  - Extended `TopikGeneratedQuestion` type in `ai.service.ts` with `imageUrl` and `imagePrompt`.
  - Updated `TOPIK_SYSTEM_PROMPT` and `generateTopikQuestionsChunk` user prompt in `ai.service.ts` to instruct AI to generate detailed `imagePrompt` descriptions for visual questions (TOPIK I listening pictures, TOPIK II essay charts, etc.) and always set `imageUrl = null`.
  - Updated normalization logic in `generateTopikExamPayload` to carry `imageUrl` and `imagePrompt` through.
  - Updated `TopikExamEditorPage.tsx` (Admin Web) with:
    - Image Prompt textarea + Copy button, Image URL input + Upload button, and image preview.
    - An image filter toggle switch to only view questions that have an image or prompt, based on saved/database state (avoiding premature disappearance during manual input edits).
    - Collapsible and expandable sections with interactive header states, visual indicators, and quick "Thu gọn tất cả" (Collapse all) / "Mở rộng tất cả" (Expand all) controls.
  - Updated `prompt_generator.dart` (Mobile) to sync TOPIK prompt template with new `imageUrl`/`imagePrompt` fields.
  - Updated `admin_topik_exam_editor_screen.dart` (Mobile Admin) with `imageUrl` and `imagePrompt` TextFields in the edit question dialog and included them in the API patch.
  - Updated `topik_take_screen.dart` (Mobile) to display uploaded images via `Image.network` or a tappable placeholder box (grey with icon) when `imagePrompt` exists but `imageUrl` is empty. Tap shows a dialog with the full `imagePrompt` text.
  - Updated `topik_review_screen.dart` (Mobile) with identical image/placeholder display logic.
- NestJS Payload limit increase:
  - Added `body-parser` configuration in `main.ts` (API) to increase the JSON and urlencoded payload size limits to `10mb` to handle large generated TOPIK exam JSON structures (100+ questions and image prompts) without throwing `PayloadTooLargeError: request entity too large`.
- Mobile TOPIK navigation fixes (system back button):
  - Root cause: `topik_take_screen.dart` used `context.go('/review')` after exam submission, which REPLACED the entire GoRouter navigation stack. This left the review screen as the only entry in the stack, so system back exited the app.
  - Fix: Changed `context.go()` to `context.pushReplacement()` in `topik_take_screen.dart` line 689. This replaces ONLY the current route (take→review) while preserving parent routes in the stack: `['/', '/topik', '/topik/exam/:examId', '/review']`.
  - `TopikReviewScreen`: Removed `WidgetsBindingObserver`, `PopScope`, and custom AppBar back button. Flutter's default back behavior now works because the stack is preserved.
  - `TopikExamsScreen`: Kept `WidgetsBindingObserver` as safety net for edge cases (deep linking to `/topik` with flat stack). Added custom AppBar back with canPop check.
- Admin Web UX Improvements:
  - Implemented a clean, beautiful filter and collapsible panel interface in `TopikExamEditorPage.tsx` with premium look and feel.
  - Validated build success with `tsc --noEmit` checking successfully with 0 errors.
- TOPIK Exam Audio Support:
  - Added `UploadModule` import to `topik.module.ts` to allow injectability of `UploadService` in `TopikService`.
  - Added `POST /questions/:id/generate-audio` endpoint to `topik.admin.controller.ts`.
  - Added `generateTtsAudio` helper in `ai.service.ts` using `gemini-3.1-flash-tts-preview`, dynamically parsing dialogue speakers from the script using a global regular expression (supporting inline single-line dialogues like `남: ... 여: ...` as well as newline-separated scripts) and supplying exactly 2 matching voice configurations (mapping first detected female/male speakers to `Kore`/`Puck` voices) or falling back to single-speaker configurations if fewer than 2 speakers exist. This resolves the 400 `INVALID_ARGUMENT: the number of enabled_voices must equal 2` error and ensures multi-voice generation works for inline scripts.
  - Prepended a custom 44-byte WAV header to the raw PCM audio bytes to build a valid WAV container.
  - Added `adminGenerateQuestionAudio` in `topik.service.ts` to parse `listeningScript`, request AI generation, write the resulting WAV file to `./uploads/audio/{uuid}.wav`, update the question's `audioUrl` in the database, and return the updated entity.
  - Added `generateQuestionAudio` frontend helper in `api.ts`.
  - Added audio URL input, audio upload button (calling `uploadApi.uploadAudio`), "AI Gen" button (calling TTS endpoint with loading states), and an interactive `<audio>` controller for listening-only questions in `TopikExamEditorPage.tsx`.
  - Verified backend and frontend compile with 0 TypeScript/lint warnings.