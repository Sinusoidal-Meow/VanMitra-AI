# Offline demo APKs (no server, no MongoDB, no PC steps)

For presentations. Each presenter installs **one APK**, signs in on the app's own sign-in screen
(phone and PIN already filled in), and sees **mock data that lives inside the phone**. There is no
server, no database and no setup: install, open, tap Login.

| APK | Presenter | Phone / PIN | Opens on | Shows |
|---|---|---|---|---|
| `VanMitra-samrudhi.apk` | Samrudhi | 9100000001 / 123456 | Livelihood tab | Module 4 (Rozgar) |
| `VanMitra-ayush.apk` | Ayush | 9100000003 / 123456 | Atlas Map tab | the map |
| `VanMitra-sanskriti.apk` | Sanskriti | 9100000002 / 123456 | Claims tab | Module 1 (claims): see "Status" |

The same app and the same code as the normal build. Only the build switch differs
(`--dart-define=VANMITRA_DEMO=<name>`). A normal build ignores all of this.

## How it works

`ApiClient` (the one place the app talks to the server) hands every call to `DemoBackend`
(`lib/demo/`) when the demo switch is on. `DemoBackend` answers from mock data bundled in the APK,
in exactly the shapes the real server sends, so the screens are the real screens. What the
presenter does (details saved, questions asked) is kept in the app's local storage and survives
closing the app. A call the demo does not cover answers 404 and the screen shows its normal
error state; the lists the dashboard asks for on start (claims, meetings, notifications) are empty.

## What is real and what is not (say this out loud in the meeting)

**Module 4 (Samrudhi).** Everything is **Sample** data and labelled so.
- The report, each idea's detail, the schemes and the answers to the suggested questions are the
  **real output of the real rules** for one sample farmer (3 acres, 2 cows, 5 goats, a well and a
  pump, near 19.7805, 73.2210). They were produced by the Module 4 backend
  (`scripts/export_demo_fixtures.py`) and bundled.
- The rules run on a server, so a phone with no server **cannot recompute a report**. Samrudhi can
  open "Add your details", change them and save, but the report does **not** change. Every Module 4
  screen carries a slim strip saying so ("Demo with a sample farmer...").
- "Delete my answers" works: it clears the details and the questions, and the report becomes the
  village-level one (no personal details), also real output.
- **Ask AI:** the suggested questions give the real answers. A typed question is matched to the
  nearest suggested one, or gets the grey "I can only answer questions about your report", or the
  red refusal when it asks for harm (a short word list; anything it does not recognise still gets no
  answer, never a made-up one). No AI model is involved: the AI step is off.
- Schemes are 8 **Sample** rows; 3 link to the national scheme search portal (that needs internet).

**Map (Ayush).** The parcel alerts and boundaries come from the app's own bundled sample data. The
satellite basemap tiles come from the internet (Esri), so the phone needs a connection for the
picture under the markers; without one the markers and shapes still show on a plain background.

**Claims (Sanskriti).** See Status.

## Build the APKs

```bash
cd vanmitra_tem
flutter build apk --release --dart-define=VANMITRA_DEMO=samrudhi    # or sanskriti, ayush, all
```

`all` is a rehearsal build that accepts all three presenters' phones. Each build takes about five
minutes; the file is `build/app/outputs/flutter-apk/app-release.apk` (about 165 MB).

Mock data for Module 4 is regenerated with `python scripts/export_demo_fixtures.py <out.json>`
in the Module 4 repo (`backend/`), then copied to `vanmitra_tem/assets/demo/livelihood_demo.json`.

## Install

Copy the APK to the phone, uninstall any older VanMitra, install (allow installs from this
source; Play Protect may warn about an unknown app, choose install anyway), open, **Login**.

## Status

- Sign-in, the Livelihood tab, Ask AI, Schemes, idea detail: built and tested against the app's
  real models (14 tests); not yet tried on a phone.
- Map: opens with the other tabs; checked by reading the code (it uses the app's own offline seed),
  not yet tried on a phone.
- Claims: the Claims tab shows "no claims yet" in the demo. A real claims demo means reproducing
  the claims rules (Forms A, B, C, completeness, the submit / return / approve path, evidence) inside
  the app: about 1,800 lines of backend logic. Decide what Sanskriti will show (read-only prepared
  claims is quick; filling forms and submitting is the big one).
