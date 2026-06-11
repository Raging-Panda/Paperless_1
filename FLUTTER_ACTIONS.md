# Flutter Actions

Tasks that must be run on the build machine. Check off each item as it is completed.

---

## Pending

### Badge artwork (when custom images are ready)

1. Create `assets/badges/` directory in the project root.
2. Add the directory to `pubspec.yaml` under `flutter: assets:`:
   ```yaml
   flutter:
     assets:
       - assets/badges/
   ```
3. Drop in PNG files named exactly:
   - `first_scan.png`
   - `streak_7.png`
   - `streak_30.png`
   - `explorer.png`
   - `loyal_regular.png`
   - `eco_warrior.png`
   - `budget_master.png`
   - `green_giant.png`
4. Run `flutter pub get`.

### Push notifications (streak-at-risk)

To implement the streak-at-risk *push* notification (the in-app card is already live):

1. Add to `pubspec.yaml`:
   ```yaml
   dependencies:
     flutter_local_notifications: ^18.0.0
   ```
2. **Android** — add to `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
   <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
   ```
3. **iOS** — request notification permission in `AppDelegate.swift` or via the plugin's `requestPermissions()` call at app start.
4. Run `flutter pub get`.
5. Implement `NotificationService` that schedules a daily 7 pm notification
   if `GamificationProfile.currentStreak > 0` and `lastScanDate != today`.

---

## Completed

*(none yet)*
