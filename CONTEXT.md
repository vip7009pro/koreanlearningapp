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
- Updated database schema with `SpecializedCategory` table and relation to `Vocabulary`.
- Refactored `VocabularyService` with database seeding, and added endpoints to CRUD categories in `VocabularyController`.
- Implemented `generateAndInsertSpecializedVocabulary` in `AIService` and exposed AI generation endpoints in `AIController`.
- Refactored React Web Admin with dynamic categories loader, Add/Delete categories forms, and direct AI generation popup.
- Updated Flutter mobile API client `api_client.dart` with categories CRUD and AI generation methods.
- Refactored `specialized_vocab_screen.dart` and `admin_specialized_vocab_screen.dart` to fetch categories dynamically from the API and support custom categories deletion, addition, and Direct AI Generation trigger.
- Refactored Gen AI generation popup on both React Web Admin and Flutter Mobile Admin to fetch and list available AI Models dynamically based on the selected AI Provider.
- Verified compilation and build checks (`npx tsc --noEmit` and `flutter analyze` both compile successfully with 0 errors).
- Root AGENTS.md remains in place to enforce CONTEXT.md maintenance.