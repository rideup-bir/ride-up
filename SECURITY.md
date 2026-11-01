# Security

## Reporting a problem

If you find a way to read someone's phone number, change someone else's ride, or anything else that looks unsafe,
**please don't open a public issue.** Email **cabwait.thermally.yours@gmail.com** with what you found and how to
reproduce it. We'll fix it privately first and credit you if you like.

## How Ride Up protects people

Ride Up has **no logins**. Instead:

- **The public key in `index.html` is meant to be public.** It only lets the app act as Supabase's `anon` role.
  Security comes from the database rules below, not from hiding the key.
- **Public tables are read-only.** Anyone can read rides, plans, trips and sky reports (that's what the app shows:
  first names, times, notes). Nobody can insert, update or delete them directly: the `anon` role has `SELECT` on
  these six tables and nothing else.
- **Private tables can't be read at all.** Phone numbers, secret tokens, feedback, ratings and usage counts live in
  tables with row-level security on and no policies, and no table grants for the app's roles.
- **Every change goes through a database function** (`security definer`, fixed `search_path`). Each one checks its
  inputs, and any change to an existing ride, plan or trip needs the secret token that only the phone that made it
  holds. Joining locks the row, so two people can't take the last seat.
- **Numbers are shared narrowly.** Only people in the same ride or trip see each other's number (in a lift, the
  driver sees everyone and joiners see the driver). Numbers are wiped within an hour of a ride being over.
- **Old data deletes itself.** Rides, plans, trips and sky reports a week after they're over; usage counts after 6 months; a name or number
  added to feedback after 90 days. An hourly job runs the tidy-up.
- **Spam guard.** Each kind of post is limited per minute across the whole app (for example 5 new rides a minute).
  Sky reports also need a name and a WhatsApp number: one number can send 3 an hour (the number is kept
  hidden in `sky_report_private` and deleted after 2 hours).
- **In the browser:** the page only loads scripts from jsDelivr, pinned to exact versions with integrity
  fingerprints, and `_headers` sends a strict Content-Security-Policy (only the listed services are reachable), plus
  `nosniff`, a referrer policy, a permissions policy and HSTS. Everything the app shows from other people is
  escaped before it reaches the page.
- **No secrets in the repository.** Account passwords and recovery codes live in the owners' password managers.

## What Supabase's security check will say (and why it's fine)

- **"Public can execute SECURITY DEFINER function"** for 26 functions: these are exactly the functions the app
  calls. Each checks its own token and limits. The helpers (`rideup_cleanup`, `rideup_rate_limit`, `bir_today`)
  can't be called from outside.
- **"RLS enabled, no policy"** for 6 tables: these are the private tables. No policy means no access, on purpose.

## Known limits (by design, for a no-login app)

- The spam guard counts across the whole app, so one determined person could block new posts for a minute.
  Per-person limits need logins.
- Names aren't verified. Anyone can type any name.
- A phone's tokens live in that phone's browser storage. Whoever holds the unlocked phone can act as that person in
  Ride Up (cancel their seat, for example).
- First names, notes and ride times are public to anyone who opens the app, as they are in a WhatsApp group.
