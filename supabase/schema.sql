-- Run this whole file once in Supabase: SQL Editor -> New query -> Run.
-- 1) CHANGE 'youruni.edu' below (2 places) and the admin emails at the bottom.

create or replace function public.is_university_email(e text) returns boolean
language sql immutable as $$ select lower(e) like '%@youruni.edu' or lower(e) like '%.youruni.edu' $$;

create table public.admins (email text primary key);

create or replace function public.is_admin() returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from public.admins where lower(email) = lower(auth.jwt() ->> 'email'))
$$;

create table public.requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid(),
  name text not null, student_id text not null, email text not null,
  trimester text not null check (trimester in ('Autumn 2026','Winter 2027','Spring 2027')),
  course text not null, supervisor text not null,
  material text not null check (material in ('PLA','ABS','PETG','TPU','PA','Composites (GF/CF)','Multi-material','Other')),
  material_specify text,
  time_est text not null, consumption text not null,
  request_form_path text not null, slicing_file_path text not null,
  status text not null default 'Pending' check (status in ('Pending','Approved','Rejected','More Info')),
  admin_note text, decided_at timestamptz,
  created_at timestamptz not null default now()
);
create table public.printers (
  id uuid primary key default gen_random_uuid(),
  brand text not null, model text not null, serial text not null,
  status text not null default 'Available' check (status in ('Available','Occupied','Under Maintenance','Not Functional'))
);

alter table public.requests enable row level security;
alter table public.printers enable row level security;
alter table public.admins enable row level security;

-- Students: may only add a request for themselves, with their verified university email
create policy "student insert" on public.requests for insert to authenticated
  with check (user_id = auth.uid() and lower(email) = lower(auth.jwt() ->> 'email')
              and public.is_university_email(email) and status = 'Pending');
create policy "read own or admin" on public.requests for select to authenticated
  using (user_id = auth.uid() or public.is_admin());
create policy "admin update" on public.requests for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy "admin printers" on public.printers for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Private file storage
insert into storage.buckets (id, name, public) values ('files', 'files', false) on conflict do nothing;
create policy "upload own folder" on storage.objects for insert to authenticated
  with check (bucket_id = 'files' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "read own or admin" on storage.objects for select to authenticated
  using (bucket_id = 'files' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));

-- 2) CHANGE: your admin staff emails
insert into public.admins (email) values ('admin1@youruni.edu'), ('admin2@youruni.edu');
