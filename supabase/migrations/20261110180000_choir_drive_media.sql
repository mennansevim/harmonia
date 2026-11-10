-- CHOIR-B2/B3: Drive connection, media, repertoire/library/assignments.
--
-- Bytes live in the choir's Google Drive. A media row is the only handle the
-- app ever gets; the Drive file id never leaves the server (no client
-- policy exposes drive_file_id). Edge Functions upload and serve bytes after
-- can_read_media()/can_upload_media() say yes.

create type media_kind as enum ('repertoire', 'take', 'voice_note');
create type media_status as enum ('pending', 'ready');
create type item_kind as enum ('reference', 'resource', 'assignment');

-- One Drive account per choir. The refresh token sits in Vault; only the
-- service role reads this table.
create table choir_drive (
  choir_id uuid primary key references choirs (id) on delete cascade,
  google_email text not null,
  token_secret_id uuid not null,
  root_folder_id text not null,
  folders jsonb not null default '{}',
  connected_by uuid not null references auth.users (id),
  connected_at timestamptz not null default now()
);
alter table choir_drive enable row level security;
-- No policies: clients read the status through drive_status().

create table media (
  id uuid primary key default gen_random_uuid(),
  choir_id uuid not null references choirs (id) on delete cascade,
  kind media_kind not null,
  owner_id uuid not null references auth.users (id) on delete cascade,
  ext text not null check (ext ~ '^[a-z0-9]{1,5}$'),
  mime text not null,
  size_bytes bigint not null check (size_bytes > 0 and size_bytes <= 200 * 1024 * 1024),
  status media_status not null default 'pending',
  drive_file_id text,
  created_at timestamptz not null default now(),
  check (status = 'pending' or drive_file_id is not null)
);
alter table media enable row level security;
-- Column grant: the Drive file id is not readable by clients.
revoke select on media from anon, authenticated;
grant select (id, choir_id, kind, owner_id, ext, mime, size_bytes, status, created_at)
  on media to authenticated;
create policy media_read on media for select using (is_member(choir_id));

-- Repertoire references, library items and assignments, as the app's own
-- JSON (ReferenceAsset, ChoirResource, Assignment). The conductor writes.
create table choir_items (
  choir_id uuid not null references choirs (id) on delete cascade,
  kind item_kind not null,
  id text not null check (length(id) between 1 and 80),
  body jsonb not null,
  media_id uuid references media (id) on delete set null,
  updated_by uuid not null references auth.users (id),
  updated_at timestamptz not null default now(),
  primary key (choir_id, kind, id)
);
alter table choir_items enable row level security;
create policy choir_items_read on choir_items for select using (is_member(choir_id));

alter table submissions add column take_kind text
  check (take_kind is null or take_kind in ('accompaniedMix', 'unaccompanied', 'imported'));

-- ---------------------------------------------------------------- rules

-- Who may start an upload of this kind (the Edge Function asks).
create function can_upload_media(c uuid, k media_kind) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare
  me members;
begin
  me := my_member(c);
  if me.user_id is null then return false; end if;
  return case k
    when 'repertoire' then me.role = 'conductor'
    when 'take' then me.role = 'singer' and me.part is not null
    when 'voice_note' then me.role = 'conductor' or me.leads_part
  end;
end $$;

-- Who may hear or open these bytes.
create function can_read_media(m uuid) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare
  row media;
begin
  select * into row from media where id = m and status = 'ready';
  if not found or not is_member(row.choir_id) then return false; end if;
  if row.owner_id = auth.uid() then return true; end if;
  case row.kind
    when 'repertoire' then
      return true;
    when 'take' then
      return exists (select 1 from submissions s
                     where s.recording_file_id = m::text and can_listen(s.id));
    when 'voice_note' then
      return exists (select 1 from feedback f
                     where f.voice_note_file_id = m::text
                       and can_read_feedback(f.submission_id));
  end case;
  return false;
end $$;

-- A ready file of this kind that the caller uploaded to this choir.
create function _own_ready_media(c uuid, m text, k media_kind) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from media
                 where id::text = m and choir_id = c and kind = k
                   and owner_id = auth.uid() and status = 'ready')
$$;

create function drive_status(c uuid)
returns table (connected boolean, google_email text, connected_at timestamptz)
language sql stable security definer set search_path = public as $$
  select d.choir_id is not null,
         case when is_conductor(c) then d.google_email end,
         d.connected_at
    from (select 1) one
    left join choir_drive d on d.choir_id = c
   where is_member(c)
$$;

-- ---------------------------------------------------------------- items

create function put_item(c uuid, k item_kind, item_id text, item jsonb,
                         m uuid default null) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_conductor(c) then raise exception 'only the conductor edits'; end if;
  if item ->> 'id' is distinct from item_id
     or item ->> 'choirId' is distinct from c::text then
    raise exception 'item does not match';
  end if;
  if m is not null and not _own_ready_media(c, m::text, 'repertoire') then
    raise exception 'no such file';
  end if;
  -- An assignment may only point at this choir's repertoire.
  if k = 'assignment' and exists (
       select 1 from jsonb_array_elements(item -> 'pieces') p
        where p ->> 'midiReferenceId' is not null
          and not exists (select 1 from choir_items r
                          where r.choir_id = c and r.kind = 'reference'
                            and r.id = p ->> 'midiReferenceId')) then
    raise exception 'unknown reference';
  end if;
  insert into choir_items (choir_id, kind, id, body, media_id, updated_by)
    values (c, k, item_id, item, m, auth.uid())
  on conflict (choir_id, kind, id) do update
    set body = excluded.body, media_id = excluded.media_id,
        updated_by = excluded.updated_by, updated_at = now();
end $$;

create function delete_item(c uuid, k item_kind, item_id text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_conductor(c) then raise exception 'only the conductor edits'; end if;
  delete from choir_items where choir_id = c and kind = k and id = item_id;
end $$;

-- ---------------------------------------------------------------- takes v2
-- The recording must be the caller's own ready take in this choir.

drop function submit_take(uuid, text, text, text, int);
create function submit_take(
  c uuid, assignment text, piece text, file_id text, duration int,
  sung text default 'accompaniedMix'
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  me members;
  s submissions;
begin
  me := my_member(c);
  if me.user_id is null or me.role <> 'singer' or me.part is null then
    raise exception 'only a singer with a part sends takes';
  end if;
  if duration is null or duration <= 0 or not _own_ready_media(c, file_id, 'take') then
    raise exception 'take needs a recording';
  end if;
  if not exists (select 1 from choir_items
                 where choir_id = c and kind = 'assignment' and id = assignment) then
    raise exception 'no such assignment';
  end if;
  select * into s from submissions
   where choir_id = c and assignment_id = assignment and piece_id = piece
     and member_id = auth.uid() for update;
  if not found then
    insert into submissions (choir_id, assignment_id, piece_id, member_id, part, status,
                             recording_file_id, duration_ms, submitted_at, take_kind)
      values (c, assignment, piece, auth.uid(), me.part, 'submitted', file_id, duration,
              now(), sung)
      returning * into s;
  elsif s.status in ('draft', 'revisionRequested') then
    update submissions
       set status = 'submitted', part = me.part, recording_file_id = file_id,
           duration_ms = duration, submitted_at = now(), listened_at = null,
           forwarded_at = null, take_kind = sung,
           attempt = case when s.status = 'revisionRequested' then s.attempt + 1
                          else s.attempt end
     where id = s.id returning * into s;
  else
    raise exception 'take already sent';
  end if;
  return s.id;
end $$;

-- Voice notes in feedback must be the author's own ready voice_note file.
create or replace function _add_feedback(s submissions, body text, tag_list text[],
                                         mark_list jsonb, voice text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if voice is not null and not _own_ready_media(s.choir_id, voice, 'voice_note') then
    raise exception 'no such file';
  end if;
  if length(trim(coalesce(body, ''))) > 0 or cardinality(tag_list) > 0
     or jsonb_array_length(mark_list) > 0 or voice is not null then
    insert into feedback (submission_id, choir_id, author_id, attempt, text, tags,
                          marks, voice_note_file_id)
      values (s.id, s.choir_id, auth.uid(), s.attempt, coalesce(body, ''), tag_list,
              mark_list, voice);
  end if;
end $$;

revoke execute on all functions in schema public from public, anon;
grant execute on all functions in schema public to authenticated;
revoke execute on function _add_feedback, _own_ready_media from authenticated;

-- ---------------------------------------------------------------- server only
-- The Edge Functions (service role) keep the Drive token in Vault.

create function _store_drive(c uuid, email text, refresh text, root text,
                             f jsonb, by_user uuid) returns void
language plpgsql security definer set search_path = public, vault as $$
declare
  sid uuid;
begin
  select token_secret_id into sid from choir_drive where choir_id = c;
  if sid is null then
    sid := vault.create_secret(refresh, 'drive-' || c::text);
  else
    perform vault.update_secret(sid, refresh);
  end if;
  insert into choir_drive (choir_id, google_email, token_secret_id, root_folder_id,
                           folders, connected_by)
    values (c, email, sid, root, f, by_user)
  on conflict (choir_id) do update
    set google_email = excluded.google_email, root_folder_id = excluded.root_folder_id,
        folders = excluded.folders, connected_by = excluded.connected_by,
        connected_at = now();
end $$;

create function _drive_token(c uuid)
returns table (refresh text, root text, folders jsonb)
language sql stable security definer set search_path = public, vault as $$
  select s.decrypted_secret, d.root_folder_id, d.folders
    from choir_drive d join vault.decrypted_secrets s on s.id = d.token_secret_id
   where d.choir_id = c
$$;

create function _save_drive_folders(c uuid, f jsonb) returns void
language sql security definer set search_path = public as $$
  update choir_drive set folders = f where choir_id = c
$$;

revoke execute on function _store_drive, _drive_token, _save_drive_folders
  from public, anon, authenticated;
grant execute on function _store_drive, _drive_token, _save_drive_folders to service_role;
