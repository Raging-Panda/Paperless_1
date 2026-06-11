# AdMob Setup Prerequisites

Steps to complete before ads will display in production. Complete them in order.

---

## 1. Create a Google AdMob account

1. Go to https://admob.google.com
2. Sign in with a Google account
3. Accept the terms and complete account registration

---

## 2. Register the Android app in AdMob

1. In the AdMob dashboard click **Apps → Add app**
2. Select **Android** as the platform
3. Choose **No** when asked if the app is already published (while in development)
4. Enter an app name (e.g. `Paperless`) and click **Add app**
5. Copy the **App ID** shown — it looks like `ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX`

---

## 3. Replace the test App ID in AndroidManifest.xml

Open `android/app/src/main/AndroidManifest.xml` and replace the test value:

```xml
<!-- Replace the value below with your real AdMob App ID -->
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX"/>
```

> The test ID (`ca-app-pub-3940256099942544~3347511713`) is Google's official test
> app ID. It will not generate revenue. You must replace it before going live.

---

## 4. Create ad units

In the AdMob dashboard for your registered app:

### 4a. Banner ad unit

1. Click **Ad units → Add ad unit**
2. Select **Banner**
3. Name it (e.g. `home_banner`) and click **Create ad unit**
4. Copy the **Ad unit ID** — it looks like `ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX`

### 4b. Rewarded ad unit

1. Click **Add ad unit** again
2. Select **Rewarded**
3. Name it (e.g. `challenge_reward`) and click **Create ad unit**
4. Copy the **Ad unit ID**

---

## 5. Replace test ad unit IDs in the code

Open `lib/services/ad_service.dart` and replace both constants:

```dart
static const _bannerAdUnitId   = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
static const _rewardedAdUnitId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
```

> The test unit IDs currently present are Google's official test IDs. Ads will
> render during development but clicks generate no revenue until replaced.

---

## 6. Add secrets for CI/CD (if using GitHub Actions)

If the App ID must not appear in plain text in the repository, pass it through
a GitHub Actions secret and inject it at build time.

Add a repository secret (**GitHub → Settings → Secrets and variables → Actions**):

| Secret name | Value |
|---|---|
| `ADMOB_APP_ID` | Your real AdMob App ID |

Then in your build workflow inject it before the build step:

```yaml
- name: Set AdMob App ID
  run: |
    sed -i "s/ca-app-pub-3940256099942544~3347511713/${{ secrets.ADMOB_APP_ID }}/g" \
      android/app/src/main/AndroidManifest.xml
```

---

## 7. Install Flutter dependencies

From the project root:

```bash
flutter pub get
```

---

## Ad placement reference

| Ad type | Location | Trigger |
|---|---|---|
| Banner | Home screen — bottom bar | Loads on screen open |
| Rewarded | Challenges screen | Shown when user taps "Collect Reward" on a completed challenge |

---

## Verification checklist

- [ ] AdMob account created and app registered
- [ ] Real App ID in `android/app/src/main/AndroidManifest.xml`
- [ ] Real banner ad unit ID in `lib/services/ad_service.dart`
- [ ] Real rewarded ad unit ID in `lib/services/ad_service.dart`
- [ ] `flutter pub get` runs without errors
- [ ] Banner ad appears at the bottom of the home screen
- [ ] Rewarded ad plays when collecting a completed challenge reward
- [ ] AdMob dashboard shows impressions after a test run
