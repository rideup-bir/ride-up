# Releasing a new version of Ride Up

Follow this every time a version people will notice goes live (1.1, 1.2 …). Small fixes (1.0.1, 1.0.2 …) can go
live any time, but still do steps 4, 5, 8 and 9 (the two bug checks are never skipped). Tick each step; don't skip ahead. If a step finds a problem, fix it
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

## 4. Bug check and fix: the app (its own task)

Goal: every flow works, nothing breaks, nothing hangs. Fix what you find, then run this step again from the top.

**4a. Read the error reports first.** In Supabase, `usage_events` since the last release: every `js_error` and
`flow_fail` (MAINTENANCE.md, "Reading error reports"; step IDs in docs/flow-map.md). Each new one is either fixed
in this version or written down with the reason it isn't.

**4b. Check every flow (two phones).** Use two phones (or two browsers: `localhost` and `127.0.0.1` keep separate
saved details). Note anything odd.

| | Flow | What to check |
|---|---|---|
| A | First open | welcome screen, name saved, "Just looking" works |
| B | Start a ride | taxi and car choice, seats, friends, note; it shows on the other phone within seconds |
| C | Join / leave | join from phone 2, seat dots fill, WhatsApp buttons, leave, cancel, the last one out ends the ride |
| D | Driving off | "We've driven off", the ride moves to "Left in the last 30 min", "I didn't go" |
| E | Offer a lift | car details, pick-up, number shared only with the joiner |
| F | Plan | add a plan, it shows for others, share to WhatsApp opens the right day link, remove |
| G | Plan your travel | calendar, When (calendar + time), How (all three), More options: every row, its menu, "Type…" + Save, "Share my car details"; save; join from phone 2, numbers swap, remove |
| H | Weather | both places, hours, Sightline picture, the forecast note + Windy link, Report (needs your details) |
| I | Map, Safety | map opens on the landing, categories, zoom buttons and slider to the closest zoom (pictures, no "Map data not yet available"), Map / Satellite, Google Maps link; call buttons dial |
| J | Settings | profile, number switch, car, Display & units, Add to Home Screen, Help & Guide (search, contents, every link into it), About / Terms & Privacy / Credits |
| K | Feedback | the chat (choices, typing, close), a test message reaches the `feedback` table |
| L | Links | a shared ride link and plan link open the right place, with the small preview in WhatsApp |

**4c. The hard cases.** These broke before; check them every time:

- **No signal:** turn on flight mode, try to save a ride, a plan and a travel plan: within 20 s a clear "No signal"
  message, nothing half-saved; turn it off, save again: it works once.
- **Back from the background:** leave the app for 5 minutes, come back: rides update, the painting isn't stuck or
  piled up, buttons respond.
- **Home Screen app on an iPhone:** the top of every page is sharp (no blur under the clock), pull to refresh works
  (the page slides down, the arrow stays put, "Release to refresh" under it).
- **Turning the phone:** only the full-screen painting and Help & Guide work sideways; every other screen asks to
  turn the phone back (or opens the painting, from the home page). Turn it back and forth five times: nothing breaks.
- **Every button once:** each ✕ / ← / Cancel closes what it should, the phone's Back does the same, no pop-up
  stays stuck open.

Then remove the test rides, plans and reports you made (or wipe them in Supabase if it's before a launch).

## 5. Bug check and fix: the art (its own task)

Goal: the scenery looks right and true to the place at every time, in every view. Rules: SCENE.md and
notes/art-playbook.md (local). Fix what you find, then run this step again from the top.

- **Times:** the banner and the full-screen painting at `?t=0500`, `?t=0630`, `?t=0800`, `?t=1300`, `?t=1630`,
  `?t=1800`, `?t=1930`, `?t=2200`, `?t=0100`: the right painting for the hour, smooth cross-fades, lights on at night,
  no white discs or leftover pieces.
- **Portrait and landscape full screen:** everything stands on the ground at its real place: people on the field and
  paths, cars on the road, cows on the grass, nobody walking on the hills or in the sky, nothing floating or cut in
  half by a layer. Check the left end, the middle and the right end (`?cam=x,scale`) in both.
- **Animations:** every mover uses its drawn frames (legs move), keeps its size as it walks (no jumps), turns at the
  ends, and disappears behind what's in front of it; gliders land on the landing field; the camera's tours end
  where they should.
- **Weather and seasons:** `?wx=cloudy` (and rain, if painted), the clothes and season pieces for this month.
- **Speed:** on a real phone, the painting runs smoothly for a minute, and after 5 minutes in the background it
  comes back without everything starting at once.

## 6. Look at every screen size

- Phones 320, 375 and 414 px wide, a phone on its side, and a laptop (the phone frame).
- Light and dark mode. Bot rides (`?bots`) on and off.
- Nothing cut off, nothing overlapping, no sideways scrolling, pop-ups fit with their buttons in view.

## 7. Check the promises are still true

Read these pages in the app and compare them with what the code and database really do now:

- **Privacy notes:** what is kept, for how long, who sees a number, what is anonymous, what is wiped and when.
- **Terms of use and Community Code:** still match how the app works.
- **Licences & Credits and `NOTICE`:** every map, data source, font, script and AI art tool used is named with its
  licence; the author credit is there.
- **Security (`SECURITY.md`, `_headers`):** every outside service the app talks to is listed in the
  Content-Security-Policy and nothing more; scripts are pinned with integrity fingerprints; no secret keys anywhere
  in the repo (`git grep -i -E "service_role|secret|password|token"` finds only the public key and code words);
  rate limits in the database still fit; the Supabase security advisor is clean or every point is understood.

## 8. Publish

1. Commit with a clear message, push, and let the person who owns the repo review if there is a second maintainer.
2. Merge to `main`; tag the release (`git tag v1.1 && git push --tags`).
3. Cloudflare Pages builds by itself in about a minute. Check it went out:
   `curl -s https://rideup.pages.dev/ | grep APP_VERSION`
4. Open https://rideup.pages.dev on a real phone: no errors, the version line shows the new number.
5. Send yourself the link on WhatsApp: the preview picture and words look right.

## 9. After the release

- For the first day, look at `usage_events` for `js_error` and `flow_fail` (see MAINTENANCE.md, "Reading error
  reports") and fix anything new as a small-fix version.
- Share the news (the message goes with the link; keep it short).
- Note in the weekly check that the release went out and anything to watch.
