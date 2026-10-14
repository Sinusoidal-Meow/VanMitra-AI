# The universal offline demo APK (no server, no MongoDB, no PC steps)

For presentations. **One APK**, the same for everyone. Install it, open it, sign in with any of the
usual demo logins, and everything works on the phone itself: there is no server, no database and no
setup. If an officer picks up any presenter's phone, all of it is there.

| Login | Phone | PIN | What it is |
|---|---|---|---|
| Villager | 9000000001 | 123456 | village user: files Forms A, B and C, Livelihood (Module 4), the map |
| Villager 2 | 9000000002 | 123456 | a second village user (to show that each person sees only their own claims) |
| Gram Sabha | 9000000003 | 123456 | reviews filed claims; meetings, attendance, quorum, resolutions |
| SDO | 9000000005 | 123456 | reviews claims approved by the Gram Sabha |
| Admin | 9000000004 | 123456 | back-office: creates Gram Sabha and SDO logins |

"Create account" works too: a new village user is created on the phone (phone number and a 6-digit
PIN) and can sign in straight away.

## What each login sees

| Login | Opens on | Sees |
|---|---|---|
| Village user | the dashboard with the hero card | their own claims, "File New Claim" (**Form A, B or C**), Livelihood, the Gram Sabha records, the map |
| Gram Sabha | the same shell, hero card says "Gram Sabha" | a **Gram Sabha review** card with the number of claims waiting for its decision; the Claims tab opens on that queue; it can file Forms B and C (not A); Livelihood |
| SDO | the same shell, hero card says "SDO" | an **SDO review** card with the claims the Gram Sabha approved; the Claims tab opens on that queue; no claim-filing cards, no Livelihood tab |
| Admin | the admin home | back-office |

On a claim waiting for them, the Gram Sabha and the SDO have three buttons: **Approve & forward**,
**Send back** (with remarks) and **Reject** (with reasons).

## What works

The real screens, backed by the same rules as the real server (ported to Dart, tested):

- **Claims, Forms A, B and C**: open a claim, fill the form, save, see what is still missing, submit.
  The Gram Sabha approves, returns (with remarks, and the villager gets 60 days) or rejects; the SDO
  approves, returns or rejects; the claim history shows each step. Evidence, readiness, boundary
  mapping, the acknowledgement and the title draft.
- **Gram Sabha**: meetings, attendance, quorum, resolutions, members, claim calls, the Forest
  Rights Committee, letters, and the tamper-evident ledger check.
- **Livelihood (Module 4)**: report, ideas in full, Ask AI, Schemes (see "Module 4" below).
- **Atlas map**: parcel alerts and boundaries.
- **Language**: English, Hindi, Marathi.

Everything a presenter does stays on that phone and survives closing the app. Each phone has its
own separate copy of the data.

## What is real and what is not (say this out loud)

All data in this build is **Sample** data, never a real person's or a real claim.

**Module 4 (Livelihood).** The report, each idea's detail, the schemes and the answers to the
suggested questions are the **real output of the real rules** for one sample farmer (3 acres, 2 cows,
5 goats, a well and a pump, near 19.7805, 73.2210), made by the Module 4 backend
(`scripts/export_demo_fixtures.py`) and bundled. The rules run on a server, so a phone with no
server **cannot recompute a report**: a user can change their details and save them, but the report
does not change, and a slim strip on every Module 4 screen says so. A person who just registered
starts with no details and sees the village-level report. "Delete my answers" works. Ask AI answers
the suggested questions for real; a typed question is matched to the nearest suggested one, or gets
the grey "not in your report", or the red refusal when it asks for harm. No AI model is involved
(the AI step is off). The 8 schemes are Sample rows.

**Map.** The parcel alerts and boundaries come from the app's own bundled sample data. The
satellite picture underneath comes from the internet, so the phone needs a connection for it;
without one the markers and shapes still show on a plain background.

**Boundary mapping in claims.** Areas and overlaps are computed with plain maths on the phone
(the real server uses a geometry library), accurate for village-sized areas.

## Build it

```bash
cd vanmitra_tem
flutter build apk --release --dart-define=VANMITRA_DEMO=all
```

About five minutes; the file is `build/app/outputs/flutter-apk/app-release.apk` (about 165 MB). A
normal build (no `VANMITRA_DEMO`) is unchanged and talks to a server as before.

Module 4's mock data is regenerated with `python scripts/export_demo_fixtures.py <out.json>` in the
Module 4 repo (`backend/`), then copied to `vanmitra_tem/assets/demo/livelihood_demo.json`.

## Install

Copy the APK to the phone (USB, WhatsApp as a *document*, or a Drive link), uninstall any older
VanMitra, install it (allow installs from that source; Play Protect may warn about an unknown app:
choose install anyway), open it, sign in.

## How it works

`ApiClient` (the one place the app talks to the server) hands every call to `DemoBackend`
(`lib/demo/`) when the demo switch is on. `DemoBackend` is a port of the real backend's routes and
rules to Dart over an in-memory database that is saved on the phone. The sign-in token names the
user, so each login sees what the real server would show it.

To start a phone again from scratch: clear the app's storage in Android settings (or reinstall).
