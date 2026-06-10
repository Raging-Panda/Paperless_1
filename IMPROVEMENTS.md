# Future Improvements

Possible enhancements grouped by area. Items within each section are roughly ordered by impact.

---

## Architecture

- **Split `main.dart` into separate files** — the single file is ~2 700 lines; split into `models/`, `db/`, `repositories/`, `screens/`, and `widgets/` packages for maintainability
- **Introduce state management** — replace ad-hoc `setState` with Riverpod, Provider, or Bloc so state (receipt list, settings, auth) is shared without prop-drilling and screens rebuild only when necessary
- **Repository interface + dependency injection** — abstract `ReceiptRepository` behind an interface so it can be swapped with a mock in tests
- **Separate `AppSettings` persistence from Firestore settings** — device-local prefs (currency symbol) belong in `shared_preferences`; user-scoped preferences that should sync across devices (future notification settings, theme) belong in Firestore under `/users/{uid}/prefs`

---

## Testing

- **Unit tests for `Receipt` model** — `toMap` / `fromMap` / `toFirestore` / `fromFirestore` round-trips
- **Unit tests for `ReceiptRepository`** — mock Firestore and SQLite, verify write-through and cache invalidation logic
- **Widget tests for key screens** — `ReceiptListScreen` (empty state, search, filter), `AddReceiptScreen` (validation), `ProfileScreen` (initials logic)
- **Integration / golden tests** — screenshot-based regression for the main user flows

---

## Features

- **Receipt categories / tags** — let users tag receipts (Food, Travel, Office…) and filter by category; store as an array field in Firestore
- **Spending analytics** — monthly totals, per-category breakdown, and a simple chart (e.g. `fl_chart`) on a dedicated Analytics screen
- **Export receipts** — CSV or PDF export of the receipt list, sharable via the system share sheet (`share_plus`)
- **Receipt photo attachment** — attach a camera or gallery image to a receipt; store in Firebase Storage, reference URL in the Firestore document
- **OCR for physical receipts** — use `google_mlkit_text_recognition` to extract merchant, amount, and date from a camera photo automatically
- **Recurring receipts** — mark a receipt as recurring (weekly / monthly) and auto-create future entries
- **Budget tracking** — set a monthly spending limit per category; show progress and alert when approaching the limit
- **Pull-to-refresh** — add a `RefreshIndicator` to `ReceiptListScreen` to manually trigger a Firestore sync
- **Bulk actions** — long-press to enter multi-select mode; bulk delete or bulk export selected receipts
- **Receipt sorting** — let users choose the sort order (date ↓ / date ↑ / amount ↓ / amount ↑ / merchant A–Z) in addition to the existing date filter

---

## UX & Polish

- **Onboarding flow** — brief walkthrough screens on first launch explaining scanning, history, and cloud sync
- **Theme toggle** — add a Light / Dark / System option to Settings; currently the app is dark-only
- **Offline indicator** — show a subtle banner when the device has no connectivity so users know syncing is paused
- **Haptic feedback** — short haptic on successful scan confirmation and on swipe-to-delete
- **Animated transitions** — hero animation on the receipt amount when navigating from list → detail
- **Receipt list grouping** — group receipts by month with sticky section headers instead of a flat date-sorted list
- **Empty search illustration** — replace the plain icon + text with a small illustration for a more polished empty state

---

## Security & Reliability

- **Firestore security rules** — lock all documents to `request.auth.uid == userId`; add field-level validation (amount is a number, date is a string, etc.)
- **Input sanitisation** — trim and length-cap all user-provided strings before writing to Firestore to prevent oversized documents
- **Biometric / PIN lock** — optional app-level lock using `local_auth` for users who want extra privacy
- **Token refresh error handling** — detect `FirebaseAuthException` with code `token-expired` across all Firestore calls and prompt re-authentication gracefully
- **Retry with exponential back-off** — replace the single manual Retry snackbar with automatic back-off retries for transient network errors

---

## Production Readiness

- **Firebase Crashlytics** — add `firebase_crashlytics` to capture unhandled exceptions and Flutter errors in production
- **Firebase Analytics** — track key events (receipt scanned, receipt saved, receipt deleted) to understand usage patterns
- **App versioning** — read the real version from `package_info_plus` in the Settings About section instead of the hardcoded string
- **Firestore indexes** — add composite indexes for queries that combine `orderBy('createdAt')` with future `where` clauses (category, date range) to avoid query failures at scale
- **SQLite migration strategy** — formalise the `onUpgrade` approach with a migration runner so future schema changes are applied cleanly across all existing installs
- **CI/CD pipeline** — GitHub Actions workflow to run `flutter analyze`, `flutter test`, and `flutter build apk` on every pull request
