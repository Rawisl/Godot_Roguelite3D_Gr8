-- Display names are stored trimmed, and the ranking follows a rename.
-- Safe to run more than once.

create or replace function public.profiles_normalize() returns trigger
language plpgsql set search_path = '' as $$
begin
	new.display_name := btrim(new.display_name);
	return new;
end $$;

drop trigger if exists profiles_normalize on public.profiles;
create trigger profiles_normalize before insert or update of display_name on public.profiles
	for each row execute function public.profiles_normalize();

-- Copies a new name to the ranking row. The ranking trigger lets it through because the score is unchanged.
create or replace function public.profiles_sync_ranking() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
	update public.leaderboard set display_name = new.display_name where user_id = new.user_id;
	return new;
end $$;

drop trigger if exists profiles_sync_ranking on public.profiles;
create trigger profiles_sync_ranking after update of display_name on public.profiles
	for each row when (old.display_name is distinct from new.display_name)
	execute function public.profiles_sync_ranking();

create or replace function public.leaderboard_before_write() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
	if tg_op = 'UPDATE' then
		-- Same score on the same version: only the name is being synced, keep the rank time.
		if new.game_version = old.game_version
			and new.waves_cleared = old.waves_cleared
			and new.run_elapsed = old.run_elapsed
			and new.run_seed = old.run_seed then
			new.submitted_at := old.submitted_at;
			return new;
		end if;
		-- A run that is not better than the stored one on the same version is ignored.
		if new.game_version = old.game_version and (
			new.waves_cleared < old.waves_cleared
			or (new.waves_cleared = old.waves_cleared and new.run_elapsed >= old.run_elapsed)
		) then
			return old;
		end if;
	end if;
	select p.display_name into new.display_name
		from public.profiles p where p.user_id = new.user_id;
	-- The server clock breaks ties, never the client's.
	new.submitted_at := now();
	return new;
end $$;
