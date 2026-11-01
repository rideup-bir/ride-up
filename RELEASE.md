# Releasing a new version of Ride Up

Follow this every time a version people will notice goes live (1.1, 1.2 …). Small fixes (1.0.1, 1.0.2 …) can go
live any time, but still do steps 4, 7 and 8. Tick each step; don't skip ahead. If a step finds a problem, fix it
and start that step again.

## 1. Decide the version

- **Number:** 1.1, 1.2 … for a release people see; 1.0.1, 1.0.2 … for small fixes; 2.0 only for a big change in
  how people use Ride Up.
- **Kind:** a normal release, or a test release with the "(beta)" label (`RELEASE_KIND = "beta"`).
- Write down in one or two lines what this version is for. Everything in the list below is checked against it.

## 2. Words people will read

In `index.html`:

- `APP_VERSION` (e.g. `"1.1"`), `RELEASE_KIND` (`""` or `"beta"`), `STAGE` (which round usage counts belong to).
- `RELEASE_DATE` (Bir time, e.g. `"1 November 2026"`) and `RELEASE_NOTES` (the points in Settings → version line;
  short, plain words, newest things first).

In the repo:

- A new entry at the top of `version-history.txt`: the number, the date and time (Bir time), and every change in
  plain words.

## 3. The database (only if it changed)

1. Update `supabase-setup.sql` (it is the whole truth: it must build a fresh database on its own).
2. Test it on a throwaway local Postgres first (see HANDOVER.md: the `pgserver` test). Every check must pass.
3. Back up the live data you'd mind losing (Supabase → Table Editor → export), then run the change on the live
   project. Run the Supabase **security advisor** afterwards and read every warning.
4. Check: each function exists once, anyone-can-run functions are only the app's own, private tables stay private.

## 4. Check every flow (two phones)

Use two phones (or two browsers: `localhost` and `127.0.0.1` keep separate saved details). Note anything odd.

| | Flow | What to check |
|---|---|---|
| A | First open | welcome screen, name saved, "Just looking" works |
| B | Start a ride | taxi and car choice, seats, friends, note; it shows on the other phone within seconds |
| C | Join / leave | join from phone 2, seat dots fill, WhatsApp buttons, leave, cancel, the last one out ends the ride |
| D | Driving off | "We've driven off", the ride moves to "Left in the last 30 min", "I didn't go" |
| E | Offer a lift | car details, pick-up, number shared only with the joiner |
| F | Plan | add a plan, it shows for others, share to WhatsApp opens the right day link, remove |
| G | Plan your travel | calendar, When (calendar + time), How, More options; join from phone 2, numbers swap, remove |
| H | Weather | both places, hours, Sightline picture, the forecast note + Windy link, Report (needs your details) |
| I | Map, Safety | map opens on the landing, categories, Google Maps link; call buttons dial |
| J | Settings | profile, number switch, car, Display & units, Add to Home Screen, About / Terms & Privacy / Credits |
| K | Feedback | the chat (choices, typing, close), a test message reaches the `feedback` table |
| L | Links | a shared ride link and plan link open the right place, with the small preview in WhatsApp |
| M | Scenery | banner and full screen at several times (`?t=0700`, `?t=1300`, `?t=1900`, `?t=2200`), no stutter |

Then remove the test rides, plans and reports you made (or wipe them in Supabase if it's before a launch).

## 5. Look at every screen size

- Phones 320, 375 and 414 px wide, a phone on its side, and a laptop (the phone frame).
- Light and dark mode. Bot rides (`?bots`) on and off.
- Nothing cut off, nothing overlapping, no sideways scrolling, pop-ups fit with their buttons in view.

## 6. Check the promises are still true

Read these pages in the app and compare them with what the code and database really do now:

- **Privacy notes:** what is kept, for how long, who sees a number, what is anonymous, what is wiped and when.
- **Terms of use and Community Code:** still match how the app works.
- **Licences & Credits and `NOTICE`:** every map, data source, font, script and AI art tool used is named with its
  licence; the author credit is there.
- **Security (`SECURITY.md`, `_headers`):** every outside service the app talks to is listed in the
  Content-Security-Policy and nothing more; scripts are pinned with integrity fingerprints; no secret keys anywhere
  in the repo (`git grep -i -E "service_role|secret|password|token"` finds only the public key and code words);
  rate limits in the database still fit; the Supabase security advisor is clean or every point is understood.

## 7. Publish

1. Commit with a clear message, push, and let the person who owns the repo review if there is a second maintainer.
2. Merge to `main`; tag the release (`git tag v1.1 && git push --tags`).
3. Cloudflare Pages builds by itself in about a minute. Check it went out:
   `curl -s https://rideup.pages.dev/ | grep APP_VERSION`
4. Open https://rideup.pages.dev on a real phone: no errors, the version line shows the new number.
5. Send yourself the link on WhatsApp: the preview picture and words look right.

## 8. After the release

- For the first day, look at `usage_events` for `js_error` and `flow_fail` (see MAINTENANCE.md, "Reading error
  reports") and fix anything new as a small-fix version.
- Share the news (the message goes with the link; keep it short).
- Note in the weekly check that the release went out and anything to watch.
