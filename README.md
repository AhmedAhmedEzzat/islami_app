# Sakina · سكينة

A Flutter companion app for the Quran, prayer, adhkar and everyday Islamic
practice. Material 3, light and dark, Arabic and English, Android-first.

Originally built as a Flutter learning project (as "Islami"), then rebuilt.

## Features

The bottom bar is **Home · Quran · Prayer · Adhkar · More**.

| Tab | What it does |
| --- | --- |
| **Home** | Greeting with today's Hijri and Gregorian dates, the next prayer with a live countdown, all five prayer times at a glance, a **Ramadan card** (Imsak, Iftar, countdown to Iftar) during Ramadan, a **khatma planner** (finish the Quran in 7 to 90 days, with today's pages and progress), a **daily good-deeds checklist** (adhkar, Quran, sunnah prayers, witr, charity, or your own, with a streak), reminders for the Monday/Thursday and White Days fasts, *continue reading*, a quick-access grid, a **verse of the day** and **hadith of the day**, and a countdown to the next Islamic occasion. |
| **Quran** | All 114 suras plus Juz and hizb-quarter indexes, **reading stats** (pages today, this week and the streak), bookmarks, and **full-text search** in Arabic (diacritics-insensitive) and English. The Quran opens as the **printed Madinah mushaf**: all 604 pages, 15 lines each, every page starting and ending on the same word as the print, with the juz and sura at the head, framed sura titles, hizb-quarter marks in the margin and the page number at the foot. Pages turn right to left straight through from one sura to the next, and you can jump to any page. Choose the **paper**: automatic, white, sepia or night. Tap the page to read **full screen**; on a tablet or in landscape it shows **two facing pages** like an open book. For larger text, switch to the **flowing view**, which reflows the sura at any size. Your place is remembered in both. Tap a verse for **tafsir** (Al-Muyassar, Al-Jalalayn), the English translation, bookmarking, copying, **sharing as an image**, a **highlighter** (five colours, shown on the page) and a **personal note**; the Bookmarks tab lists bookmarks and notes and highlights. A **memorisation tracker** (More > Memorisation) marks suras as being learnt or memorised, shows the share of the Quran known by heart, and schedules **spaced revision**: the next day, then after 2, 4, 7, 14 and 30 days while it goes well, and the next day again after a hard one. Recitation by 12 reciters plays verse by verse, highlights the verse being recited, and can repeat a verse or the sura. For **memorising**, each verse can be repeated 2 to 10 times before the next, and a **passage** (from one verse to another) can be looped 2 to 20 times. Recitation **plays on into the next sura** (or stops, as you choose), and a **sleep timer** (15 to 90 minutes, or the end of the sura) stops it and the radio by itself. The **Listen** screen (headphones on the Quran tab, or More) plays any sura with any reciter, carrying on in the now-playing bar. Any sura, or the whole Quran, can be **downloaded per reciter** for offline listening, from there or the player bar; downloaded verses play from the phone, with the same highlighting and page-following. Both tafsirs can be **saved for offline reading** from Settings. Sajda verses are marked. |
| **Prayer** | Prayer times for your location or a city you pick: 12 calculation methods, Shafi'i/Hanafi Asr, high-latitude rules and per-prayer minute adjustments. Day-by-day browsing, a monthly timetable (shareable as text), a **Qibla compass**, a **prayer tracker** with a streak, the last 30 days per prayer and a **qada counter** for missed prayers and fasts to make up, and adhkar shortcuts. |
| **Adhkar** | The full **Hisn al-Muslim** (132 chapters, 267 adhkar) with counters, plus the **tasbeh**: a progress ring, the three classic dhikr and your own, a target of 33, 99, 100 or 1000, rounds, today's total, undo, haptics and a confirmed reset. |
| **More** | **Hadith**: An-Nawawi's Forty with Ibn Rajab's 8 additions, and the **Forty Hadith Qudsi**, in Arabic and English (search and favourites), Duas from the Quran (Rabbana and the prophets' supplications), the **99 Names of Allah** with flashcards and a quiz to learn them (their meanings, or in Arabic their order), **Quran radio** (10 live stations), the **Islamic calendar** with occasions, White Days and a **Hijri ⇄ Gregorian date converter**, Qibla, prayer tracker, a **Zakat calculator**, Listen and download, Settings, Rate, About and Share. |

**First run** ends with a setup page that sets your location and turns on the adhan,
each with its permission prompt.

**Notifications** (off until turned on): an adhan-time alert for each prayer you
choose, an optional reminder N minutes before, and an optional Friday reminder
to read Al-Kahf, and morning and evening **adhkar reminders** half an hour after
Fajr and Asr, a daily khatma reminder after Isha while a khatma is under way, **dhikr reminders** every 2 to 4 hours between sunrise and Isha (never within 15 minutes of a prayer), and **sunnah reminders**:
Jumu'ah an hour before the Friday prayer (on by default), Duha, and Qiyam at the start of the
last third of the night.
Tapping a notification opens its screen; the adhan's opens the dua after the adhan. The prayer alert plays the **adhan** (a separate recording for
Fajr), the phone's usual notification sound, or nothing, as chosen in
Settings. Reminders and the other alerts always use the usual sound.
The adhan notification has a **Stop** button. Settings has **Test the adhan**
and an **Adhan not playing?** checklist, including the battery-saver settings
that stop alarms on Samsung and Xiaomi phones.
Alerts are scheduled two weeks ahead and topped up whenever the app opens and,
on Android, by a background task every 12 hours, so they keep coming even if
the app is not opened.
Fasting reminders, each with its own switch: the evening before Monday and
Thursday, before the White Days and before Arafah and Ashura, and suhoor and
iftar during Ramadan. None is sent before Eid or the days of Tashreeq.

**Home screen widget** (Android): the next prayer with a live countdown and the
day's five prayer times. It keeps working without the app open: the app saves two
weeks of times, and the widget moves on by itself at each prayer.

**Settings**: language, theme (light, dark or follow the phone), Quran text size,
mushaf paper, offline tafsir, reciter,
calculation method, madhab, high-latitude rule, prayer adjustments,
Hijri date adjustment (±2 days), and notifications (adhan sound and muezzin,
reminders, fasting, adhkar, khatma and sunnah alerts).

**Backup** (Android): Settings > Backup saves bookmarks, notes and highlights,
memorisation, the prayer log, missed prayers and fasts, good deeds, khatma,
tasbeeh and settings to one JSON file to share to Drive, email or WhatsApp,
and restores it on a new phone. Downloaded recitations and chosen adhan
recordings belong to the old phone and are left out.

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
flutter test      # 266 tests
flutter analyze   # clean
```

`test/new_screens_smoke_test.dart` lays out Home, More, Zakat, Settings, Listen,
Memorisation and the date converter at the target phone's size and 1.1 font
scale, in both languages and both themes, so any overflow fails the test.

Prayer times and alerts are worked out in the phone's own timezone, so the
prayer tests are written to pass in any of them. CI (`.github/workflows/ci.yml`)
runs `flutter analyze` and the whole suite on every pull request, then the
prayer tests again under Fiji, Apia, New York and Berlin time. To try another:

```bash
TZ=Pacific/Auckland flutter test test/prayer_times_service_test.dart test/prayer_notification_plan_test.dart
```

## Adhan recordings

Two public-domain recordings ship in `android/app/src/main/res/raw/`:

| File | Recording | Licence |
| --- | --- | --- |
| `adhan.ogg` | [Beautiful adhan.ogg](https://commons.wikimedia.org/wiki/File:Beautiful_adhan.ogg) by Adam-synagda, 2:34 | CC0 1.0 |
| `adhan_short.ogg` | [Adhan.ogg](https://commons.wikimedia.org/wiki/File:Adhan.ogg), 0:42, volume raised 8 dB | CC0 1.0 |

Both came from Wikimedia Commons by way of the
[qibla-mobile](https://github.com/rahmanSaaed/qibla-mobile) project, which
bundles the same files with the same credits. Neither has a separate Fajr
version, so Fajr plays the same recording until one is added.

Settings > Muezzin offers these two, and on Android **your own recording**:
any adhan on the phone (an audio file, or a sound already installed), with a
separate one for Fajr if wanted. A picked file is copied into the shared
`Notifications/Sakina` folder through MediaStore (`AdhanSounds.kt`), because a
notification sound has to be a URI the system itself can read; picking a file
needs Android 10 or later, installed sounds work on any version. Each recording
gets its own notification channel; old channels, and the app's own copies of
recordings no longer used, are deleted; and if the file later
disappears the alert falls back to the default adhan.

More can be bundled. Each muezzin is a pair of files (`.ogg` or `.mp3`,
never both for one name): one for Dhuhr, Asr, Maghrib and Isha, and one for
Fajr (the adhan with *as-salatu khayrun min an-nawm*):

| Muezzin | Four prayers | Fajr |
| --- | --- | --- |
| Default | `adhan.ogg` (bundled) | `adhan_fajr.ogg` |
| Short adhan | `adhan_short.ogg` (bundled) | `adhan_short_fajr.ogg` |
| Makkah | `adhan_makkah.mp3` | `adhan_makkah_fajr.mp3` |
| Madinah | `adhan_madinah.mp3` | `adhan_madinah_fajr.mp3` |
| Al-Aqsa | `adhan_aqsa.mp3` | `adhan_aqsa_fajr.mp3` |
| Egypt | `adhan_egypt.mp3` | `adhan_egypt_fajr.mp3` |

Makkah, Madinah, Al-Aqsa and Egypt are defined in `Muezzins.unbundled`
(`lib/core/constants/muezzins.dart`) but hidden until their recording ships:
after adding the file, move the entry into `Muezzins.all`, and a test checks
the file is there. Names must be lowercase letters, digits and underscores
(Android resource rules). A missing Fajr file falls back to the muezzin's own
adhan, then the default adhan, then the usual notification sound, so no alert
is lost.
Use recordings you have the right to distribute.

Android fixes a channel's sound the first time it posts, so after **replacing**
a recording on a phone that already played the old one, uninstall the app (or
clear its data) to hear the new one.

On iOS a notification sound is capped at 30 seconds, so iOS keeps the system
sound.

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
| Mushaf pages and lines | The 1441 AH Madinah mushaf's 604-page, 15-line layout from the [quran-qcf4](https://www.npmjs.com/package/quran-qcf4) package (MIT). Only its line data is used, re-keyed to the Tanzil text; its fonts are not redistributable and are not bundled. |
| Adhkar | Hisn al-Muslim (hisnmuslim.com) |
| 99 Names | api.aladhan.com |
| An-Nawawi's Forty | Arabic and English, fawazahmed0/hadith-api (text from sunnah.com); six source defects fixed by the script, each asserted |
| Forty Hadith Qudsi | Arabic and English, fawazahmed0/hadith-api |
| Tafsir | Al-Muyassar and Al-Jalalayn, fetched on demand and cached, or saved in full from Settings |
| Recitation | everyayah.com, streamed per verse |
| Quran font | Amiri Quran (SIL OFL, `assets/fonts/OFL-AmiriQuran.txt`) |

The script asserts the corpus shape before writing: 6,236 verses, 112 basmala
prefixes removed, 30 juz, 240 hizb quarters and 15 sajdas.
`test/quran_assets_integrity_test.dart` checks every sura's verse count
against the metadata. `QuranService` also checks it at runtime in debug builds.
The Quranic duas and the verses of the day are stored only as references.
Their tests check that each reference really says what it was chosen for.

An-Nawawi's 42 ahadeth are generated from the source above. Ibn Rajab's 8
additions (43–50) are still the original project's files
(`tool/content/ibn_rajab/`), tatweel removed, and have not been checked against
a source; the app says so under each one.

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
    services/    quran, mushaf layout, search, tafsir (and its offline download),
                 prayer times, notifications and their background refresh, home
                 screen widget, calendar, azkar, hadeth, zakat, khatma, hifz,
                 qada, prayer tracker, reading stats, recitation downloads,
                 sleep timer, review prompt, recent suras, local storage
    state/       cubits: settings, radio, quran player, bookmarks, verse notes;
                 now-playing derivation
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
Tabs are built the first time they are opened. Hidden tabs sit under a disabled
`TickerMode`, so their animations stop and `isOnScreen(context)` tells a
listener whether its page is the one in view.

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
language or the location changes, so it keeps rolling forward. On Android a background task also rebuilds it every 12
hours. **On iOS, if the app is not opened for 14 days, notifications stop.** Scheduling at startup uses the
last cached location, so it never triggers a location prompt.

Times come from the `adhan` package, with two corrections in
`PrayerTimesService.entriesOn`. Within about four degrees of the 180th meridian
(Fiji, Tonga, Tuvalu) the package skipped days and sometimes gave Fajr and Isha
as midnight, so there the times are worked out at 170° and moved by four minutes
a degree. Where the clock runs a day ahead of the sun (Samoa and Tonga at
UTC+13, Kiribati at +14) it gave the next day's times, so the date is moved to
match. Everywhere else the package's times are used unchanged.

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
