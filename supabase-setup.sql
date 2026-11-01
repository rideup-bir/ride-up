-- Ride Up: the complete database setup (Supabase / PostgreSQL).
--
-- Paste the whole file into Supabase → SQL Editor → Run. It is safe to run again: everything is
-- "create if missing" or "replace". This file is the single source of truth for the database.
--
-- How it works (see SECURITY.md):
--  * The app has no logins. It talks to the database only as the "anon" role, with the public key.
--  * Public tables can be READ by anyone (that's what the app shows), but nobody can write to them directly.
--  * Every change goes through a function below. Each one checks its own rules and, for changes to an
--    existing ride / plan / trip, a secret token that only the phone that made it holds.
--  * Phone numbers and tokens live in "private" tables that nobody outside can read at all.
--  * "Today" is always the date at Bir (India, UTC+5:30), whatever the server clock says.
--  * Old data cleans itself up: numbers when a ride is over, everything else after 7 days.


-- ============ TABLES ============

-- A taxi ride up from the landing ("taxi"), or a lift in someone's own car ("own")
create table if not exists cab_sessions (
  id           uuid primary key default gen_random_uuid(),
  created_at   timestamptz not null default now(),
  capacity     int not null check (capacity between 1 and 12),
  vehicle      text not null default 'taxi' check (vehicle in ('taxi', 'own')),
  car_type     text,
  car_number   text,                       -- lifts only
  status       text not null default 'waiting' check (status in ('waiting', 'full', 'departed', 'cancelled')),
  departed_at  timestamptz,
  flexible     boolean not null default false,   -- "happy to leave with fewer"
  flexible_by  uuid,                              -- who offered to cover the empty share (null = the starter)
  pickup       text,                       -- lifts: where the driver picks people up
  leave_time   text,                       -- lifts: "HH:MM", Bir time
  leave_window int,                        -- lifts: give or take this many minutes
  disputed_by  text,                       -- "I didn't go": the name of whoever said so
  disputed_at  timestamptz
);
create index if not exists cab_sessions_created on cab_sessions (created_at);

create table if not exists cab_passengers (
  id         uuid primary key default gen_random_uuid(),
  session_id uuid not null references cab_sessions (id) on delete cascade,
  name       text not null,
  notes      text,
  extra      int not null default 0,      -- friends coming along (they take seats too)
  friends    text,                        -- their first names, if given
  joined_at  timestamptz not null default now(),
  left_at    timestamptz
);
create index if not exists cab_passengers_session on cab_passengers (session_id);

-- PRIVATE: the secret token that proves "this is my seat", and the WhatsApp number (if shared)
create table if not exists cab_passenger_private (
  passenger_id uuid primary key references cab_passengers (id) on delete cascade,
  token        uuid not null default gen_random_uuid(),
  phone        text
);

-- "Plan ahead": who's heading up to fly when
create table if not exists flight_plans (
  id         uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  plan_date  date not null,
  name       text not null,
  time_slot  text,                        -- "HH:MM", Bir time
  note       text
);
create index if not exists flight_plans_date on flight_plans (plan_date);

create table if not exists flight_plan_private (
  plan_id uuid primary key references flight_plans (id) on delete cascade,
  token   uuid not null default gen_random_uuid()
);

-- "Plan your travel": trips to or from Bir. "offer" = seats on offer; "request" = someone asking for a ride
create table if not exists trips (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  kind        text not null default 'offer' check (kind in ('offer', 'request')),
  from_place  text not null,
  to_place    text not null,
  trip_date   date not null,
  trip_time   text not null,              -- "HH:MM", Bir time
  time_window int,                        -- give or take this many minutes
  flexible    boolean not null default false,
  time_from   text,
  time_to     text,
  capacity    int not null,               -- offers: free seats + the host's party; requests: how many people
  status      text not null default 'open' check (status in ('open', 'full', 'cancelled')),
  vehicle     text not null default 'taxi' check (vehicle in ('taxi', 'own')),
  taxi_booked boolean not null default true,
  bags        int not null default 0,
  stops       text,
  team_up     boolean not null default false,  -- requests: happy to share a taxi with others going the same way
  host_member uuid
);
create index if not exists trips_date on trips (trip_date);

create table if not exists trip_members (
  id        uuid primary key default gen_random_uuid(),
  trip_id   uuid not null references trips (id) on delete cascade,
  name      text not null,
  notes     text,
  pickup    text,                         -- "only part of the way", e.g. "till Mandi"
  extra     int not null default 0,
  removed   boolean not null default false,  -- taken off by the host
  joined_at timestamptz not null default now(),
  left_at   timestamptz
);
create index if not exists trip_members_trip on trip_members (trip_id);

create table if not exists trip_member_private (
  member_id uuid primary key references trip_members (id) on delete cascade,
  token     uuid not null default gen_random_uuid(),
  phone     text
);

-- What people at launch / the landing actually see ("clear", "cloudy", "fog")
create table if not exists sky_reports (
  id         uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  spot       text not null check (spot in ('launch', 'landing')),
  state      text not null check (state in ('clear', 'cloudy', 'fog')),
  name       text
);

-- PRIVATE: the number behind a sky report, kept only to stop one number reporting over and over (gone after 2 hours)
create table if not exists sky_report_private (
  report_id  uuid primary key references sky_reports (id) on delete cascade,
  created_at timestamptz not null default now(),
  phone      text not null
);
create index if not exists sky_report_private_phone on sky_report_private (phone, created_at);

-- PRIVATE: feedback from the app (read in Supabase → Table Editor, or the insights views below)
create table if not exists feedback (
  id         uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  message    text not null,
  contact    text,
  name       text,                        -- only if the person chose to add their details
  phone      text,
  topic      text,
  stage      text,
  version    text
);

-- PRIVATE: ratings from the faces pop-up and the "Rate Ride Up" questionnaire (score 0–100)
create table if not exists review_feedback (
  id         bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  batch      uuid not null,
  stage      text,
  version    text,
  topic      text not null,
  score      int check (score between 0 and 100),
  comment    text
);

-- PRIVATE: anonymous usage counts ("a ride was started", "the map was opened") and error reports.
-- No names, numbers, ids or cookies.
create table if not exists usage_events (
  id         bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  event      text not null,
  detail     text,
  version    text,
  stage      text
);
create index if not exists usage_events_time on usage_events (created_at);


-- ============ WHO CAN SEE WHAT ============

alter table cab_sessions          enable row level security;
alter table cab_passengers        enable row level security;
alter table cab_passenger_private enable row level security;
alter table flight_plans          enable row level security;
alter table flight_plan_private   enable row level security;
alter table trips                 enable row level security;
alter table trip_members          enable row level security;
alter table trip_member_private   enable row level security;
alter table sky_reports           enable row level security;
alter table sky_report_private    enable row level security;
alter table feedback              enable row level security;
alter table review_feedback       enable row level security;
alter table usage_events          enable row level security;

-- Public tables: anyone may read them. Private tables get no rules at all, so nobody outside can read them.
do $$
declare t text;
begin
  foreach t in array array['cab_sessions', 'cab_passengers', 'flight_plans', 'trips', 'trip_members', 'sky_reports'] loop
    execute format('drop policy if exists "public read" on %I', t);
    execute format('create policy "public read" on %I for select using (true)', t);
  end loop;
end $$;

-- A second lock: the app's roles may only READ the public tables, and touch nothing else directly.
revoke all on all tables in schema public from anon, authenticated;
grant select on cab_sessions, cab_passengers, flight_plans, trips, trip_members, sky_reports to anon;
alter default privileges in schema public revoke all on tables from anon, authenticated;


-- ============ HELPERS (not callable from outside) ============

-- Today's date at Bir
create or replace function bir_today() returns date language sql stable set search_path = pg_catalog as $$
  select (now() at time zone 'Asia/Kolkata')::date
$$;

-- A simple spam guard: at most p_max new rows a minute in a table, across the whole app
create or replace function rideup_rate_limit(p_table text, p_max int)
returns void language plpgsql security definer set search_path = public as $$
declare v_count int;
begin
  execute format('select count(*) from %I where created_at > now() - interval ''1 minute''', p_table) into v_count;
  if v_count >= p_max then raise exception 'slow_down'; end if;
end $$;

-- Tidy-up: numbers go as soon as a ride is over, everything else after 7 days.
-- Feedback keeps its words; a name + number given with it go after 90 days.
create or replace function rideup_cleanup()
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from sky_reports where created_at < now() - interval '7 days';
  delete from sky_report_private where created_at < now() - interval '2 hours';
  update cab_passenger_private k set phone = null
    from cab_passengers p join cab_sessions s on s.id = p.session_id
   where k.passenger_id = p.id and k.phone is not null
     and (p.left_at is not null or s.status in ('departed', 'cancelled') or s.created_at < now() - interval '4 hours');
  update trip_member_private k set phone = null
    from trip_members m join trips t on t.id = m.trip_id
   where k.member_id = m.id and k.phone is not null
     and (m.left_at is not null or t.status = 'cancelled' or t.trip_date < bir_today());
  delete from cab_sessions where created_at < now() - interval '7 days';
  delete from trips where trip_date < bir_today() - 7 or (status = 'cancelled' and created_at < now() - interval '7 days');
  delete from flight_plans where plan_date < bir_today() - 7;
  delete from usage_events where created_at < now() - interval '180 days';
  update feedback set name = null, phone = null where (name is not null or phone is not null) and created_at < now() - interval '90 days';
end $$;


-- ============ RIDES UP FROM THE LANDING ============
-- Errors the app understands: name_required, bad_capacity, phone_required, pickup_required, bad_time,
-- not_found, cab_full, cab_closed, not_member, not_owner, too_small, slow_down.

-- Start a taxi ride or offer a lift. p_leave_* = leave your old ride in the same step.
create or replace function start_cab(
  p_id uuid, p_capacity int, p_name text, p_car_number text default null, p_car_type text default null,
  p_notes text default null, p_phone text default null, p_leave_passenger uuid default null, p_leave_token uuid default null,
  p_vehicle text default 'taxi', p_extra int default 0, p_flexible boolean default false,
  p_pickup text default null, p_time text default null, p_window int default null, p_friends text default null)
returns json language plpgsql security definer set search_path = public as $$
declare
  v_session uuid;
  v_passenger uuid;
  v_token uuid;
  v_own boolean := p_vehicle = 'own';
  v_extra int := case when p_vehicle = 'own' then 0 else coalesce(p_extra, 0) end;
begin
  if coalesce(trim(p_name), '') = '' then raise exception 'name_required'; end if;
  if p_capacity is null or p_capacity < 1 or p_capacity > 12 then raise exception 'bad_capacity'; end if;
  if v_extra < 0 or 1 + v_extra > p_capacity then raise exception 'bad_capacity'; end if;
  if v_own and coalesce(p_phone, '') !~ '^[0-9]{11,15}$' then raise exception 'phone_required'; end if;
  if v_own and coalesce(trim(p_pickup), '') = '' then raise exception 'pickup_required'; end if;
  if p_time is not null and p_time !~ '^[0-2][0-9]:[0-5][0-9]$' then raise exception 'bad_time'; end if;
  if p_window is not null and (p_window < 0 or p_window > 60) then raise exception 'bad_time'; end if;
  if p_leave_passenger is not null then perform leave_cab(p_leave_passenger, p_leave_token); end if;
  perform rideup_cleanup();
  perform rideup_rate_limit('cab_sessions', 5);

  insert into cab_sessions (id, capacity, car_number, car_type, status, vehicle, flexible, pickup, leave_time, leave_window)
  values (coalesce(p_id, gen_random_uuid()), p_capacity,
          case when v_own then nullif(left(trim(coalesce(p_car_number, '')), 20), '') end,
          nullif(left(trim(coalesce(p_car_type, '')), 30), ''),
          case when 1 + v_extra >= p_capacity then 'full' else 'waiting' end,
          case when v_own then 'own' else 'taxi' end,
          not v_own and coalesce(p_flexible, false),
          case when v_own then left(trim(p_pickup), 80) end,
          case when v_own then p_time end,
          case when v_own and p_time is not null then coalesce(p_window, 10) end)
  returning id into v_session;

  insert into cab_passengers (session_id, name, notes, extra, friends)
  values (v_session, left(trim(p_name), 40), nullif(left(trim(coalesce(p_notes, '')), 120), ''), v_extra,
          case when v_extra > 0 then nullif(left(trim(coalesce(p_friends, '')), 70), '') end)
  returning id into v_passenger;

  insert into cab_passenger_private (passenger_id, phone)
  values (v_passenger, case when p_phone ~ '^[0-9]{11,15}$' then p_phone end)
  returning token into v_token;

  return json_build_object('session_id', v_session, 'passenger_id', v_passenger, 'token', v_token);
end $$;

-- Join a ride. The row is locked while seats are counted, so two people can't take the last seat.
create or replace function join_cab(
  p_session uuid, p_name text, p_notes text default null, p_phone text default null,
  p_leave_passenger uuid default null, p_leave_token uuid default null, p_extra int default 0, p_friends text default null)
returns json language plpgsql security definer set search_path = public as $$
declare
  v_status text;
  v_capacity int;
  v_vehicle text;
  v_count int;
  v_passenger uuid;
  v_token uuid;
begin
  if coalesce(trim(p_name), '') = '' then raise exception 'name_required'; end if;
  if coalesce(p_extra, 0) < 0 or coalesce(p_extra, 0) > 11 then raise exception 'bad_capacity'; end if;

  select status, capacity, vehicle into v_status, v_capacity, v_vehicle from cab_sessions where id = p_session for update;
  if v_status is null then raise exception 'not_found'; end if;
  if v_vehicle = 'own' and coalesce(p_phone, '') !~ '^[0-9]{11,15}$' then raise exception 'phone_required'; end if;
  if p_leave_passenger is not null then perform leave_cab(p_leave_passenger, p_leave_token); end if;
  if v_status = 'full' then raise exception 'cab_full'; end if;
  if v_status <> 'waiting' then raise exception 'cab_closed'; end if;
  select coalesce(sum(1 + extra), 0) into v_count from cab_passengers where session_id = p_session and left_at is null;
  if v_count + 1 + coalesce(p_extra, 0) > v_capacity then raise exception 'cab_full'; end if;

  insert into cab_passengers (session_id, name, notes, extra, friends)
  values (p_session, left(trim(p_name), 40), nullif(left(trim(coalesce(p_notes, '')), 120), ''), coalesce(p_extra, 0),
          case when coalesce(p_extra, 0) > 0 then nullif(left(trim(coalesce(p_friends, '')), 70), '') end)
  returning id into v_passenger;

  insert into cab_passenger_private (passenger_id, phone)
  values (v_passenger, case when p_phone ~ '^[0-9]{11,15}$' then p_phone end)
  returning token into v_token;

  if v_count + 1 + coalesce(p_extra, 0) >= v_capacity then
    update cab_sessions set status = 'full' where id = p_session;
  end if;

  return json_build_object('session_id', p_session, 'passenger_id', v_passenger, 'token', v_token);
end $$;

-- Cancel your seat. The last person out cancels the ride; a lift's driver leaving ends the lift for everyone.
create or replace function leave_cab(p_passenger uuid, p_token uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_session uuid;
  v_status text;
  v_capacity int;
  v_remaining int;
  v_vehicle text;
  v_flex boolean;
  v_by uuid;
  v_starter uuid;
begin
  select p.session_id into v_session
    from cab_passengers p join cab_passenger_private k on k.passenger_id = p.id
   where p.id = p_passenger and k.token = p_token and p.left_at is null;
  if v_session is null then raise exception 'not_member'; end if;

  select status, capacity, vehicle, flexible, flexible_by into v_status, v_capacity, v_vehicle, v_flex, v_by
    from cab_sessions where id = v_session for update;
  if v_status in ('departed', 'cancelled') then raise exception 'cab_closed'; end if;
  select id into v_starter from cab_passengers where session_id = v_session order by joined_at, id limit 1;

  update cab_passengers set left_at = now() where id = p_passenger;
  -- an offer to cover the empty share leaves with the person who made it (null = the starter made it)
  if v_flex and (v_by = p_passenger or (v_by is null and v_starter = p_passenger)) then
    update cab_sessions set flexible = false, flexible_by = null where id = v_session;
  end if;
  if v_vehicle = 'own' and v_starter = p_passenger then
    update cab_sessions set status = 'cancelled' where id = v_session;
    return;
  end if;
  select coalesce(sum(1 + extra), 0) into v_remaining from cab_passengers where session_id = v_session and left_at is null;
  if v_remaining = 0 then
    update cab_sessions set status = 'cancelled' where id = v_session;
  elsif v_remaining < v_capacity then
    update cab_sessions set status = 'waiting' where id = v_session;
  end if;
end $$;

-- "We've driven off" (anyone in the ride can say it)
create or replace function mark_departed(p_passenger uuid, p_token uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_session uuid;
begin
  select p.session_id into v_session
    from cab_passengers p join cab_passenger_private k on k.passenger_id = p.id
   where p.id = p_passenger and k.token = p_token and p.left_at is null;
  if v_session is null then raise exception 'not_member'; end if;
  update cab_sessions set status = 'departed', departed_at = now()
   where id = v_session and departed_at is null and status in ('waiting', 'full');
end $$;

-- "I didn't go": leave a ride marked as driven off (within 90 min); the others are asked if they left
create or replace function undo_departed(p_passenger uuid, p_token uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_session uuid; v_name text;
begin
  select p.session_id, p.name into v_session, v_name
    from cab_passengers p join cab_passenger_private k on k.passenger_id = p.id
    join cab_sessions s on s.id = p.session_id
   where p.id = p_passenger and k.token = p_token and p.left_at is null
     and s.status = 'departed' and s.departed_at > now() - interval '90 minutes';
  if v_session is null then raise exception 'not_member'; end if;
  update cab_passengers set left_at = now() where id = p_passenger;
  update cab_sessions set disputed_by = v_name, disputed_at = now() where id = v_session;
end $$;

-- "No, still waiting": someone still in that ride puts it back on the list
create or replace function reopen_cab(p_passenger uuid, p_token uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_session uuid; v_used int; v_cap int;
begin
  select p.session_id into v_session
    from cab_passengers p join cab_passenger_private k on k.passenger_id = p.id
    join cab_sessions s on s.id = p.session_id
   where p.id = p_passenger and k.token = p_token and p.left_at is null
     and s.status = 'departed' and s.disputed_at is not null and s.departed_at > now() - interval '90 minutes';
  if v_session is null then raise exception 'not_member'; end if;
  select capacity into v_cap from cab_sessions where id = v_session for update;
  select coalesce(sum(1 + extra), 0) into v_used from cab_passengers where session_id = v_session and left_at is null;
  update cab_sessions set status = case when v_used >= v_cap then 'full' else 'waiting' end,
         departed_at = null, disputed_by = null, disputed_at = null
   where id = v_session;
end $$;

-- The WhatsApp numbers you may see: everyone in a taxi ride; in a lift, the driver sees all and joiners see the driver
create or replace function get_cab_contacts(p_passenger uuid, p_token uuid)
returns table (passenger_id uuid, phone text) language sql stable security definer set search_path = public as $$
  with me as (
    select m.id, m.session_id
      from cab_passengers m join cab_passenger_private mk on mk.passenger_id = m.id
     where m.id = p_passenger and mk.token = p_token and m.left_at is null),
  host as (
    select h.id from cab_passengers h where h.session_id = (select session_id from me)
     order by h.joined_at limit 1)
  select p.id, k.phone
    from cab_passengers p join cab_passenger_private k on k.passenger_id = p.id
    join cab_sessions s on s.id = p.session_id
   where p.left_at is null
     and p.session_id = (select session_id from me)
     and (s.vehicle <> 'own' or (select id from me) = (select id from host)
          or p.id = (select id from host) or p.id = (select id from me));
$$;

-- Share or hide your number in a ride (a lift always shares it)
create or replace function set_cab_phone(p_passenger uuid, p_token uuid, p_phone text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if coalesce(p_phone, '') !~ '^[0-9]{11,15}$' and exists (
       select 1 from cab_passengers p join cab_sessions s on s.id = p.session_id
        where p.id = p_passenger and s.vehicle = 'own') then
    raise exception 'phone_required';
  end if;
  update cab_passenger_private
     set phone = case when p_phone ~ '^[0-9]{11,15}$' then p_phone end
   where passenger_id = p_passenger and token = p_token;
  if not found then raise exception 'not_member'; end if;
end $$;

-- "Happy to leave with fewer": anyone in a taxi ride can offer to cover the empty share; only they can take it back
create or replace function set_cab_flexible(p_passenger uuid, p_token uuid, p_flexible boolean)
returns void language plpgsql security definer set search_path = public as $$
declare v_session uuid; v_by uuid; v_flex boolean; v_starter uuid;
begin
  select p.session_id into v_session
    from cab_passengers p join cab_passenger_private k on k.passenger_id = p.id
   where p.id = p_passenger and k.token = p_token and p.left_at is null;
  if v_session is null then raise exception 'not_member'; end if;
  select flexible, flexible_by into v_flex, v_by from cab_sessions where id = v_session;
  if coalesce(p_flexible, false) then
    update cab_sessions set flexible = true, flexible_by = p_passenger
     where id = v_session and vehicle = 'taxi' and status in ('waiting', 'full');
  else
    select id into v_starter from cab_passengers where session_id = v_session order by joined_at limit 1;
    if v_flex and coalesce(v_by, v_starter) <> p_passenger then raise exception 'not_owner'; end if;
    update cab_sessions set flexible = false, flexible_by = null
     where id = v_session and vehicle = 'taxi' and status in ('waiting', 'full');
  end if;
end $$;

-- The starter changes the car (never smaller than the seats already taken)
create or replace function set_cab_car(p_passenger uuid, p_token uuid, p_car_type text, p_capacity int)
returns void language plpgsql security definer set search_path = public as $$
declare v_session uuid; v_starter uuid; v_used int; v_vehicle text; v_status text;
begin
  select p.session_id into v_session
    from cab_passengers p join cab_passenger_private k on k.passenger_id = p.id
   where p.id = p_passenger and k.token = p_token and p.left_at is null;
  if v_session is null then raise exception 'not_member'; end if;
  select vehicle, status into v_vehicle, v_status from cab_sessions where id = v_session for update;
  if v_vehicle <> 'taxi' or v_status not in ('waiting', 'full') then raise exception 'cab_closed'; end if;
  select id into v_starter from cab_passengers where session_id = v_session order by joined_at, id limit 1;
  if v_starter <> p_passenger then raise exception 'not_owner'; end if;
  if p_capacity is null or p_capacity < 2 or p_capacity > 12 then raise exception 'bad_capacity'; end if;
  select coalesce(sum(1 + extra), 0) into v_used from cab_passengers where session_id = v_session and left_at is null;
  if p_capacity < v_used then raise exception 'too_small'; end if;
  update cab_sessions set car_type = nullif(left(trim(coalesce(p_car_type, '')), 30), ''), capacity = p_capacity,
         status = case when v_used >= p_capacity then 'full' else 'waiting' end
   where id = v_session;
end $$;

-- Add or change your own note on a ride
create or replace function set_my_note(p_passenger uuid, p_token uuid, p_note text)
returns void language plpgsql security definer set search_path = public as $$
begin
  update cab_passengers p set notes = nullif(left(trim(coalesce(p_note, '')), 120), '')
    from cab_passenger_private k
   where p.id = p_passenger and k.passenger_id = p.id and k.token = p_token and p.left_at is null;
  if not found then raise exception 'not_member'; end if;
end $$;

-- "+ Add a friend": friends who'll ride with you in a taxi you're already in (up to the free seats)
create or replace function set_my_friends(p_passenger uuid, p_token uuid, p_extra int, p_friends text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_session uuid; v_vehicle text; v_status text; v_cap int; v_others int;
begin
  select p.session_id into v_session
    from cab_passengers p join cab_passenger_private k on k.passenger_id = p.id
   where p.id = p_passenger and k.token = p_token and p.left_at is null;
  if v_session is null then raise exception 'not_member'; end if;
  if coalesce(p_extra, 0) < 0 or coalesce(p_extra, 0) > 11 then raise exception 'bad_capacity'; end if;
  select vehicle, status, capacity into v_vehicle, v_status, v_cap from cab_sessions where id = v_session for update;
  if v_vehicle <> 'taxi' or v_status not in ('waiting', 'full') then raise exception 'cab_closed'; end if;
  select coalesce(sum(1 + extra), 0) into v_others from cab_passengers
   where session_id = v_session and left_at is null and id <> p_passenger;
  if v_others + 1 + coalesce(p_extra, 0) > v_cap then raise exception 'cab_full'; end if;
  update cab_passengers set extra = coalesce(p_extra, 0),
         friends = case when coalesce(p_extra, 0) > 0 then nullif(left(trim(coalesce(p_friends, '')), 70), '') end
   where id = p_passenger;
  update cab_sessions set status = case when v_others + 1 + coalesce(p_extra, 0) >= v_cap then 'full' else 'waiting' end
   where id = v_session;
end $$;

-- The driver of a lift changes its pick-up point, time or car details (null car = hidden on the card)
create or replace function set_lift(p_passenger uuid, p_token uuid, p_pickup text, p_time text, p_window int,
  p_car_type text default null, p_car_number text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_session uuid; v_starter uuid; v_vehicle text; v_status text;
begin
  select p.session_id into v_session
    from cab_passengers p join cab_passenger_private k on k.passenger_id = p.id
   where p.id = p_passenger and k.token = p_token and p.left_at is null;
  if v_session is null then raise exception 'not_member'; end if;
  select vehicle, status into v_vehicle, v_status from cab_sessions where id = v_session for update;
  if v_vehicle <> 'own' or v_status not in ('waiting', 'full') then raise exception 'cab_closed'; end if;
  select id into v_starter from cab_passengers where session_id = v_session order by joined_at, id limit 1;
  if v_starter <> p_passenger then raise exception 'not_owner'; end if;
  if coalesce(trim(p_pickup), '') = '' then raise exception 'pickup_required'; end if;
  if p_time is not null and p_time !~ '^[0-2][0-9]:[0-5][0-9]$' then raise exception 'bad_time'; end if;
  if p_window is not null and (p_window < 0 or p_window > 60) then raise exception 'bad_time'; end if;
  update cab_sessions set pickup = left(trim(p_pickup), 80), leave_time = p_time,
         leave_window = case when p_time is not null then coalesce(p_window, 10) end,
         car_type = nullif(left(trim(coalesce(p_car_type, '')), 30), ''),
         car_number = nullif(left(trim(coalesce(p_car_number, '')), 20), '')
   where id = v_session;
end $$;


-- ============ PLAN AHEAD ============

-- Add a plan (yesterday to a week ahead, any time of day). Also tidies away plans from before yesterday.
create or replace function add_plan(p_date date, p_name text, p_time text, p_note text default null)
returns json language plpgsql security definer set search_path = public as $$
declare
  v_plan uuid;
  v_token uuid;
begin
  if coalesce(trim(p_name), '') = '' then raise exception 'name_required'; end if;
  if p_time is null or p_time !~ '^[0-2][0-9]:[0-5][0-9]$' or p_time > '23:59' then raise exception 'bad_time'; end if;
  if p_date is null or p_date < bir_today() - 1 or p_date > bir_today() + 7 then raise exception 'bad_date'; end if;

  delete from flight_plans where plan_date < bir_today() - 1;
  perform rideup_rate_limit('flight_plans', 10);

  insert into flight_plans (plan_date, name, time_slot, note)
  values (p_date, left(trim(p_name), 40), p_time, nullif(left(trim(coalesce(p_note, '')), 120), ''))
  returning id into v_plan;

  insert into flight_plan_private (plan_id) values (v_plan) returning token into v_token;
  return json_build_object('plan_id', v_plan, 'token', v_token);
end $$;

create or replace function remove_plan(p_plan uuid, p_token uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from flight_plans f using flight_plan_private k
   where f.id = p_plan and k.plan_id = f.id and k.token = p_token;
  if not found then raise exception 'not_owner'; end if;
end $$;


-- ============ PLAN YOUR TRAVEL (trips to / from Bir) ============

-- Post a trip: "offer" (seats free, not counting the host and their friends) or "request" (how many people).
-- A WhatsApp number is required, so people going the same way can reach each other.
create or replace function create_trip(
  p_kind text, p_from text, p_to text, p_date date, p_time text,
  p_flexible boolean, p_time_from text, p_time_to text,
  p_seats int, p_name text, p_phone text, p_notes text default null,
  p_vehicle text default 'taxi', p_taxi_booked boolean default true, p_bags int default 0,
  p_stops text default null, p_team_up boolean default true,
  p_extra int default 0, p_window int default null)
returns json language plpgsql security definer set search_path = public as $$
declare
  v_trip uuid;
  v_member uuid;
  v_token uuid;
  v_extra int := case when p_kind = 'offer' and coalesce(p_vehicle, 'taxi') = 'taxi' then coalesce(p_extra, 0) else 0 end;
begin
  if p_kind not in ('offer', 'request') then raise exception 'bad_kind'; end if;
  if coalesce(trim(p_name), '') = '' then raise exception 'name_required'; end if;
  if coalesce(p_phone, '') !~ '^[0-9]{11,15}$' then raise exception 'phone_required'; end if;
  if coalesce(trim(p_from), '') = '' or coalesce(trim(p_to), '') = '' then raise exception 'place_required'; end if;
  if p_seats is null or p_seats < 1 or p_seats > 11 then raise exception 'bad_capacity'; end if;
  if v_extra < 0 or v_extra > 10 or p_seats + 1 + v_extra > 12 then raise exception 'bad_capacity'; end if;
  if p_window is not null and (p_window < 0 or p_window > 180) then raise exception 'bad_time'; end if;
  if p_date is null or p_date < bir_today() - 1 or p_date > bir_today() + 90 then raise exception 'bad_date'; end if;
  if p_time is null or p_time !~ '^[0-2][0-9]:[0-5][0-9]$' then raise exception 'bad_time'; end if;
  if p_time_from is not null and p_time_from !~ '^[0-2][0-9]:[0-5][0-9]$' then raise exception 'bad_time'; end if;
  if p_time_to is not null and p_time_to !~ '^[0-2][0-9]:[0-5][0-9]$' then raise exception 'bad_time'; end if;
  if coalesce(p_vehicle, 'taxi') not in ('taxi', 'own') then raise exception 'bad_vehicle'; end if;

  if exists (select 1 from trip_members m join trip_member_private k on k.member_id = m.id join trips t on t.id = m.trip_id
              where k.phone = p_phone and m.left_at is null and t.status <> 'cancelled' and t.trip_date = p_date) then
    raise exception 'one_plan_a_day';
  end if;

  perform rideup_cleanup();
  perform rideup_rate_limit('trips', 5);
  insert into trips (kind, from_place, to_place, trip_date, trip_time, flexible, time_from, time_to, capacity,
                     vehicle, taxi_booked, bags, stops, team_up, time_window)
  values (p_kind, left(trim(p_from), 40), left(trim(p_to), 40), p_date, p_time, coalesce(p_flexible, false),
          case when p_flexible then p_time_from end, case when p_flexible then p_time_to end,
          case when p_kind = 'offer' then p_seats + 1 + v_extra else p_seats end,
          coalesce(p_vehicle, 'taxi'), coalesce(p_taxi_booked, true), greatest(0, least(coalesce(p_bags, 0), 10)),
          nullif(left(trim(coalesce(p_stops, '')), 120), ''),
          p_kind = 'request' and coalesce(p_team_up, true), p_window)
  returning id into v_trip;

  insert into trip_members (trip_id, name, notes, extra)
  values (v_trip, left(trim(p_name), 40), nullif(left(trim(coalesce(p_notes, '')), 120), ''), v_extra)
  returning id into v_member;
  update trips set host_member = v_member where id = v_trip;

  insert into trip_member_private (member_id, phone) values (v_member, p_phone)
  returning token into v_token;

  return json_build_object('trip_id', v_trip, 'member_id', v_member, 'token', v_token);
end $$;

-- Join a trip with seats on offer (p_pickup = "only part of the way", e.g. "till Mandi")
create or replace function join_trip(p_trip uuid, p_name text, p_notes text default null, p_phone text default null,
                                     p_pickup text default null, p_extra int default 0)
returns json language plpgsql security definer set search_path = public as $$
declare
  v_status text;
  v_capacity int;
  v_kind text;
  v_date date;
  v_count int;
  v_member uuid;
  v_token uuid;
begin
  if coalesce(trim(p_name), '') = '' then raise exception 'name_required'; end if;
  if coalesce(p_phone, '') !~ '^[0-9]{11,15}$' then raise exception 'phone_required'; end if;
  if coalesce(p_extra, 0) < 0 or coalesce(p_extra, 0) > 10 then raise exception 'bad_capacity'; end if;
  select status, capacity, kind, trip_date into v_status, v_capacity, v_kind, v_date from trips where id = p_trip for update;
  if v_status is null or v_status = 'cancelled' then raise exception 'not_found'; end if;
  if exists (select 1 from trip_members m join trip_member_private k on k.member_id = m.id join trips t on t.id = m.trip_id
              where k.phone = p_phone and m.left_at is null and t.status <> 'cancelled' and t.trip_date = v_date) then
    raise exception 'one_plan_a_day';
  end if;
  select coalesce(sum(1 + extra), 0) into v_count from trip_members where trip_id = p_trip and left_at is null;
  -- a plan to share a taxi can take anyone who wants to share it (up to a full Bolero); seats on offer can fill up
  if v_kind = 'request' then
    if v_count + 1 + coalesce(p_extra, 0) > 12 then raise exception 'cab_full'; end if;
  else
    if v_status <> 'open' then raise exception 'cab_full'; end if;
    if v_count + 1 + coalesce(p_extra, 0) > v_capacity then raise exception 'cab_full'; end if;
  end if;

  insert into trip_members (trip_id, name, notes, pickup, extra)
  values (p_trip, left(trim(p_name), 40), nullif(left(trim(coalesce(p_notes, '')), 120), ''),
          nullif(left(trim(coalesce(p_pickup, '')), 40), ''), coalesce(p_extra, 0))
  returning id into v_member;

  insert into trip_member_private (member_id, phone) values (v_member, p_phone)
  returning token into v_token;

  if v_kind <> 'request' and v_count + 1 + coalesce(p_extra, 0) >= v_capacity then update trips set status = 'full' where id = p_trip; end if;
  return json_build_object('trip_id', p_trip, 'member_id', v_member, 'token', v_token);
end $$;

create or replace function leave_trip(p_member uuid, p_token uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_trip uuid;
  v_capacity int;
  v_remaining int;
begin
  select m.trip_id into v_trip
    from trip_members m join trip_member_private k on k.member_id = m.id
   where m.id = p_member and k.token = p_token and m.left_at is null;
  if v_trip is null then raise exception 'not_member'; end if;

  select capacity into v_capacity from trips where id = v_trip for update;
  update trip_members set left_at = now() where id = p_member;
  select coalesce(sum(1 + extra), 0) into v_remaining from trip_members where trip_id = v_trip and left_at is null;
  if v_remaining = 0 then
    update trips set status = 'cancelled' where id = v_trip;
  elsif v_remaining < v_capacity then
    update trips set status = 'open' where id = v_trip and status = 'full';
  end if;
end $$;

-- The host takes someone off their trip
create or replace function remove_trip_member(p_host uuid, p_token uuid, p_member uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_trip uuid;
  v_capacity int;
  v_remaining int;
begin
  select t.id, t.capacity into v_trip, v_capacity
    from trips t join trip_member_private k on k.member_id = t.host_member
   where t.host_member = p_host and k.token = p_token
     and t.id = (select trip_id from trip_members where id = p_member)
   for update of t;
  if v_trip is null then raise exception 'not_owner'; end if;
  if p_member = p_host then raise exception 'not_owner'; end if;
  update trip_members set left_at = now(), removed = true where id = p_member and trip_id = v_trip and left_at is null;
  select coalesce(sum(1 + extra), 0) into v_remaining from trip_members where trip_id = v_trip and left_at is null;
  if v_remaining < v_capacity then update trips set status = 'open' where id = v_trip and status = 'full'; end if;
end $$;

-- Numbers inside the same trip
create or replace function get_trip_contacts(p_member uuid, p_token uuid)
returns table (member_id uuid, phone text) language sql stable security definer set search_path = public as $$
  select m.id, k.phone
    from trip_members m join trip_member_private k on k.member_id = m.id
   where m.left_at is null
     and m.trip_id = (
       select me.trip_id
         from trip_members me join trip_member_private mk on mk.member_id = me.id
        where me.id = p_member and mk.token = p_token and me.left_at is null);
$$;

-- Numbers are swapped only by joining a plan (get_trip_contacts). This older call is kept so pages from older
-- versions still work, but it no longer shares anything.
create or replace function get_match_contacts(p_member uuid, p_token uuid)
returns table (trip_id uuid, member_id uuid, phone text) language sql stable security definer set search_path = public as $$
  select null::uuid, null::uuid, null::text where false;
$$;

create or replace function set_trip_phone(p_member uuid, p_token uuid, p_phone text)
returns void language plpgsql security definer set search_path = public as $$
begin
  update trip_member_private
     set phone = case when p_phone ~ '^[0-9]{11,15}$' then p_phone end
   where member_id = p_member and token = p_token;
  if not found then raise exception 'not_member'; end if;
end $$;


-- ============ WEATHER REPORTS, FEEDBACK, USAGE COUNTS ============

-- A report needs a name and a WhatsApp number. The number is never shown: it only limits one number to 3 reports an hour.
drop function if exists report_sky(text, text, text);
create or replace function report_sky(p_spot text, p_state text, p_name text, p_phone text)
returns void language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if p_spot not in ('launch', 'landing') or p_state not in ('clear', 'cloudy', 'fog') then raise exception 'bad_report'; end if;
  if length(trim(coalesce(p_name, ''))) = 0 or coalesce(p_phone, '') !~ '^[0-9]{11,15}$' then raise exception 'need_details'; end if;
  if (select count(*) from sky_report_private where phone = p_phone and created_at > now() - interval '1 hour') >= 3 then
    raise exception 'too_many_reports';
  end if;
  perform rideup_rate_limit('sky_reports', 20);
  insert into sky_reports (spot, state, name) values (p_spot, p_state, left(trim(p_name), 40)) returning id into v_id;
  insert into sky_report_private (report_id, phone) values (v_id, p_phone);
end $$;

create or replace function send_feedback(p_message text, p_contact text default null, p_name text default null,
  p_phone text default null, p_topic text default null, p_stage text default null, p_version text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if length(trim(coalesce(p_message, ''))) < 2 then raise exception 'empty_message'; end if;
  perform rideup_rate_limit('feedback', 5);
  insert into feedback (message, contact, name, phone, topic, stage, version)
  values (left(trim(p_message), 2000), nullif(left(trim(coalesce(p_contact, '')), 120), ''),
          nullif(left(trim(coalesce(p_name, '')), 40), ''),
          case when p_phone ~ '^[0-9]{11,15}$' then p_phone end,
          nullif(left(trim(coalesce(p_topic, '')), 40), ''), left(p_stage, 30), left(p_version, 20));
end $$;

-- Ratings: a batch of { topic, score 0–100, comment } (at most 10 batches a minute across the app)
create or replace function submit_review(p_stage text, p_version text, p_items jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_batch uuid := gen_random_uuid();
  v_item jsonb;
begin
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 or jsonb_array_length(p_items) > 20 then raise exception 'bad_review'; end if;
  if (select count(distinct batch) from review_feedback where created_at > now() - interval '1 minute') >= 10 then raise exception 'slow_down'; end if;
  for v_item in select * from jsonb_array_elements(p_items) loop
    if coalesce(v_item->>'topic', '') !~ '^[a-z_]{2,20}$' then continue; end if;
    if v_item->>'score' is null and coalesce(trim(v_item->>'comment'), '') = '' then continue; end if;
    insert into review_feedback (batch, stage, version, topic, score, comment)
    values (v_batch, left(p_stage, 20), left(p_version, 12), v_item->>'topic',
            case when v_item->>'score' ~ '^[0-9]{1,3}$' then least(100, (v_item->>'score')::int) end,
            nullif(left(trim(coalesce(v_item->>'comment', '')), 1000), ''));
  end loop;
end $$;

-- Anonymous usage counts and error reports (at most 600 a minute across the app; nothing personal)
create or replace function log_event(p_event text, p_detail text default null, p_version text default null, p_stage text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_event is null or p_event !~ '^[a-z_]{2,30}$' then return; end if;
  if (select count(*) from usage_events where created_at > now() - interval '1 minute') >= 600 then return; end if;
  insert into usage_events (event, detail, version, stage)
  values (p_event, left(p_detail, case when p_event = 'js_error' then 300 else 40 end), left(p_version, 12), left(p_stage, 20));
end $$;


-- ============ WHO MAY CALL WHAT ============
-- Every function the app calls is open to "anon" (each checks its own token / limits inside).
-- Nothing is open to "authenticated" (there are no logins) or to everyone by default; helpers stay closed.
do $$
declare f record;
begin
  for f in select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' loop
    execute format('revoke all on function %s from public, anon, authenticated', f.sig);
  end loop;
  for f in select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.proname = any (array['start_cab', 'join_cab', 'leave_cab', 'mark_departed',
              'undo_departed', 'reopen_cab', 'get_cab_contacts', 'set_cab_phone', 'set_cab_flexible', 'set_cab_car',
              'set_my_note', 'set_my_friends', 'set_lift', 'add_plan', 'remove_plan', 'create_trip', 'join_trip',
              'leave_trip', 'remove_trip_member', 'get_trip_contacts', 'get_match_contacts', 'set_trip_phone',
              'report_sky', 'send_feedback', 'submit_review', 'log_event']) loop
    execute format('grant execute on function %s to anon', f.sig);
  end loop;
end $$;
alter default privileges in schema public revoke execute on functions from public;


-- ============ LIVE UPDATES ============
-- The app listens for changes to these tables, so seats fill up live on everyone's phone.
do $$
declare t text;
begin
  foreach t in array array['cab_sessions', 'cab_passengers', 'flight_plans', 'trips', 'trip_members', 'sky_reports'] loop
    begin
      execute format('alter publication supabase_realtime add table %I', t);
    exception when duplicate_object then null;
    end;
  end loop;
end $$;


-- ============ AUTOMATIC TIDY-UP ============
-- Runs every hour with pg_cron where it's available. Without it, the tidy-up still runs whenever someone
-- starts a ride or posts a trip.
do $$
begin
  execute 'create extension if not exists pg_cron';
  perform cron.unschedule(jobid) from cron.job where jobname = 'rideup-cleanup';
  perform cron.schedule('rideup-cleanup', '17 * * * *', 'select public.rideup_cleanup()');
exception when others then
  raise notice 'pg_cron not available: the tidy-up runs on new rides and trips instead';
end $$;


-- ============ INSIGHTS (for the people looking after Ride Up) ============
-- Read-only summaries for the weekly check (see MAINTENANCE.md). Not reachable from the app.
create schema if not exists insights;

create or replace view insights.feedback_week as
  select created_at, message, contact, topic, name, phone, stage, version
    from public.feedback where created_at > now() - interval '7 days' order by created_at desc;

create or replace view insights.ratings_by_topic as
  select version, stage, topic, count(*) as answers, round(avg(score)) as avg_score,
         count(*) filter (where score >= 67) as thumbs_up, count(*) filter (where score < 33) as thumbs_down,
         count(comment) as comments
    from public.review_feedback group by version, stage, topic order by version desc, topic;

create or replace view insights.review_comments_week as
  select created_at, stage, version, topic, score, comment
    from public.review_feedback where comment is not null and created_at > now() - interval '7 days'
   order by created_at desc;

create or replace view insights.usage_daily as
  select created_at::date as day, event, coalesce(detail, '') as detail, stage, count(*) as times
    from public.usage_events
   where created_at > now() - interval '30 days' and event <> 'js_error'
   group by 1, 2, 3, 4 order by 1 desc, 5 desc;

create or replace view insights.errors_recent as
  select detail as error, version, count(*) as times, max(created_at) as last_seen
    from public.usage_events
   where event = 'js_error' and created_at > now() - interval '14 days'
   group by detail, version order by count(*) desc;

revoke all on schema insights from public, anon, authenticated;
revoke all on all tables in schema insights from public, anon, authenticated;

notify pgrst, 'reload schema';
