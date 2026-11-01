# Contributing to Ride Up

Ride Up is built by and for the flying community at Bir. Pilots, developers and designers are all welcome.

## Suggest something

- In the app: **Settings → Feedback**.
- On GitHub: open an issue (templates: bug, idea, from feedback). Security problems go by email instead; see
  [SECURITY.md](SECURITY.md).

## Build something

1. Read [README.md](README.md) and the rules in section 6 of [HANDOVER.md](HANDOVER.md).
2. Fork the repository or ask for access, make a branch, and run the app locally (`python3 -m http.server 8000`).
3. Keep it simple: the app is one file (`index.html`) of plain HTML, CSS and JavaScript. Please don't add a build
   step, bundler or framework without discussing it first.
4. Test on a phone-sized screen (320, 375 and 414 px wide) and with `?bots`. Check the browser console for errors.
5. If you change the database, update `supabase-setup.sql` and say so in the pull request.
6. Open a pull request: say what changed and why, in plain words, with a screenshot if it's visible.

## Style

- **Words:** short, friendly, plain English. *Ride* (shared taxi from the landing), *lift* (a seat in someone's
  car), *trip* (to or from Bir), *number* (WhatsApp number). No jargon in the app.
- **Time:** always Bir time; use `nowMins()`, `todayStr()`, `birDate()` and `clock()`, never the phone's own clock.
- **Code:** match what's around it. Comments explain *why*, briefly.
- **Art:** true to the real place and to scale; anything that moves uses real drawn frames.

## Licence of contributions

Ride Up is licensed under the GNU Affero General Public License v3.0 (see [LICENSE](LICENSE) and [NOTICE](NOTICE)).
By contributing you agree that your contribution is published under the same licence. The original author credit
("Ride Up was originally created by Praval Sharda (2026)") stays in the app.
