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

## Notifications — flutter_local_notifications Setup

**Must be completed on the build machine before notification features work.**

### 1. Install packages
After the pubspec.yaml dependency additions were made via code, run:
```
flutter pub get
```

### 2. Android — `android/app/src/main/AndroidManifest.xml`

Add inside the `<manifest>` tag, **before** `<application>`:
```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

Add inside the `<application>` tag:
```xml
<receiver
    android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
<receiver
    android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
        <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
        <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
    </intent-filter>
</receiver>
```

### 3. Android — `android/app/build.gradle`
Ensure `minSdkVersion` is **21** or higher:
```gradle
defaultConfig {
    minSdkVersion 21
    ...
}
```

### 4. iOS — `ios/Runner/AppDelegate.swift`
Add `import UserNotifications` at the top.
Inside `application(_:didFinishLaunchingWithOptions:)`, add before `return true`:
```swift
if #available(iOS 10.0, *) {
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
}
```

### 5. iOS — `ios/Runner/Info.plist`
No changes required for basic local notifications.

### Notification channels implemented
| Channel | ID | Purpose |
|---|---|---|
| Streak Reminders | `streak_reminders` | Daily 7 pm reminder if streak > 0 and no scan today |
| Receipt Reminders | `receipt_reminders` | Return window closes in 2 days (fires 28 days after save) |
| Budget Alerts | `budget_alerts` | Immediate alert at 80% and 100% of monthly category budget |
