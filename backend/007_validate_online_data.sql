begin;

create or replace function public.save_data_valid(payload jsonb) returns boolean
language plpgsql immutable strict set search_path = '' as $$
declare
	section text;
	field text;
	levels jsonb;
	limits constant jsonb := '{"FORT_HP":5,"GOLD_PCT":4,"CMD_HP":3,"EMG_REPAIR":3}';
begin
	-- Bound request storage without imposing a gameplay cap on lifetime progression.
	if jsonb_typeof(payload) <> 'object' or octet_length(payload::text) > 1048576 then
		return false;
	end if;
	if exists (select 1 from jsonb_object_keys(payload) k where k not in ('profile', 'meta', 'flags')) then
		return false;
	end if;
	foreach section in array array['profile', 'meta', 'flags'] loop
		if payload ? section and jsonb_typeof(payload -> section) <> 'object' then
			return false;
		end if;
	end loop;
	-- Persisted progression numbers are nonnegative integer counts supported by Godot int.
	if exists (
		select 1 from jsonb_path_query(payload, '$.** ? (@.type() == "number")') value
		where (value #>> '{}')::numeric < 0
			or (value #>> '{}')::numeric > 9223372036854775807
			or trunc((value #>> '{}')::numeric) <> (value #>> '{}')::numeric
	) then
		return false;
	end if;
	foreach field in array array['prestige_balance', 'max_wave_cleared'] loop
		if payload -> 'profile' ? field and jsonb_typeof(payload -> 'profile' -> field) <> 'number' then
			return false;
		end if;
	end loop;
	foreach field in array array['stats', 'best_by_start'] loop
		if payload -> 'profile' ? field and jsonb_typeof(payload -> 'profile' -> field) <> 'object' then
			return false;
		end if;
		if exists (select 1 from jsonb_each(coalesce(payload -> 'profile' -> field, '{}'::jsonb)) e
			where jsonb_typeof(e.value) <> 'number') then
			return false;
		end if;
	end loop;
	levels := payload -> 'meta' -> 'levels';
	if levels is not null then
		if jsonb_typeof(levels) <> 'object' then
			return false;
		end if;
		if exists (select 1 from jsonb_each(levels) e where jsonb_typeof(e.value) <> 'number') then
			return false;
		end if;
		for field in select jsonb_object_keys(limits) loop
			if levels ? field and (levels ->> field)::numeric > (limits ->> field)::numeric then
				return false;
			end if;
		end loop;
	end if;
	if payload -> 'flags' ? 'tutorial_done'
		and jsonb_typeof(payload -> 'flags' -> 'tutorial_done') <> 'boolean' then
		return false;
	end if;
	return true;
end $$;

revoke all on function public.save_data_valid(jsonb) from public;
grant execute on function public.save_data_valid(jsonb) to authenticated;

alter table public.saves drop constraint if exists saves_revision_nonnegative;
alter table public.saves add constraint saves_revision_nonnegative check (revision >= 0) not valid;
alter table public.saves drop constraint if exists saves_data_valid;
alter table public.saves add constraint saves_data_valid check (public.save_data_valid(data)) not valid;

alter table public.leaderboard drop constraint if exists leaderboard_elapsed_nonnegative;
alter table public.leaderboard add constraint leaderboard_elapsed_nonnegative
	check (run_elapsed >= 0 and run_elapsed < 'Infinity'::double precision) not valid;

commit;
