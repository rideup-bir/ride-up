# Handover: keeping Ride Up alive

Ride Up is meant to run **without depending on any one person**. This file is everything a new maintainer needs:
what exists, who owns it, how a change goes live, and how to take over or step back.

## 1. What exists

| Thing | Where | Free plan limits worth knowing |
|---|---|---|
| Code | GitHub organisation **rideup-bir**, repository **ride-up** (public) | none that matter |
| Website | Cloudflare Pages project **rideup** → https://rideup.pages.dev | 500 builds a month |
| Database | Supabase project **Ride Up** (Mumbai) | pauses after 7 days with no activity (the keep-alive job prevents this); 500 MB |
| Project email | cabwait.thermally.yours@gmail.com | the login for Cloudflare, and the contact address in the app |

Everything runs on free plans. There are no paid services, no ads and no money involved.

## 2. Who holds the keys

Each account should always have **at least two owners**, all with two-factor login turned on.

| Account | Owners today | How to add an owner |
|---|---|---|
| GitHub organisation | Praval Sharda | Organisation → People → Invite member → role **Owner** |
| Cloudflare | Praval Sharda (project email) | Manage account → Members → Invite → **Administrator** |
| Supabase | Praval Sharda | Organisation → Team → Invite → role **Owner** |
| Project email | Praval Sharda | Gmail → Settings → Accounts → **Grant access to your account** (delegation) |

Backup and recovery codes for each account live in the owners' password managers, **never** in this repository.

## 3. How a change goes live

1. Make a branch, change the code, and push it. Cloudflare builds a preview at
   `https://<branch-name>.rideup.pages.dev` within a minute or two.
2. Open a pull request. Another maintainer looks at it and tries the preview on a phone.
3. Merge into `main`. Cloudflare deploys it to https://rideup.pages.dev in about a minute.
4. For a release (not a small fix), follow the release procedure in [RELEASE.md](RELEASE.md) and tag it
   (`v1.1`, `v1.2`…).

**Undo:** in Cloudflare → Workers & Pages → rideup → Deployments, pick the last good deployment → **Rollback**. Or
revert the commit on GitHub.

## 4. Changing the database

`supabase-setup.sql` is the single source of truth.

1. Change the file.
2. Test it on a throwaway database first (for example the `pgserver` Python package; create an `anon` role and a
   `supabase_realtime` publication to mimic Supabase).
3. Run the changed parts in Supabase → SQL Editor. The file is safe to run again in full.
4. Keep old function signatures working until the new app version is live, so phones with the old page don't
   break.

## 5. If something goes wrong

| What you see | What to do |
|---|---|
| The site doesn't load | Cloudflare → rideup → Deployments: is the last build green? Roll back if not. |
| "Couldn't load rides" for everyone | Supabase dashboard: is the project paused? Click **Restore**. Check the keep-alive job in GitHub → Actions. |
| Spam or abusive posts | Supabase → Table Editor: delete the rows (rides, plans or trips). Everything deletes itself a week after it's over anyway. |
| Someone reports a security problem | See [SECURITY.md](SECURITY.md). Fix privately first, then publish. |
| Errors in the weekly check | See "Reading error reports" in [MAINTENANCE.md](MAINTENANCE.md). |

## 6. The rules that make Ride Up what it is

Please keep these unless the community clearly wants otherwise:

- **No logins, no ads, no tracking.** Names live on the phone; numbers are shared only inside a ride and wiped
  within an hour of it being over; everything else is deleted a week after it's over; usage counts are anonymous.
- **Bir time everywhere.** The app's clock is India time for everyone, wherever they open it.
- **Faster than WhatsApp, or it fails.** Every flow should take fewer taps than typing in the group.
- **Plain, friendly English.** A *ride* is a shared taxi from the landing, a *lift* is a seat in someone's car, a
  *trip* is travel to or from Bir, and the *number* is a WhatsApp number.
- **The scenery is true to Bir.** Everything to scale, real terrain, moving things use real animation frames.
  Every living thing and its rules are in [SCENE.md](SCENE.md): change that first, then the code.
- **A plain static site.** No build step, bundler or framework without a good reason and a discussion.

## 7. Stepping back

The founder (or any maintainer) can step back at any time: make sure every account has another owner, then
leave the organisation and accounts. Nothing else is needed. The author credit in [NOTICE](NOTICE) and in the
app stays, as the licence requires.
