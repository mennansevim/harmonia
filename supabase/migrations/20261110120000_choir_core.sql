-- CHOIR-B1: choirs, members, invites, join requests, takes and feedback.
--
-- Isolation rule: every row carries choir_id and is visible only to approved
-- members of that choir. Clients never write tables directly; every change
-- goes through a SECURITY DEFINER function that checks the caller's role.
-- The rules mirror lib/choir/domain/choir_access.dart.
--
-- Files (MIDI, PDF, takes, voice notes) live in the choir's Google Drive;
-- rows keep only Drive file ids, which are useless without the server-held
-- token. Audio is served by an Edge Function that calls can_listen().

create type choir_role as enum ('conductor', 'singer');
create type choir_part as enum ('soprano', 'alto', 'tenor', 'bass');
create type submission_status as enum (
  'draft', 'submitted', 'listened', 'forwarded', 'accepted', 'revisionRequested'
);
create type join_status as enum ('pending', 'approved', 'declined');

-- ---------------------------------------------------------------- tables

create table choirs (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 1 and 80),
  conductor_id uuid not null references auth.users (id),
  created_at timestamptz not null default now()
);

create table members (
  choir_id uuid not null references choirs (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  display_name text not null check (length(trim(display_name)) between 1 and 60),
  role choir_role not null,
  part choir_part,
  leads_part boolean not null default false,
  joined_at timestamptz not null default now(),
  primary key (choir_id, user_id),
  check (role = 'singer' or part is null),
  check (not leads_part or (role = 'singer' and part is not null))
);
-- One conductor per choir.
create unique index members_one_conductor on members (choir_id)
  where role = 'conductor';

create table invites (
  code text primary key check (code ~ '^[A-Z2-9]{8}$'),
  choir_id uuid not null references choirs (id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  max_uses int check (max_uses is null or max_uses >= 1),
  uses int not null default 0 check (uses >= 0),
  revoked boolean not null default false,
  check (expires_at > created_at),
  check (max_uses is null or uses <= max_uses)
);

create table join_requests (
  id uuid primary key default gen_random_uuid(),
  choir_id uuid not null references choirs (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  display_name text not null check (length(trim(display_name)) between 1 and 60),
  wanted_part choir_part,
  status join_status not null default 'pending',
  created_at timestamptz not null default now(),
  decided_at timestamptz
);
create unique index join_requests_one_pending on join_requests (choir_id, user_id)
  where status = 'pending';

create table submissions (
  id uuid primary key default gen_random_uuid(),
  choir_id uuid not null references choirs (id) on delete cascade,
  assignment_id text not null,
  piece_id text not null,
  member_id uuid not null references auth.users (id) on delete cascade,
  part choir_part not null,
  status submission_status not null default 'draft',
  attempt int not null default 1 check (attempt >= 1),
  recording_file_id text,
  duration_ms int check (duration_ms is null or duration_ms > 0),
  submitted_at timestamptz,
  listened_at timestamptz,
  forwarded_at timestamptz,
  unique (choir_id, assignment_id, piece_id, member_id),
  check (status = 'draft' or (recording_file_id is not null and submitted_at is not null)),
  check (status <> 'forwarded' or forwarded_at is not null),
  check (forwarded_at is null or status in ('forwarded', 'accepted', 'revisionRequested'))
);

create table feedback (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references submissions (id) on delete cascade,
  choir_id uuid not null references choirs (id) on delete cascade,
  author_id uuid not null references auth.users (id),
  attempt int not null check (attempt >= 1),
  text text not null default '',
  tags text[] not null default '{}',
  marks jsonb not null default '[]',
  voice_note_file_id text,
  created_at timestamptz not null default now(),
  check (length(trim(text)) > 0 or cardinality(tags) > 0
         or jsonb_array_length(marks) > 0 or voice_note_file_id is not null)
);

alter table choirs enable row level security;
alter table members enable row level security;
alter table invites enable row level security;
alter table join_requests enable row level security;
alter table submissions enable row level security;
alter table feedback enable row level security;

-- ---------------------------------------------------------------- helpers
-- SECURITY DEFINER so policies can read members without recursing into
-- members' own policy. search_path is pinned.

create function my_member(c uuid) returns members
language sql stable security definer set search_path = public as $$
  select * from members where choir_id = c and user_id = auth.uid()
$$;

create function is_member(c uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from members where choir_id = c and user_id = auth.uid())
$$;

create function is_conductor(c uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from members
                 where choir_id = c and user_id = auth.uid() and role = 'conductor')
$$;

create function part_has_other_leader(c uuid, p choir_part, singer uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from members
                 where choir_id = c and part = p and leads_part and user_id <> singer)
$$;

create function conductor_sees(s submissions) returns boolean
language sql stable security definer set search_path = public as $$
  select s.status <> 'draft'
     and (s.forwarded_at is not null
          or not part_has_other_leader(s.choir_id, s.part, s.member_id))
$$;

create function can_listen(sub_id uuid) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare
  s submissions;
  me members;
begin
  select * into s from submissions where id = sub_id;
  if not found then return false; end if;
  me := my_member(s.choir_id);
  if me.user_id is null then return false; end if;
  if me.user_id = s.member_id then return true; end if;
  if s.status = 'draft' then return false; end if;
  if me.role = 'conductor' then return conductor_sees(s); end if;
  return me.part = s.part;
end $$;

create function can_read_feedback(sub_id uuid) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare
  s submissions;
  me members;
begin
  select * into s from submissions where id = sub_id;
  if not found then return false; end if;
  me := my_member(s.choir_id);
  if me.user_id is null then return false; end if;
  if me.user_id = s.member_id then return true; end if;
  if s.status = 'draft' then return false; end if;
  if me.role = 'conductor' then return conductor_sees(s); end if;
  return me.leads_part and me.part = s.part;
end $$;

-- ---------------------------------------------------------------- read policies
-- No insert/update/delete policies: all writes go through the functions below.

create policy choirs_read on choirs for select using (is_member(id));
create policy members_read on members for select using (is_member(choir_id));
create policy invites_read on invites for select using (is_conductor(choir_id));
create policy join_requests_read on join_requests for select
  using (user_id = auth.uid() or is_conductor(choir_id));
-- Everyone in the choir sees who sent what; drafts stay with their singer.
-- The recording itself is served only after can_listen().
create policy submissions_read on submissions for select
  using (member_id = auth.uid() or (status <> 'draft' and is_member(choir_id)));
create policy feedback_read on feedback for select
  using (can_read_feedback(submission_id));

-- ---------------------------------------------------------------- choir & joining

create function create_choir(choir_name text, conductor_name text) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  new_id uuid;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  insert into choirs (name, conductor_id) values (trim(choir_name), auth.uid())
    returning id into new_id;
  insert into members (choir_id, user_id, display_name, role)
    values (new_id, auth.uid(), trim(conductor_name), 'conductor');
  return new_id;
end $$;

create function create_invite(c uuid, valid_days int default 14, max_uses int default null)
returns text
language plpgsql security definer set search_path = public, extensions as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  new_code text;
  b bytea;
begin
  if not is_conductor(c) then raise exception 'only the conductor invites'; end if;
  if valid_days not between 1 and 90 then raise exception 'valid_days out of range'; end if;
  loop
    b := gen_random_bytes(8);
    new_code := '';
    for i in 0..7 loop
      new_code := new_code || substr(alphabet, (get_byte(b, i) % 32) + 1, 1);
    end loop;
    exit when not exists (select 1 from invites where code = new_code);
  end loop;
  insert into invites (code, choir_id, expires_at, max_uses)
    values (new_code, c, now() + make_interval(days => valid_days), max_uses);
  return new_code;
end $$;

create function revoke_invite(invite_code text) returns void
language plpgsql security definer set search_path = public as $$
begin
  update invites set revoked = true
   where code = upper(invite_code) and is_conductor(choir_id);
  if not found then raise exception 'no such invite'; end if;
end $$;

-- What a person sees before asking to join: the choir name, nothing else.
create function preview_invite(invite_code text) returns text
language plpgsql stable security definer set search_path = public as $$
declare
  n text;
begin
  select ch.name into n from invites i join choirs ch on ch.id = i.choir_id
   where i.code = upper(invite_code) and not i.revoked and i.expires_at > now()
     and (i.max_uses is null or i.uses < i.max_uses);
  if n is null then raise exception 'invite not valid'; end if;
  return n;
end $$;

create function request_join(invite_code text, name text, wanted choir_part default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  inv invites;
  req_id uuid;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select * into inv from invites where code = upper(invite_code) for update;
  if not found or inv.revoked or inv.expires_at <= now()
     or (inv.max_uses is not null and inv.uses >= inv.max_uses) then
    raise exception 'invite not valid';
  end if;
  if exists (select 1 from members where choir_id = inv.choir_id and user_id = auth.uid()) then
    raise exception 'already a member';
  end if;
  select id into req_id from join_requests
   where choir_id = inv.choir_id and user_id = auth.uid() and status = 'pending';
  if req_id is not null then return req_id; end if;
  update invites set uses = uses + 1 where code = inv.code;
  insert into join_requests (choir_id, user_id, display_name, wanted_part)
    values (inv.choir_id, auth.uid(), trim(name), wanted) returning id into req_id;
  return req_id;
end $$;

create function decide_join(request_id uuid, approve boolean, part choir_part default null)
returns void
language plpgsql security definer set search_path = public as $$
declare
  r join_requests;
begin
  select * into r from join_requests where id = request_id for update;
  if not found or not is_conductor(r.choir_id) then raise exception 'no such request'; end if;
  if r.status <> 'pending' then raise exception 'already decided'; end if;
  update join_requests set status = case when approve then 'approved'::join_status
                                         else 'declined'::join_status end,
                           decided_at = now()
   where id = request_id;
  if approve then
    insert into members (choir_id, user_id, display_name, role, part)
      values (r.choir_id, r.user_id, r.display_name, 'singer', coalesce(part, r.wanted_part));
  end if;
end $$;

-- The conductor assigns a part; moving a leader ends their leading.
create function set_member_part(c uuid, singer uuid, p choir_part) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_conductor(c) then raise exception 'only the conductor assigns parts'; end if;
  update members set leads_part = leads_part and part is not distinct from p, part = p
   where choir_id = c and user_id = singer and role = 'singer';
  if not found then raise exception 'no such singer'; end if;
end $$;

create function set_section_leader(c uuid, singer uuid, leads boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_conductor(c) then raise exception 'only the conductor names leaders'; end if;
  update members set leads_part = leads
   where choir_id = c and user_id = singer and role = 'singer' and part is not null;
  if not found then raise exception 'no such singer with a part'; end if;
end $$;

-- The conductor removes a singer, or a singer leaves. Access ends at once.
create function remove_member(c uuid, who uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if who <> auth.uid() and not is_conductor(c) then raise exception 'not allowed'; end if;
  delete from members where choir_id = c and user_id = who and role = 'singer';
  if not found then raise exception 'no such singer'; end if;
end $$;

-- ---------------------------------------------------------------- takes

-- The singer sends a recorded take (file already in Drive via upload-finalize).
create function submit_take(
  c uuid, assignment text, piece text, file_id text, duration int
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
  if file_id is null or duration is null or duration <= 0 then
    raise exception 'take needs a recording';
  end if;
  select * into s from submissions
   where choir_id = c and assignment_id = assignment and piece_id = piece
     and member_id = auth.uid() for update;
  if not found then
    insert into submissions (choir_id, assignment_id, piece_id, member_id, part, status,
                             recording_file_id, duration_ms, submitted_at)
      values (c, assignment, piece, auth.uid(), me.part, 'submitted', file_id, duration, now())
      returning * into s;
  elsif s.status in ('draft', 'revisionRequested') then
    update submissions
       set status = 'submitted', part = me.part, recording_file_id = file_id,
           duration_ms = duration, submitted_at = now(), listened_at = null,
           forwarded_at = null,
           attempt = case when s.status = 'revisionRequested' then s.attempt + 1
                          else s.attempt end
     where id = s.id returning * into s;
  else
    raise exception 'take already sent';
  end if;
  return s.id;
end $$;

create function mark_listened(sub_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  s submissions;
  me members;
begin
  select * into s from submissions where id = sub_id for update;
  if not found then raise exception 'no such take'; end if;
  me := my_member(s.choir_id);
  if not coalesce((me.leads_part and me.part = s.part and me.user_id <> s.member_id)
                  or (me.role = 'conductor' and conductor_sees(s)), false) then
    raise exception 'not allowed';
  end if;
  if s.status = 'submitted' then
    update submissions set status = 'listened', listened_at = now() where id = sub_id;
  end if;
end $$;

create function _add_feedback(s submissions, body text, tag_list text[],
                              mark_list jsonb, voice text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if length(trim(coalesce(body, ''))) > 0 or cardinality(tag_list) > 0
     or jsonb_array_length(mark_list) > 0 or voice is not null then
    insert into feedback (submission_id, choir_id, author_id, attempt, text, tags,
                          marks, voice_note_file_id)
      values (s.id, s.choir_id, auth.uid(), s.attempt, coalesce(body, ''), tag_list,
              mark_list, voice);
  end if;
end $$;

-- Section leader: forward to the conductor, or ask for a retake (needs a note).
create function leader_decide(
  sub_id uuid, forward boolean, body text default '', tag_list text[] default '{}',
  mark_list jsonb default '[]', voice text default null
) returns void
language plpgsql security definer set search_path = public as $$
declare
  s submissions;
  me members;
begin
  select * into s from submissions where id = sub_id for update;
  if not found then raise exception 'no such take'; end if;
  me := my_member(s.choir_id);
  if not coalesce(me.leads_part and me.part = s.part and me.user_id <> s.member_id,
                  false) then
    raise exception 'only a leader of this part';
  end if;
  if s.status not in ('submitted', 'listened') then
    raise exception 'take is not waiting for the leader';
  end if;
  if not forward and length(trim(coalesce(body, ''))) = 0 and cardinality(tag_list) = 0
     and jsonb_array_length(mark_list) = 0 and voice is null then
    raise exception 'say what to change';
  end if;
  perform _add_feedback(s, body, tag_list, mark_list, voice);
  update submissions
     set status = case when forward then 'forwarded'::submission_status
                       else 'revisionRequested'::submission_status end,
         listened_at = coalesce(listened_at, now()),
         forwarded_at = case when forward then now() else null end
   where id = sub_id;
end $$;

-- Conductor: accept or return a take that has reached them. Needs a note.
create function conductor_review(
  sub_id uuid, accept boolean, body text default '', tag_list text[] default '{}',
  mark_list jsonb default '[]', voice text default null
) returns void
language plpgsql security definer set search_path = public as $$
declare
  s submissions;
begin
  select * into s from submissions where id = sub_id for update;
  if not found or not is_conductor(s.choir_id) or not conductor_sees(s) then
    raise exception 'not allowed';
  end if;
  if s.status not in ('submitted', 'listened', 'forwarded') then
    raise exception 'take is not waiting for review';
  end if;
  if length(trim(coalesce(body, ''))) = 0 and cardinality(tag_list) = 0
     and jsonb_array_length(mark_list) = 0 and voice is null then
    raise exception 'feedback needs text, a tag, a mark or a voice note';
  end if;
  perform _add_feedback(s, body, tag_list, mark_list, voice);
  update submissions
     set status = case when accept then 'accepted'::submission_status
                       else 'revisionRequested'::submission_status end,
         listened_at = coalesce(listened_at, now())
   where id = sub_id;
end $$;

-- Signed-in callers only; the feedback helper is internal.
revoke execute on all functions in schema public from public, anon;
grant execute on all functions in schema public to authenticated;
revoke execute on function _add_feedback from authenticated;
