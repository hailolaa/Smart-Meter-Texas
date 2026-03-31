# Flutter Play Store V1 Checklist

## 1) Release config and secrets

Use production dart-defines in CI/CD (not hardcoded in source):

- `SMT_BACKEND_BASE_URL=https://api.yourdomain.com`
- `SMT_BACKEND_API_KEY=<public app key>`
- `SMT_ADMIN_USERNAME=` (optional for demo-only)
- `SMT_ADMIN_PASSWORD=` (optional for demo-only)

Recommended command:

```bash
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/symbols \
  --dart-define=SMT_BACKEND_BASE_URL=https://api.yourdomain.com \
  --dart-define=SMT_BACKEND_API_KEY=your_public_key
```

## 2) Android signing

- Create/upload keystore securely
- Configure `android/key.properties` (local/CI secret store)
- Verify release signing in `android/app/build.gradle*`
- Keep keystore backups offline

## 3) App quality gates

Run before release:

```bash
flutter pub get
flutter analyze
flutter test
```

Manual checks:

- Login/logout (normal + admin role)
- Onboarding flow
- Energy dashboard + usage charts
- Alerts read/unread behavior
- Network failure states and retry UX

## 4) Performance checks

- Build profile APK and test on a real low/mid-range Android device
- Verify first launch time and chart loading
- Check memory/CPU spikes during live refresh and chart tabs
- Confirm no repeated 429s under normal usage

## 5) Store listing and policy readiness

- Privacy Policy URL live and accurate
- Data safety form completed
- App content rating completed
- Screenshots, feature graphic, and short/full descriptions ready
- Support email + contact URL set

## 6) Release strategy

- Upload AAB to Internal Testing first
- Validate crash-free and login/backend stability
- Promote to Closed Testing, then Production staged rollout (10% -> 50% -> 100%)

## 7) Post-release monitoring

- Watch Play Console ANRs/crashes
- Monitor backend error rates (401/403/429/500)
- Keep rollback plan ready (previous AAB + backend release)

