# Google Play listing — BeachIQ v1 (free)

Ready-to-paste content for Play Console. Graphics: `docs/assets/play-store/` (icon 512x512,
feature graphic 1024x500). Phone screenshots: Play Console needs 2-8; take them from the app
(see "Screenshots" below). Privacy policy URL:
`https://github.com/huseyinsaht/BeachIQ/blob/main/docs/privacy-policy.md`

## Store listing (English, default)
- **App name** (max 30): `BeachIQ: Swim Conditions`
- **Short description** (max 80): `Waves, wind, water temp & depth — know if it's good to swim today.`
- **Full description** (max 4000):

> Know before you go. BeachIQ tells you whether today is a good day for the water — at a glance.
>
> • One-look verdict for swimming, with a clear reason and safety hints
> • Wave height, wave period, wind, water and air temperature, UV and more
> • Hourly and multi-day forecast, with an alert when conditions turn favorable
> • Nearby beaches on a map, with toilets, showers, cafes and parking
> • Approximate water depth near the shore
> • Compare beaches side by side
> • No account, no ads, no tracking
>
> Data comes from open services (Open-Meteo, OpenStreetMap, EMODnet Bathymetry).
> BeachIQ gives estimates, not a guarantee of safety: always follow local lifeguard flags.

- **App category:** Weather. **Tags:** weather, travel/outdoors.
- **Contact email:** (Play Console requires one — yours)
- **Contact website:** https://github.com/huseyinsaht/BeachIQ

## Turkish (optional second language)
- **Name:** `BeachIQ: Yüzme Koşulları`
- **Short:** `Dalga, rüzgar, su sıcaklığı ve derinlik — bugün denize girilir mi?`

## App content declarations
- **Ads:** No. **Account required:** No. **In-app purchases:** No (v1 is free; Pro tier #269/#272 is deferred).
- **Target audience:** 13+ (not directed at children). **News app / government / health:** No.
- **Content rating questionnaire:** no violence, sexual content, gambling, user-generated content or
  shared location with other users → expect "Everyone". Category: Utility/Weather.
- **Data safety form** (answers match `docs/privacy-policy.md`):
  - Collects or shares data? **Yes** (approximate location is sent to third-party data services to
    fetch conditions; the app has no server of its own).
  - **Approximate location**: collected, optional, used for app functionality only; shared with
    service providers (Open-Meteo, Overpass, EMODnet) as a necessary part of the feature; not used
    for ads or analytics. Not stored on a BeachIQ server.
  - Personal info, financial info, health, messages, photos, contacts, app activity, device IDs:
    **not collected**.
  - Data encrypted in transit: **Yes** (all HTTPS). Users can request deletion: **N/A, no account**
    (local data is removed by uninstalling or clearing app data).
- **Permissions to justify:** `ACCESS_COARSE_LOCATION` (opt-in "Use my location"),
  `POST_NOTIFICATIONS` (favorable-conditions alert), `INTERNET`.
- **Background work:** the Android alert check runs periodically via WorkManager; no foreground
  service and no background location.

## Screenshots
2-8 phone screenshots, 16:9 or 9:16, min 320 px, max 3840 px. Suggested set: Home (verdict + 3x3
grid), map with beaches, a beach detail chart, Forecast, Compare beaches, Search. The daily CI
screenshot (`daily-screenshots` branch) is a web render and fine for drafts; take final ones on a
phone or the Android emulator.

## Release steps (once the Play Console account is verified)
1. Create the app in Play Console (name above, free, default language English).
2. Generate the upload keystore (see "Signing" in `docs/play-store/release.md`) and add the four
   `BEACHIQ_*` repository secrets.
3. Actions → "Build Play Store bundle" → download `beachiq-release-aab`.
4. Upload it to an Internal/Closed testing track; fill the declarations above; start the closed
   test (new personal accounts need 12+ testers for 14 days before production).
