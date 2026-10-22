-- Endless War backend, first migration. Safe to run more than once.
-- Run it in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
--
-- Access model: every table has row level security on and only the grants below.
-- The client only holds the publishable key, so these rules are the real protection.

-- ---------------------------------------------------------------- profiles
-- One row per account, created by a trigger when the account is created.

create table if not exists public.profiles (
	user_id uuid primary key references auth.users (id) on delete cascade,
	display_name text not null check (char_length(display_name) between 3 and 16),
	created_at timestamptz not null default now(),
	updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
	for select to authenticated
	using ((select auth.uid()) = user_id);

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
	for update to authenticated
	using ((select auth.uid()) = user_id)
	with check ((select auth.uid()) = user_id);

-- No insert or delete policy: rows come from the trigger and leave with the account.
revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant update (display_name) on public.profiles to authenticated;

create or replace function public.touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
	new.updated_at := now();
	return new;
end $$;

drop trigger if exists profiles_touch on public.profiles;
create trigger profiles_touch before update on public.profiles
	for each row execute function public.touch_updated_at();

-- The client sends the display name as sign-up metadata.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
	name text := btrim(coalesce(new.raw_user_meta_data ->> 'display_name', ''));
begin
	if char_length(name) not between 3 and 16 then
		raise exception 'display_name must be 3 to 16 characters';
	end if;
	insert into public.profiles (user_id, display_name) values (new.id, name);
	return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
	for each row execute function public.handle_new_user();

-- ------------------------------------------------------------- leaderboard
-- One row per account: the best run for the game version it was played on.
-- Anyone can read it (it is a public ranking), only the owner can write their own row.

create table if not exists public.leaderboard (
	user_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
	display_name text not null,
	-- The ceiling of 100 is the server-side sanity limit, raise it here if the game allows more.
	waves_cleared int not null check (waves_cleared between 0 and 100),
	run_elapsed double precision not null,
	run_seed bigint not null,
	game_version text not null check (char_length(game_version) between 1 and 32),
	submitted_at timestamptz not null default now(),
	-- Cheap anti-cheat: a wave cannot be cleared faster than 15 s of game time.
	constraint leaderboard_min_time check (run_elapsed >= 15 * waves_cleared)
);

create index if not exists leaderboard_rank_idx
	on public.leaderboard (game_version, waves_cleared desc, run_elapsed asc, submitted_at asc);

alter table public.leaderboard enable row level security;

drop policy if exists leaderboard_select_all on public.leaderboard;
create policy leaderboard_select_all on public.leaderboard
	for select to anon, authenticated
	using (true);

drop policy if exists leaderboard_insert_own on public.leaderboard;
create policy leaderboard_insert_own on public.leaderboard
	for insert to authenticated
	with check ((select auth.uid()) = user_id);

drop policy if exists leaderboard_update_own on public.leaderboard;
create policy leaderboard_update_own on public.leaderboard
	for update to authenticated
	using ((select auth.uid()) = user_id)
	with check ((select auth.uid()) = user_id);

-- user_id, display_name and submitted_at are never taken from the client.
revoke all on public.leaderboard from anon, authenticated;
grant select on public.leaderboard to anon, authenticated;
grant insert (waves_cleared, run_elapsed, run_seed, game_version) on public.leaderboard to authenticated;
grant update (waves_cleared, run_elapsed, run_seed, game_version) on public.leaderboard to authenticated;

create or replace function public.leaderboard_before_write() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
	-- A run that is not better than the stored one on the same version is ignored.
	if tg_op = 'UPDATE' and new.game_version = old.game_version and (
		new.waves_cleared < old.waves_cleared
		or (new.waves_cleared = old.waves_cleared and new.run_elapsed >= old.run_elapsed)
	) then
		return old;
	end if;
	select p.display_name into new.display_name
		from public.profiles p where p.user_id = new.user_id;
	-- The server clock breaks ties, never the client's.
	new.submitted_at := now();
	return new;
end $$;

drop trigger if exists leaderboard_write on public.leaderboard;
create trigger leaderboard_write before insert or update on public.leaderboard
	for each row execute function public.leaderboard_before_write();

-- ------------------------------------------------------------ account delete
-- Lets a player remove their own account, and lets tests clean up after themselves.

create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = '' as $$
begin
	if auth.uid() is null then
		raise exception 'not signed in';
	end if;
	delete from auth.users where id = auth.uid();
end $$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
