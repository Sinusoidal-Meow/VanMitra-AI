# Put VanMitra online for a demo (one APK, no PC, no adb)

For a meeting where a phone must just work: the server runs on **Railway**, the data stays in
**MongoDB Atlas**, and the APK finds the server by a web address typed once on the sign-in screen.
The phone only needs mobile data or Wi-Fi. No USB, no `adb reverse`, no IP allowlisting per PC.

This needs **internet on the phone**. A fully offline build is a separate piece of work
(Module 4's report would have to be rewritten to run on the phone).

Everything below is done by a person. Claude Code does not deploy, change database network
settings or write to the database.

---

## 1. MongoDB Atlas: let the server in (2 minutes)

Railway's address changes, so for the demo allow every address and remove the rule afterwards.

1. Atlas → your project → **Network Access** → **Add IP Address**
2. **Allow access from anywhere** (`0.0.0.0/0`) → Confirm. Wait until it says Active.

The database password is still required. **Delete this rule after the meeting** (section 7).

## 2. Railway: deploy the server (10 minutes)

1. Railway → **New Project** → **Deploy from GitHub repo** → `Sinusoidal-Meow/VanMitra-AI`,
   branch **main** (once the Module 4 work is merged there; until then use the branch
   `feature/module4-livelihood`, which already has everything below).
2. Open the service → **Settings** → **Config as code** → path: `railway.api.toml`.
   (This builds the **lean** image in `vanmitra_backend/Dockerfile.api`: the API only, no PyTorch.
   The old image tried to load the AI models at start and was killed for running out of memory,
   see `railway/logs.*.log`. The old "Model A" AI endpoints are therefore not part of this
   deployment.)
3. **Variables** (the Variables tab):

   | Name | Value |
   |---|---|
   | `VANMITRA_MONGODB_URI` | the link from `vanmitra_backend/.env` (a secret: paste it, never commit it) |
   | `VANMITRA_MONGODB_DB` | `vanmitra` |
   | `VANMITRA_ENV` | `production` |
   | `VANMITRA_JWT_SECRET` | a new random secret: `python -c "import secrets; print(secrets.token_urlsafe(48))"` |

   Leave everything else at its default. The Module 4 AI stays off.
4. **Settings → Networking → Generate Domain**. That is the server address, for example
   `https://vanmitra-production.up.railway.app`.
5. Wait for the deploy to turn green (about two minutes).

## 3. Check the server (1 minute, from your PC)

```bash
cd vanmitra_backend
./venv/Scripts/python -m scripts.check_deploy https://YOUR-ADDRESS --login 9000000001:123456
```

Every line should say PASS. Each FAIL names its fix:

| It says | Do this |
|---|---|
| no connection | the address is wrong, or the deploy is not finished |
| the database is connected: FAIL | Atlas Network Access (section 1), then wait a minute |
| sign in as 9000000001: FAIL | that demo user is not in this database: `python -m scripts.seed_demo` (writes; you run it) |
| Module 4 data is loaded: FAIL | section 4 |

(Signing in makes the server note the last-login time of that user, as it does for any sign-in.)

## 4. Module 4 data: once (2 minutes)

The Livelihood tab builds its report from data in the database. When this was checked, the five
`lv_*` collections were **empty**, so the tab would have shown nothing.

```bash
cd vanmitra_backend
./venv/Scripts/python -m scripts.setup_module4_demo --check     # read only: what is there now
./venv/Scripts/python -m scripts.setup_module4_demo             # dry run: shows the steps
./venv/Scripts/python -m scripts.setup_module4_demo --apply     # writes: indexes, 16 draft ideas,
                                                                #   8 Sample schemes, the demo village
                                                                #   location, 12 Sample resources
./venv/Scripts/python -m scripts.setup_module4_demo --check     # should say READY
```

Safe to run again; nothing is deleted. Everything it writes is **Sample** data and labelled so in
the app. Do not use a database that holds real users' data for this.

### 4b. Recommended before the meeting: prove the database code on a throwaway database

Module 4's database code has only ever been tested against an in-memory copy. This runs the real
routes over the real MongoDB code in a database that is thrown away afterwards (the name must end
with `_test`, or the script refuses):

```powershell
cd vanmitra_backend
$env:VANMITRA_MONGODB_DB = "vanmitra_smoke_test"
./venv/Scripts/python -m scripts.smoke_mongo --apply      # prints OK for each of ~25 steps
Remove-Item Env:VANMITRA_MONGODB_DB
```

It saves details with the default coordinates, builds a report (the geo search), asks a question
and a harmful one, opens an idea, lists schemes, checks the AI daily limit and deletes everything.
If a line fails, send it to the team before the meeting. Drop `vanmitra_smoke_test` in Atlas
afterwards.

## 5. The phone

1. Uninstall the old VanMitra and the old Module 4 test app.
2. Install the new APK.
3. Open it. On the sign-in screen tap **Server: not set** (it opens by itself the first time),
   type the Railway address, tap **Test** (it must say *Connected*), then **Save**.
4. Sign in: **Villager** chip (`9000000001`, PIN `123456`).
5. **Livelihood** tab → **Add your details** → at the location step choose **Type the
   coordinates** → **Use default coordinates** (19.7805, 73.2210) → **Save**.
6. **Show my report**, **Ask AI**, **Schemes**.

Each person who signs in sees only their own details. The server address is kept on the phone, so
this is done once per install. To point a phone at another server later, tap the Server line again.

## 6. Cost and limits to know about

- Railway bills for running time and memory. A lean API service is small. Check the plan on the
  Railway dashboard before relying on it, and stop the service when the demos are finished.
- Atlas free clusters pause when idle; the first request after a long gap can be slow.
- The server restarts on failure (3 tries). It checks for overdue claims every 60 minutes, as the
  app always did; set `VANMITRA_EXPIRY_CHECK_MINUTES=0` to switch that off for a demo database.

## 7. After the meeting

- Atlas → Network Access → **delete the `0.0.0.0/0` rule**.
- Railway → stop or delete the service, or at least change `VANMITRA_JWT_SECRET` (signs everyone out).
- Nothing in this setup puts a key in the APK. The only server-side secrets are the two variables
  above, which live in Railway.
