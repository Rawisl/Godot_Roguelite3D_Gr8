-- Display names are measured after trimming, so a name made of spaces is refused.
-- Safe to run more than once.

alter table public.profiles drop constraint if exists profiles_display_name_check;
alter table public.profiles add constraint profiles_display_name_check
	check (char_length(btrim(display_name)) between 3 and 16);
