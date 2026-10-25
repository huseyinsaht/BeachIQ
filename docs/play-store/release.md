# Release signing and Play Store build

## One-time: create the upload keystore (keep it private, back it up)
```
keytool -genkeypair -v -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 \
  -keystore beachiq-upload.jks -alias beachiq
```
Never commit the `.jks` or its passwords. If you lose the upload key you can reset it through
Play Console, but back it up anyway. Enrol in **Play App Signing** when creating the app (default);
the key above is only the *upload* key.

## Local release build
Create `android/key.properties` (git-ignored):
```
storeFile=C:/path/to/beachiq-upload.jks
storePassword=...
keyAlias=beachiq
keyPassword=...
```
then `flutter build appbundle --release`. Without `key.properties` the release build is signed with
the debug key and **cannot be uploaded** to Play.

## CI build (preferred)
Add four repository secrets: `BEACHIQ_KEYSTORE_BASE64` (`base64 -w0 beachiq-upload.jks`),
`BEACHIQ_KEYSTORE_PASSWORD`, `BEACHIQ_KEY_ALIAS`, `BEACHIQ_KEY_PASSWORD`. Then run Actions →
"Build Play Store bundle". The workflow fails fast if a secret is missing or the bundle ends up
debug-signed, and uploads `app-release.aab` as the artifact `beachiq-release-aab`.

## Version numbers
`pubspec.yaml` `version: 1.0.0+1` → name `1.0.0`, code `1`. Play requires a higher build number
(`+N`) for every upload; bump it in the PR that prepares each upload.

## Application ID
`io.beachiq.beachiq` is permanent once the first bundle is uploaded.
