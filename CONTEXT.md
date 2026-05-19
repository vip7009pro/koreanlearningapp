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
- Completed Phase 2 task **AI Gap Diagnostics & Study Rx (Chẩn đoán điểm yếu AI & Đơn thuốc học tập)**:
  - **Backend API**: Created `GET /analytics/diagnostics` endpoint in NestJS `AnalyticsController`. It queries incorrect answers from `TopikAnswer` records, calls `AIService` to identify core grammar/vocabulary weak concepts using Gemini, maps them to matching DB `Lesson` titles, and compiles a personalized Study Rx response.
  - **AIService**: Added `analyzeGapDiagnostics` utilizing the unified Gemini client for structural JSON-based gap analysis.
  - **Mobile Client**: Registered new GoRoute `/diagnostics` mapping to `AiDiagnosticsScreen` in `router.dart`.
  - **Mobile Screen**: Created `ai_diagnostics_screen.dart` featuring dynamic HSL dark/light themed circular progress meters for Listening/Reading/Writing skills, list of AI detected error patterns (e.g. particles/connectors), and clickable prescription cards navigating users directly to relevant study lessons.
  - **Home Screen Entry**: Integrated a premium "Bác sĩ Chẩn đoán Năng lực AI" card on the `HomeScreen` navigation dashboard.
  - **Verification**: Confirmed backend API builds successfully, and verified mobile Flutter static analysis reports zero compiler errors.
- Root AGENTS.md remains in place to enforce CONTEXT.md maintenance.