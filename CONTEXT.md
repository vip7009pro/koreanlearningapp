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
- Completed Phase 2 task **TOPIK Writing Scaffold (Trợ lý viết TOPIK)**:
  - Designed templates and keywords for TOPIK II Question 53 (chart/graph analysis) and Question 54 (essay/social argument).
  - Implemented `_insertTemplateText` inside `_TopikTakeScreenState` to insert structural Korean expressions directly at the cursor selection point of the active `TextEditingController`.
  - Added a collapsible and tabbed helper UI card `_buildWritingScaffoldHelper` containing three tabs: "Câu 53 (Biểu đồ)", "Câu 54 (Nghị luận)", and "Từ vựng hay".
  - Rendered the helper section above the text field in the TOPIK taking screen `topik_take_screen.dart` when the question type is `ESSAY`.
  - Verified static compilation with `flutter analyze` which completed cleanly with zero warnings or errors on our newly written code.
- Root AGENTS.md remains in place to enforce CONTEXT.md maintenance.