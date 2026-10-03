# Sakina · سكينة

A Flutter companion app for the Quran, prayer, adhkar and everyday Islamic
practice. Material 3, light and dark, Arabic and English, Android-first.

Originally built as a Flutter learning project (as "Islami"), then rebuilt.

## Features

The bottom bar is **Home · Quran · Prayer · Adhkar · More**.

| Tab | What it does |
| --- | --- |
| **Home** | Greeting with today's Hijri and Gregorian dates, the next prayer with a live countdown, all five prayer times at a glance, a **Ramadan card** (Imsak, Iftar, countdown to Iftar) during Ramadan, reminders for the Monday/Thursday and White Days fasts, *continue reading*, a quick-access grid, a **verse of the day** and **hadith of the day**, and a countdown to the next Islamic occasion. |
| **Quran** | All 114 suras plus Juz and hizb-quarter indexes, bookmarks, and **full-text search** in Arabic (diacritics-insensitive) and English. A sura opens as a **mushaf** turned page by page, right to left. Pages are filled like a printed copy, so a verse can run across a page break. Each page shows its juz and hizb. Your page is remembered. Tap a verse for **tafsir** (Al-Muyassar, Al-Jalalayn), the English translation, bookmarking, copying, or **sharing as an image**. Recitation by 12 reciters plays verse by verse, highlights the verse being recited, and can repeat a verse or the sura. Sajda verses are marked. |
| **Prayer** | Prayer times for your location or a city you pick: 12 calculation methods, Shafi'i/Hanafi Asr, high-latitude rules and per-prayer minute adjustments. Day-by-day browsing, a monthly timetable, a **Qibla compass**, a **prayer tracker** with a streak, and adhkar shortcuts. |
| **Adhkar** | The full **Hisn al-Muslim** (132 chapters, 267 adhkar) with counters, plus the **tasbeh**: a progress ring to 33, three dhikr, rounds, undo, haptics and a confirmed reset. |
| **More** | Hadeth (search and favourites), Duas from the Quran (Rabbana and the prophets' supplications), the **99 Names of Allah**, **Quran radio** (10 live stations), the **Islamic calendar** with occasions and White Days, Qibla, prayer tracker, a **Zakat calculator**, Settings, About and Share. |

**Notifications** (off by default): an adhan-time alert for each prayer you
choose, an optional reminder N minutes before, and an optional Friday reminder
to read Al-Kahf.

**Settings**: language, theme (light, dark or follow the phone), Quran text size,
reciter, calculation method, madhab, high-latitude rule, prayer adjustments,
Hijri date adjustment (±2 days), and notifications.

**Arabic and English.** The app follows the phone's language, and you can
override it in Settings. In Arabic the whole UI mirrors to right-to-left, with
Arabic month names, dates and digits.

Reading a sura, a hadeth or the adhkar keeps the bottom tabs visible. A
**now-playing bar** sits above them whenever recitation or radio is playing, so
audio never runs where you can't see it.

## Running it

```bash
flutter pub get
flutter run
```

Requires Flutter 3.44+ / Dart 3.8+. Verified on Android (Samsung SM A528B). The
iOS and desktop configuration is written but **has not been built or tested**,
because the development machine has no Xcode.

```bash
flutter test      # 172 tests
flutter analyze   # clean
```

`test/new_screens_smoke_test.dart` lays out Home, More, Zakat and Settings at
the target phone's size and 1.1 font scale, in both languages and both themes,
so any overflow fails the test.

## Religious content

Every text is generated from a published source by one script. Nothing is
typed by hand:

```bash
python3 tool/build_content_assets.py   # downloads into .content_cache/, writes assets/
```

| Content | Source |
| --- | --- |
| Quran text | Tanzil Uthmani (via api.alquran.cloud), with the basmala split from verse 1 |
| Search text | Tanzil simple-clean, so `الرحمن` finds `ٱلرَّحْمَٰن` |
| Translation | Saheeh International |
| Juz, hizb, sajda | Tanzil metadata |
| Adhkar | Hisn al-Muslim (hisnmuslim.com) |
| 99 Names | api.aladhan.com |
| Tafsir | Al-Muyassar and Al-Jalalayn, fetched on demand and cached |
| Recitation | everyayah.com, streamed per verse |
| Quran font | Amiri Quran (SIL OFL, `assets/fonts/OFL-AmiriQuran.txt`) |

The script asserts the corpus shape before writing: 6,236 verses, 112 basmala
prefixes removed, 30 juz, 240 hizb quarters and 15 sajdas.
`test/quran_assets_integrity_test.dart` checks every sura's verse count
against the metadata. `QuranService` also checks it at runtime in debug builds.
The Quranic duas and the verses of the day are stored only as references.
Their tests check that each reference really says what it was chosen for.

The 50 ahadeth are the original project's files and have not been checked
against a source.

## Brand artwork

The launcher icon, adaptive icon and native splash images are generated from
Dart, because this machine has no image tooling:

```bash
flutter test tool/generate_brand_assets_test.dart   # writes assets/brand/*.png
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

`SakinaMark` in `lib/core/widgets/sakina_mark.dart` is the single definition of
the mark. The icon, the native splash and the in-app splash all paint it, which
is what makes the native-to-Dart handoff seamless. After regenerating the native
splash, check that `NormalTheme`'s `android:windowBackground` in all four
`values*/styles.xml` files is the brand colour and not `?android:colorBackground`.
The generator resets it, and that window is what flashes white otherwise.

## Architecture

```
lib/
  core/
    constants/   asset paths, sura table, reciters, Quranic duas, daily verses, prefs keys
    services/    quran, search, tafsir, prayer times, notifications, calendar,
                 azkar, hadeth, zakat, recent suras, local storage
    state/       cubits: settings, radio, quran player, bookmarks; now-playing derivation
    theme/       Material 3 light/dark, design tokens
    utils/       Arabic text normalisation, prayer labels, l10n helpers
    widgets/     page shell, brand mark, empty/error states
  models/        plain data classes
  l10n/          app_en.arb, app_ar.arb (generated output in l10n/gen, gitignored)
  modules/       splash, onboarding, home, layout (the tabs), more, settings
```

Each tab owns its own `Navigator` (`lib/modules/layout/tab_navigator.dart`),
which keeps the bottom bar visible while a detail page is open. The layout
exposes `LayoutScope` so any screen can switch tabs or open a sura in the Quran
tab. A single `PopScope` at the layout level routes the system back button,
because `IndexedStack` keeps hidden tabs mounted and per-tab handlers would
fight. Back steps out of the current page, then returns to Home, then exits.
Tabs are built the first time they are opened.

State is held in `flutter_bloc` Cubits. Anything that touches the asset bundle,
the network or the device sits behind a service in `core/services`, so it can be
unit tested without a widget tree. There is deliberately **no**
entity/usecase/repository layering. The app has no backend, so those layers
would only add boilerplate.

## Mushaf pages

No page-mapping data is bundled, so pages are **measured**, not looked up.
`MushafPaginator` lays the sura out with a `TextPainter` and breaks pages at the
word level, filling each page the way a printed mushaf does. The page count
depends on the screen and the text size. That is why the saved position is a
word, not a page number: it survives a change of text size.

## Prayer notifications

Notifications are off by default. Turning them on in Settings is what asks for
the notification permission. Each alert for the next 14 days is scheduled
individually, because prayer times drift by about a minute a day and a repeating
notification would slowly go wrong.

The schedule is rebuilt on every launch and whenever a prayer setting, the
language or the location changes, so it keeps rolling forward. **If the app is
not opened for 14 days, notifications stop.** Scheduling at startup uses the
last cached location, so it never triggers a location prompt.

Android 14 does not grant exact alarms by default. The app asks, and if refused
it falls back to inexact alarms, which may arrive a few minutes late. Samsung's
battery optimisation can also delay alarms for apps it considers idle.

## Permissions

- **Internet**: radio, recitation and tafsir.
- **Notifications**, **exact alarms** and **boot completed**: prayer
  notifications, only if turned on. Boot and app-update receivers restore the
  schedule.
- **Location** (coarse or fine): prayer times and Qibla. This is optional. If
  it is denied, you can pick a city, and otherwise the app falls back to Cairo
  and says so.
- **Vibrate**: tasbeh haptics.

## Packages

`flutter_bloc`, `flutter_localizations`, `intl`, `shared_preferences`,
`just_audio`, `audio_session`, `adhan`, `hijri`, `geolocator`, `geocoding`,
`flutter_compass`, `flutter_local_notifications`, `timezone`, `flutter_timezone`,
`http`, `path_provider`, `share_plus`, `package_info_plus`. Dev:
`flutter_launcher_icons`, `flutter_native_splash`.

`intl` is pinned to `^0.20.2` rather than `^0.20.3` because
`flutter_localizations` requires exactly `0.20.2`.
