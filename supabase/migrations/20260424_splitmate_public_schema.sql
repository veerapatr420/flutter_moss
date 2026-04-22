-- Splitmate: Public schema + storage policies for School Project (No Auth required)
-- Run this in Supabase SQL Editor once.

create extension if not exists pgcrypto;

-- 1. Create bills table
create table if not exists public.bills (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  total_amount numeric(12, 2) not null check (total_amount > 0),
  image_url text,
  created_at timestamptz not null default timezone('utc', now())
);

-- 2. Create participants table
create table if not exists public.participants (
  id uuid primary key default gen_random_uuid(),
  bill_id uuid not null references public.bills(id) on delete cascade,
  name text not null,
  amount_owed numeric(12, 2) not null check (amount_owed >= 0),
  created_at timestamptz not null default timezone('utc', now())
);

-- Indices
create index if not exists idx_bills_created_at
  on public.bills (created_at desc);

create index if not exists idx_participants_bill_id
  on public.participants (bill_id);

-- Enable RLS but allow ALL for anon/authenticated (Public Access)
alter table public.bills enable row level security;
alter table public.participants enable row level security;

drop policy if exists "bills_public_access" on public.bills;
create policy "bills_public_access"
on public.bills
for all
using (true)
with check (true);

drop policy if exists "participants_public_access" on public.participants;
create policy "participants_public_access"
on public.participants
for all
using (true)
with check (true);

-- 3. Storage bucket setup
insert into storage.buckets (id, name, public)
values ('receipts', 'receipts', true)
on conflict (id) do update set public = true;

-- Storage Policy allowing all uploads
drop policy if exists "receipts_public_access" on storage.objects;
create policy "receipts_public_access"
on storage.objects
for all
using (bucket_id = 'receipts')
with check (bucket_id = 'receipts');