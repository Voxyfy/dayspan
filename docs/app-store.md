# App Store listing

Texts to paste into App Store Connect. Character limits are Apple's; the
number in brackets is the current length.

## Name and subtitle

**Name** (max 30) — 22
```
Dayspan: Today, Sorted
```

The Home Screen shows `CFBundleDisplayName`, which is plain **Dayspan**. The
store name carries a descriptive tail because the plain name "Dayspan" is
already taken on the App Store (rejected at record creation, 5 Sept 2026).

**Subtitle** (max 30) — 29
```
Calendar, tasks, habits. One.
```

## Keywords

Comma-separated, no spaces. Words already in the name and subtitle are
indexed; don't repeat them.

(max 100) — 98
```
planner,daily,agenda,schedule,todo,routine,tracker,streak,focus,productivity,reminder,alarm,widget
```

## Promotional text

The only field editable without a new version. (max 170)
```
Your calendar, your tasks and your habit tiles on one dark screen. Reads the calendars already on your phone. No account, nothing leaves the device.
```

## Description

```
Dayspan is the one screen for the busy person who opens their calendar all day.

It reads the calendars already on your phone (iCloud, Google, Outlook…) and puts today's events next to the two things a calendar cannot hold: the tasks you must get to and the habits you are trying to keep. Open it and the day is already there.

ONE BOARD
Tasks and habits are tiles on the same grid. Tasks are graphite; habits carry colour. Tap the circle to check off, tap the tile to open it. When the last tile is done, the board tells you and celebrates once.

HABIT TILES
Daily or weekly goals, chosen weekdays, in-day counts (8 glasses of water). Each tile shows this week; its page shows six months as a heatmap in the habit's own colour, with your current and best streak.

REMINDERS THAT RING
Any task or habit can nudge you: a notification on time or a few minutes before, or a real alarm that rings even in silent mode (iOS 26). You choose per item. Nothing is scheduled until you turn it on.

MORNING BRIEF
One optional notification at the hour you pick with the day's events, tasks and habits.

HOME SCREEN WIDGET
Today's items at a glance without opening the app.

NO ACCOUNT, NO CLOUD, NO ADS
There is no server. Your calendar is read, never copied. Everything you enter stays on your phone. The source code is open on GitHub.

English and Turkish.
```

## What's new (1.0.0)

```
First release.
```

## Support and privacy links

| Field | Value |
|---|---|
| Support URL | `https://voxyfy.github.io/dayspan/support.html` |
| Marketing URL (optional) | `https://voxyfy.github.io/dayspan/` |
| Privacy policy URL | `https://voxyfy.github.io/dayspan/privacy.html` |

Source in `docs/`: `index.html`, `support.html`, `privacy.html`. GitHub
Pages must be enabled on the repository (`main`, `/docs`) **before**
submission; Apple opens both URLs during review and a 404 is a rejection.

## App Privacy questionnaire

Answer **"No, we do not collect data from this app."** Dayspan makes no
network requests. Calendar access is read-only and the data is not stored,
which does not count as collection under Apple's definition.

## Review notes

```
Dayspan has no account and no server. To see calendar events, grant calendar access when prompted from Settings → Connect calendar (or allow it during onboarding). The "Alarm" reminder option appears only on iOS 26+, where it uses AlarmKit. The Home Screen widget is under the "Dayspan" name in the widget gallery.
```

## Build pitfalls

- With a Watch companion, `flutter build`/`run` need `-d <device>`.
- The Watch target must declare `SUPPORTED_PLATFORMS = watchos watchsimulator`.
  Without it the **archive** (not the simulator build) compiles the Watch
  asset catalog with the iOS SDK and fails with "app icon set named AppIcon
  did not have any applicable content". `ios/add_watch_target.rb` sets it.
- Flutter's archive step caches that failure; after fixing, clear
  `~/Library/Developer/Xcode/DerivedData/Runner-*` before rebuilding.

## Watch screenshot

App Store Connect refuses "Add for Review" without an Apple Watch screenshot
when the binary embeds a Watch app. The frame comes from the paired Watch
simulator (`xcrun simctl io <watch> screenshot`), 416 × 496 for Series 10/11
46mm. The Watch app renders whatever the phone last published; to seed it
without the phone, write the board JSON into the Watch app's defaults:
`xcrun simctl spawn <watch> defaults write com.batuhanhaymana.dayspan.watchkitapp board -string '<json>'`
(the `-string` flag matters, otherwise `defaults` tries to parse it as a plist).
`simctl terminate` may leave the phone app alive after a simulator reboot;
`kill -9 <pid>` from the host works.

## Checklist

- [x] App record created 5 Sept 2026 as "Dayspan: Today, Sorted", SKU `dayspan`, bundle `com.batuhanhaymana.dayspan`, team `4U5QVH3U6A`
- [x] Identifiers registered: app, `.widget`, `.watchkitapp`; App Group `group.com.batuhanhaymana.dayspan` bound to app and widget
- [x] GitHub Pages live; all three URLs return 200 (5 Sept 2026)
- [x] Screenshots rendered: `screenshots/ios-6.9/` (required), `ios-6.7/`, `ios-6.5/`; 6 frames each, alpha flattened
- [x] `flutter test && flutter analyze` clean (48 tests)
- [x] `version: 1.0.0+1` in `pubspec.yaml`; build number must increase on every upload
- [x] `flutter build ipa --release` → `build/ios/ipa/dayspan.ipa` (5 Sept 2026)
- [x] 1.0.0 (1) uploaded via Xcode Organizer, attached to the version (5 Sept 2026)
- [x] Apple Watch screenshot required because the binary carries a Watch app: `screenshots/watch-46mm/01-today.png` (416 × 496, Series 11 46mm simulator)
- [x] Submitted for review 5 Sept 2026, auto-release on approval
- [x] App Privacy published: no data collected; privacy URL set
- [x] Metadata filled: promo text, description, keywords, copyright, review contact + notes, categories Productivity / Lifestyle, price Free in 175 regions, Mac and Vision Pro availability off
- [x] Age rating questionnaire: 4+
- [x] `ITSAppUsesNonExemptEncryption = false` in both Info.plists, so no export-compliance prompt per build
