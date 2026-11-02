-- Display names are unique with case: "Khang" and "khang" are two different names.
-- Safe to run more than once. Run this check first, it must return no rows:
--   select display_name, count(*) from public.profiles group by 1 having count(*) > 1;
drop index if exists public.profiles_display_name_unique;
create unique index profiles_display_name_unique
	on public.profiles (display_name);

-- Lets the sign-up form tell a taken name apart from other errors before the account exists.
-- The unique index still has the last word if two players pick the same name at once.
create or replace function public.display_name_available(wanted_name text) returns boolean
language sql stable security definer set search_path = '' as $$
	select not exists (
		select 1 from public.profiles p where p.display_name = btrim(wanted_name)
	);
$$;
revoke all on function public.display_name_available(text) from public;
grant execute on function public.display_name_available(text) to anon, authenticated;