begin;

create table if not exists public.saves (
	user_id uuid primary key references auth.users(id) on delete cascade,
	revision int not null default 0,
	device_id text,
	data jsonb not null,
	updated_at timestamptz not null default now(),
	created_at timestamptz not null default now()
);

alter table public.saves enable row level security;
drop policy if exists saves_select_own on public.saves;
create policy saves_select_own on public.saves for select to authenticated
	using ((select auth.uid()) = user_id);
drop policy if exists saves_insert_own on public.saves;
create policy saves_insert_own on public.saves for insert to authenticated
	with check ((select auth.uid()) = user_id);
drop policy if exists saves_update_own on public.saves;
create policy saves_update_own on public.saves for update to authenticated
	using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

revoke all on public.saves from anon, authenticated;
grant select on public.saves to authenticated;
grant insert (user_id, revision, device_id, data) on public.saves to authenticated;
grant update (revision, device_id, data) on public.saves to authenticated;

create or replace function public.saves_before_write() returns trigger
language plpgsql set search_path = '' as $$
begin
	if tg_op = 'UPDATE' and new.revision <= old.revision then
		raise exception using errcode = 'PT409', message = 'stale_revision';
	end if;
	new.updated_at := now();
	return new;
end $$;

drop trigger if exists saves_write on public.saves;
create trigger saves_write before insert or update on public.saves
	for each row execute function public.saves_before_write();

commit;
