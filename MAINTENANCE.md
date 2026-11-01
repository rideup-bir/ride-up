# Maintenance

A short routine keeps Ride Up healthy. It needs about 15 minutes a week.

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

The trail is made of these steps:

| Step | Meaning | Step | Meaning |
|---|---|---|---|
| A1 | Now page opened | E1 | Plan page opened |
| A2 | Rides loaded | E2 | Plan form opened |
| A3 | Trips loaded | E3 | Plan saved (database) |
| A4 | Weather loaded | E4 | Plan added |
| B1 | Start / join pop-up opened | E5 | Plan removed |
| B2 | Ride started (database) | E6 | Plan shared to WhatsApp |
| B3 | Ride / lift is up | F1 | Plan your travel opened |
| B4 | Offer a lift pop-up opened | F2 | Travel form opened |
| C1 | Join-a-lift form opened | F3 | Trip posted |
| C2 | Joined (database) | F4 | Join-trip form opened |
| C3 | Numbers loaded | F5 | Joined a trip |
| D1 | "Leave with fewer" changed | F6 | Left a trip |
| D2 | Number shared / hidden | F7 | Host removed someone |
| D3 | Seat cancelled | F8 | Trip numbers loaded |
| D4 | "We've driven off" (database) | F9 | Trip number changed |
| D5 | Driven off | G1 | Weather page opened |
| D6 | Friends added | G2 | Sky report sent |
| D7 | Note changed | H1 | Map opened |
| D8 | Car changed | I1–I6 | Feedback pop-up, chat, sent, rating opened, rating sent, note suggestion |
| D9 | Lift changed | K1–K7 | Menu, Settings, Profile, Safety, info pages, Home Screen, Versions |
| D10 | "I didn't go" / "still waiting" | | |

## Backups

The code is in GitHub, so it is its own backup. The database holds only short-lived data by design (rides and
plans disappear within a week), and `supabase-setup.sql` rebuilds it from nothing. Feedback is the only thing worth
keeping: export `feedback` and `review_feedback` as CSV from the Table Editor now and then if you want a copy.
