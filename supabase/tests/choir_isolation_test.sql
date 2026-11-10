-- CHOIR-B1 isolation and section-leader rules. Run: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
select plan(33);

-- Users: choir 1 = sef1, leader (soprano), ece + sena (soprano), aylin (alto),
-- newbie (asks to join). Choir 2 = sef2, x (soprano).
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000001', 'sef1@t'),
  ('00000000-0000-0000-0000-000000000002', 'leader@t'),
  ('00000000-0000-0000-0000-000000000003', 'ece@t'),
  ('00000000-0000-0000-0000-000000000004', 'sena@t'),
  ('00000000-0000-0000-0000-000000000005', 'aylin@t'),
  ('00000000-0000-0000-0000-000000000006', 'newbie@t'),
  ('00000000-0000-0000-0000-000000000011', 'sef2@t'),
  ('00000000-0000-0000-0000-000000000012', 'x@t');

create function pg_temp.as_user(n int) returns void language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims',
           json_build_object('sub', '00000000-0000-0000-0000-0000000000'
             || lpad(n::text, 2, '0'), 'role', 'authenticated')::text, true);
$$;
create function pg_temp.as_admin() returns void language sql as $$
  select set_config('role', 'postgres', true);
$$;
create temp table ids (k text primary key, v text);
grant all on ids to authenticated;

-- Choir 1 and its members, through the public functions only.
select pg_temp.as_user(1);
insert into ids values ('c1', create_choir('Koro Bir', 'Şef Bir'));
insert into ids values ('inv1', create_invite((select v::uuid from ids where k = 'c1')));

select pg_temp.as_user(2);
select is(preview_invite((select v from ids where k = 'inv1')), 'Koro Bir',
          'invite shows only the choir name');
insert into ids values ('r2', request_join((select v from ids where k = 'inv1'), 'Ayşe', 'soprano'));
select is((select count(*)::int from choirs), 0, 'a pending person sees no choir');
select is((select count(*)::int from members), 0, 'a pending person sees no members');
select pg_temp.as_user(3);
insert into ids values ('r3', request_join((select v from ids where k = 'inv1'), 'Ece', 'soprano'));
select pg_temp.as_user(4);
insert into ids values ('r4', request_join((select v from ids where k = 'inv1'), 'Sena', 'soprano'));
select pg_temp.as_user(5);
insert into ids values ('r5', request_join((select v from ids where k = 'inv1'), 'Aylin', 'alto'));
select pg_temp.as_user(6);
insert into ids values ('r6', request_join((select v from ids where k = 'inv1'), 'Yeni', 'tenor'));

select pg_temp.as_user(3);
select throws_ok($$ select decide_join((select v::uuid from ids where k = 'r4'), true) $$,
                 'no such request', 'a singer cannot approve requests');

select pg_temp.as_user(1);
select decide_join((select v::uuid from ids where k = k2), true)
  from (values ('r2'), ('r3'), ('r4'), ('r5')) v(k2);
select is((select count(*)::int from join_requests where status = 'pending'), 1,
          'conductor sees the remaining pending request');
select set_section_leader((select v::uuid from ids where k = 'c1'),
                          '00000000-0000-0000-0000-000000000002', true);
select is((select count(*)::int from members), 5, 'conductor sees five members');

-- Choir 2.
select pg_temp.as_user(11);
insert into ids values ('c2', create_choir('Koro İki', 'Şef İki'));
insert into ids values ('inv2', create_invite((select v::uuid from ids where k = 'c2')));
select pg_temp.as_user(12);
insert into ids values ('r12', request_join((select v from ids where k = 'inv2'), 'X', 'soprano'));
select pg_temp.as_user(11);
select decide_join((select v::uuid from ids where k = 'r12'), true);

-- Each choir publishes assignment a1; each singer's recording is a ready
-- take file of their own (the Edge Function would have made these rows).
select pg_temp.as_user(1);
select put_item((select v::uuid from ids where k = 'c1'), 'assignment', 'a1',
  jsonb_build_object('id', 'a1', 'choirId', (select v from ids where k = 'c1'), 'pieces', '[]'::jsonb));
select pg_temp.as_user(11);
select put_item((select v::uuid from ids where k = 'c2'), 'assignment', 'a1',
  jsonb_build_object('id', 'a1', 'choirId', (select v from ids where k = 'c2'), 'pieces', '[]'::jsonb));
select pg_temp.as_admin();
insert into media (id, choir_id, kind, owner_id, ext, mime, size_bytes, status, drive_file_id) values
  ('10000000-0000-0000-0000-000000000003', (select v::uuid from ids where k = 'c1'), 'take',
   '00000000-0000-0000-0000-000000000003', 'wav', 'audio/wav', 1000, 'ready', 'd-ece'),
  ('10000000-0000-0000-0000-000000000005', (select v::uuid from ids where k = 'c1'), 'take',
   '00000000-0000-0000-0000-000000000005', 'wav', 'audio/wav', 1000, 'ready', 'd-aylin'),
  ('10000000-0000-0000-0000-000000000012', (select v::uuid from ids where k = 'c2'), 'take',
   '00000000-0000-0000-0000-000000000012', 'wav', 'audio/wav', 1000, 'ready', 'd-x');

-- Takes in choir 1: ece (soprano), aylin (alto). Choir 2: x (soprano).
select pg_temp.as_user(3);
insert into ids values ('s_ece', submit_take((select v::uuid from ids where k = 'c1'),
  'a1', 'p1', '10000000-0000-0000-0000-000000000003', 60000));
select pg_temp.as_user(5);
insert into ids values ('s_aylin', submit_take((select v::uuid from ids where k = 'c1'),
  'a1', 'p1', '10000000-0000-0000-0000-000000000005', 60000));
select pg_temp.as_user(12);
insert into ids values ('s_x', submit_take((select v::uuid from ids where k = 'c2'),
  'a1', 'p1', '10000000-0000-0000-0000-000000000012', 60000));

-- Isolation across choirs.
select is((select count(*)::int from choirs), 1, 'choir 2 singer sees only choir 2');
select is((select count(*)::int from submissions), 1, 'choir 2 singer sees only choir 2 takes');
select ok(not can_listen((select v::uuid from ids where k = 's_ece')),
          'choir 2 soprano cannot hear a choir 1 soprano');
select pg_temp.as_user(11);
select ok(not can_listen((select v::uuid from ids where k = 's_ece')),
          'another conductor cannot hear choir 1');
select throws_ok($$ select conductor_review((select v::uuid from ids where k = 's_ece'),
                                            true, 'ok') $$,
                 'not allowed', 'another conductor cannot review choir 1');
select throws_ok($$ select create_invite((select v::uuid from ids where k = 'c1')) $$,
                 'only the conductor invites', 'another conductor cannot invite to choir 1');

-- Within choir 1: status for all, audio by part.
select pg_temp.as_user(5);
select is((select count(*)::int from submissions), 2, 'alto sees every sent status');
select ok(not can_listen((select v::uuid from ids where k = 's_ece')),
          'alto cannot hear a soprano take');
select pg_temp.as_user(4);
select ok(can_listen((select v::uuid from ids where k = 's_ece')),
          'same-part soprano can hear it');
select throws_ok($$ select leader_decide((select v::uuid from ids where k = 's_ece'), true) $$,
                 'only a leader of this part', 'a plain singer cannot forward');

-- Conductor waits for the soprano leader; alto has no leader.
select pg_temp.as_user(1);
select ok(not can_listen((select v::uuid from ids where k = 's_ece')),
          'conductor cannot hear an unforwarded soprano take');
select ok(can_listen((select v::uuid from ids where k = 's_aylin')),
          'conductor hears a take from a part with no leader');
select throws_ok($$ select conductor_review((select v::uuid from ids where k = 's_ece'),
                                            true, 'ok') $$,
                 'not allowed', 'conductor cannot review before forwarding');

-- Leader acts.
select pg_temp.as_user(2);
select ok(can_listen((select v::uuid from ids where k = 's_ece')), 'leader hears the take');
select throws_ok($$ select leader_decide((select v::uuid from ids where k = 's_ece'), false) $$,
                 'say what to change', 'a retake request needs a note');
select lives_ok($$ select leader_decide((select v::uuid from ids where k = 's_ece'), true,
                                        'Temiz, gönderiyorum') $$,
                'leader forwards with a note');

select pg_temp.as_user(1);
select ok(can_listen((select v::uuid from ids where k = 's_ece')),
          'conductor hears it once forwarded');
select is((select count(*)::int from feedback), 1, 'conductor reads the leader note');
select lives_ok($$ select conductor_review((select v::uuid from ids where k = 's_ece'),
                                           true, 'Tamam') $$, 'conductor accepts');

select pg_temp.as_user(4);
select is((select count(*)::int from feedback), 0, 'another soprano cannot read feedback');
select pg_temp.as_user(3);
select is((select count(*)::int from feedback), 2, 'the singer reads all their feedback');

-- Table writes are closed; removal ends access.
select throws_ok($$ insert into choirs (name, conductor_id)
                    values ('Sahte', '00000000-0000-0000-0000-000000000003') $$,
                 '42501', null, 'no direct insert into choirs');
with u as (update submissions set status = 'accepted' returning 1)
select is((select count(*)::int from u), 0, 'no direct status change');

select pg_temp.as_user(1);
select remove_member((select v::uuid from ids where k = 'c1'),
                     '00000000-0000-0000-0000-000000000004');
select pg_temp.as_user(4);
select is((select count(*)::int from submissions), 0, 'a removed singer sees nothing');
select ok(not can_listen((select v::uuid from ids where k = 's_ece')),
          'a removed singer hears nothing');

-- Invites expire and can be revoked.
select pg_temp.as_user(1);
select revoke_invite((select v from ids where k = 'inv1'));
select pg_temp.as_user(4);
select throws_ok($$ select request_join((select v from ids where k = 'inv1'), 'Sena') $$,
                 'invite not valid', 'a revoked invite is refused');

-- Anonymous gets nothing.
select set_config('role', 'anon', true);
select throws_ok($$ select preview_invite('AAAAAAAA') $$, '42501', null,
                 'anonymous cannot call functions');

select * from finish();
rollback;
