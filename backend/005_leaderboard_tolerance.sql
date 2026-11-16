begin;

alter table public.leaderboard drop constraint if exists leaderboard_min_time;
alter table public.leaderboard add constraint leaderboard_min_time
	check (run_elapsed + 1 >= 15 * waves_cleared);

create or replace function public.leaderboard_top(version text, top_n int)
returns table(rank bigint, display_name text, waves_cleared int, run_elapsed double precision)
language sql stable security definer set search_path = '' as $$
	select row_number() over (order by l.waves_cleared desc, l.run_elapsed, l.submitted_at, l.user_id),
		l.display_name, l.waves_cleared, l.run_elapsed
	from public.leaderboard l
	where l.game_version = version
	order by l.waves_cleared desc, l.run_elapsed, l.submitted_at, l.user_id
	limit greatest(0, least(coalesce(top_n, 50), 50));
$$;

create or replace function public.leaderboard_my_rank(version text)
returns table(rank bigint, display_name text, waves_cleared int, run_elapsed double precision)
language sql stable security definer set search_path = '' as $$
	select ranked.rank, ranked.display_name, ranked.waves_cleared, ranked.run_elapsed
	from (
		select row_number() over (order by l.waves_cleared desc, l.run_elapsed, l.submitted_at, l.user_id) as rank,
			l.user_id, l.display_name, l.waves_cleared, l.run_elapsed
		from public.leaderboard l where l.game_version = version
	) ranked where ranked.user_id = (select auth.uid());
$$;

revoke all on function public.leaderboard_top(text, int) from public;
revoke all on function public.leaderboard_my_rank(text) from public;
grant execute on function public.leaderboard_top(text, int) to anon, authenticated;
grant execute on function public.leaderboard_my_rank(text) to anon, authenticated;

commit;
