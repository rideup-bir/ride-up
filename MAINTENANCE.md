# Maintenance

A short routine keeps Ride Up healthy. It needs about 15 minutes a week.

## Who looks after Ride Up

Today Ride Up has one owner, its founder, who looks after it until others join (see [HANDOVER.md](HANDOVER.md):
every account should get a second owner). Day to day it runs by itself: the database cleans itself up every hour, a
GitHub job keeps it awake, and an automatic daily check and a weekly briefing (run by the owner's AI assistant,
read-only on the database) report anything broken. Small fixes can go live straight away; anything bigger waits for
the owner. When maintainers join, they share the routine below.

## Every week (Saturday evening works well)

Open Supabase → SQL Editor and run:

```sql
select * from insights.feedback_week;        -- what people wrote
select * from insights.review_comments_week;  -- comments in ratings
select * from insights.ratings_by_topic;     -- ratings per topic (0–100)
select * from insights.usage_daily;          -- what people did, per day
select * from insights.errors_recent;        -- errors from people's phones
```

Then:

1. Reply where someone left a contact and asked something.
2. Turn anything worth doing into a GitHub issue (templates: bug, idea, from feedback).
3. Act straight away on anything about **safety, privacy or the law**, or anything **five or more people** say.
4. Look at the errors (see below). A few "network" failures are normal on the road up.

## Every month

- Supabase → Advisors → Security. The expected notes are explained in [SECURITY.md](SECURITY.md); anything else
  needs a look.
- GitHub → Actions: is "Keep Ride Up's database awake" still running? (GitHub pauses scheduled jobs after 60 days
  without activity in the repository. Re-enable it there.)
- Cloudflare → rideup: builds used this month (limit 500).
- GitHub → rideup-bir/ride-up → Settings → Rules: both rulesets ("Protect main", "Protect release tags") are Active.
- Every owner still has two-factor login on, and the recovery codes are where they should be (a password manager).

## Every season

- No-fly season dates (`NO_FLY_SEASON` in `index.html`, today 15 July – 15 September).
- Safety numbers, map places and pick-up points still correct?
- Clothing of the people in the scenery fits the season.

## Releasing a new version

Follow the step-by-step procedure in [RELEASE.md](RELEASE.md) for every new version.

Version numbers: **1.1, 1.2…** for releases people see; **1.1.1, 1.1.2…** for small fixes; **2.0** only for a
big change in how people use it.

If the app's outside scripts are updated (Supabase JS or Leaflet), pin the exact new version and update the
`integrity` fingerprint next to it (`openssl dgst -sha384 -binary file | openssl base64 -A`).

## Reading error reports

Phones send an anonymous report when something breaks (at most a few per visit). In `usage_events`:

- **`js_error`**: `message | file:line:col | screen + seconds after opening | browser | first trace step` and a
  `flow` trail, for example `flow A1>B1>B2`.
- **`flow_fail`**: a refused or failed step, for example `join_cab: cab_full @C2`. "network" means the phone had
  no signal; a refusal code like `cab_full` usually means the app worked as designed.

The trail is made of these steps (the owners keep a fuller map with every refusal reason):

| Step | Meaning | Step | Meaning |
|---|---|---|---|
| A1 | Now page opened | E1 | Plan page opened |
| A2 | Rides loaded | E2 | Plan form opened |
| A3 | Travel posts loaded | E3 | Plan saved (database) |
| A4 | Weather loaded | E4 | Plan added |
| A5 | Welcome (first visit) | E5 | Plan removed |
| B1 | Ride pop-up opened | E6 | Plan shared to WhatsApp |
| B2 | Ride started (database) | F1 | Plan your travel opened |
| B3 | Ride / lift is up | F2 | Travel form opened |
| B4 | Offer a lift form opened | F3 | Trip posted (database) |
| B5 | Your own circle (name, number) | F4 | Join-trip form opened |
| B6 | A friend's circle / name | F5 | Joined a trip (database) |
| C1 | Join pop-up opened | F6 | Left a trip |
| C2 | Joined (database) | F7 | Poster removed someone |
| C3 | Numbers loaded | F8 | Trip numbers loaded |
| D1 | "Leave with fewer" changed | F9 | Trip number shared / hidden |
| D2 | Number shared / hidden | F10 | When: calendar + time |
| D3 | Seat cancelled / left | F11 | How: taxi or my car |
| D4 | "We've driven off" (database) | G1 | Weather page opened |
| D5 | Driven off | G2 | Sky report sent (database) |
| D6 | Friends changed | G3 | Report pop-up opened |
| D7 | Note added / changed | G4 | Forecast note opened |
| D8 | Car changed | H1 | Map opened |
| D9 | Lift changed | I1–I6 | Feedback faces, chat, sent, ratings |
| D10 | "I didn't go" / reopened | J1 | Bot rides switched on |
| | | K1–K9 | Menu, Settings, Profile, Help, info pages, Home Screen, Version, Display & units, number / car |

Common refusal reasons: `slow_down` (the spam guard), `cab_full` (someone was quicker), `cab_closed` (it left or
was cancelled), `not_found` / `not_member` (the ride was deleted after a week, or the phone lost its saved
membership), `need_details` / `too_many_reports` (weather reports need a name and number; 3 an hour).

## Backups

The code is in GitHub, so it is its own backup. The database holds only short-lived data by design (rides and
plans disappear within a week), and `supabase-setup.sql` rebuilds it from nothing. Feedback is the only thing worth
keeping: export `feedback` and `review_feedback` as CSV from the Table Editor now and then if you want a copy.
