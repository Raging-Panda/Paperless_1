# Paperless App - Conversation Context (for next session)

**Last updated:** 2026-06-04

## Current App State
- App renamed to **Paperless**
- **Phase 1 [COMPLETE]**: Login screen + navigation to Home
- **Phase 2 [COMPLETE]**: 
  - Home screen with navigation buttons (Profile, Scan, Receipts, Hamburger → Settings)
  - Settings screen
  - Profile screen with form (name, email, payment)
  - **Room DB integration** (User entity, UserDao, PaperlessDatabase)
  - SharedPreferences fallback removed in favor of Room for profile data
- Login screen has gradient background (`login_background.xml`)
- All navigation between screens is functional (Activities + Intents)

## Key Files
- `DEVELOPMENT_PLAN.md` — Main roadmap (Phases 1-6)
- `app/src/main/java/com/example/myapplication/`:
  - MainActivity.kt (Login)
  - HomeActivity.kt
  - ProfileActivity.kt (now uses Room)
  - SettingsActivity.kt
  - User.kt, UserDao.kt, PaperlessDatabase.kt
- Layouts: activity_main.xml, activity_home.xml, activity_profile.xml, activity_settings.xml
- `app/build.gradle.kts` — Room dependencies added

## Next Steps (from plan)
- Phase 3: NFC & QR Integration
- Continue marking sections complete in DEVELOPMENT_PLAN.md as work progresses
- Future: Receipts screen, Scan functionality, dynamic backgrounds from Settings

## Notes for Continuity
- Use `DEVELOPMENT_PLAN.md` as primary tracker
- Link back to this file in future conversations for full context
- Current focus: Keep changes incremental to avoid context overload

**To continue:** Open this file + DEVELOPMENT_PLAN.md together.