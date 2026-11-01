# Ride Up

**Share a taxi from the Bir landing ground up to take-off.**
A free community web app for paragliding pilots at Bir-Billing, Himachal Pradesh, India.

Live at **https://rideup.pages.dev**

- **Now:** start a ride or hop into one; seats fill live on everyone's phone. Offer a lift in your own car.
- **Plan:** say when you're heading up to fly in the next days, and see who else is.
- **Plan your travel:** find company for trips to and from Bir.
- **Weather:** launch and landing, the next hours, and "is the landing visible from take-off?".
- **Getting around Bir:** a map of key places, medical, ATMs, groceries and hostels.
- **Safety & contacts:** emergency and rescue numbers.

No sign-up, no ads, no tracking. Phone numbers are shared only inside a ride and wiped when it's over.

## How it's built

Ride Up is deliberately simple, so anyone can look after it:

| Part | What it is |
|---|---|
| `index.html` | The whole app: one file of plain HTML, CSS and JavaScript. No build step, no framework. |
| `art/` | The paintings, sprites and icons the app shows. |
| `supabase-setup.sql` | The complete database (tables, rules, functions). Run it once on a new Supabase project. |
| `functions/`, `lib/` | Two tiny Cloudflare Pages Functions that make the WhatsApp link previews for shared rides and plans. |
| `_headers` | Security rules Cloudflare sends with every page. |
| `.github/` | Issue templates and the job that keeps the free database awake. |

Hosting is **Cloudflare Pages** (it deploys `main` automatically) and the database is **Supabase** (free plan).

## Run it on your computer

```bash
python3 -m http.server 8000
```

Then open http://localhost:8000. Useful additions to the address:

- `?bots`: pretend rides that exist only on your phone, to try everything safely.
- `?t=1730`: show the scenery at 5:30 pm (any time, Bir time).
- `?full`: on a laptop, show the app full width instead of inside a phone frame.

The app always runs on **Bir time** (India, UTC+5:30), wherever it is opened.

## Looking after Ride Up

- [HANDOVER.md](HANDOVER.md): who owns what, how changes go live, how to take over or step back.
- [MAINTENANCE.md](MAINTENANCE.md): the weekly check and reading error reports.
- [RELEASE.md](RELEASE.md): the step-by-step procedure for every new version.
- [SECURITY.md](SECURITY.md): how the app protects people's data, and how to report a problem.
- [SCENE.md](SCENE.md): the scene rulebook: every living thing in the painted view, its life and its rules.
- [CONTRIBUTING.md](CONTRIBUTING.md): how to suggest or build something.

## Licence and credit

Ride Up is free software under the **GNU Affero General Public License v3.0**. See [LICENSE](LICENSE) and
[NOTICE](NOTICE).

**Ride Up was originally created by Praval Sharda (2026).** This credit must stay visible in the app in every copy
and changed version.
