-- CHOIR-B2/B3 media, items and Drive status. Run: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
select plan(28);

-- 1 conductor, 2 soprano leader, 3 soprano, 4 alto; 11 another conductor.
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000001', 'sef@t'),
  ('00000000-0000-0000-0000-000000000002', 'lider@t'),
  ('00000000-0000-0000-0000-000000000003', 'sop@t'),
  ('00000000-0000-0000-0000-000000000004', 'alto@t'),
  ('00000000-0000-0000-0000-000000000011', 'baska@t');

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

select pg_temp.as_user(1);
insert into ids values ('c', create_choir('Koro', 'Şef'));
insert into ids values ('inv', create_invite((select v::uuid from ids where k = 'c')));
select pg_temp.as_user(2);
insert into ids values ('r2', request_join((select v from ids where k = 'inv'), 'Lider', 'soprano'));
select pg_temp.as_user(3);
insert into ids values ('r3', request_join((select v from ids where k = 'inv'), 'Sop', 'soprano'));
select pg_temp.as_user(4);
insert into ids values ('r4', request_join((select v from ids where k = 'inv'), 'Alto', 'alto'));
select pg_temp.as_user(1);
select decide_join((select v::uuid from ids where k = x), true) from (values ('r2'), ('r3'), ('r4')) v(x);
select set_section_leader((select v::uuid from ids where k = 'c'),
                          '00000000-0000-0000-0000-000000000002', true);
select pg_temp.as_user(11);
insert into ids values ('c2', create_choir('Başka', 'Başka'));

-- Upload rights.
select pg_temp.as_user(1);
select ok(can_upload_media((select v::uuid from ids where k = 'c'), 'repertoire'), 'conductor uploads repertoire');
select ok(not can_upload_media((select v::uuid from ids where k = 'c'), 'take'), 'conductor sends no takes');
select ok(can_upload_media((select v::uuid from ids where k = 'c'), 'voice_note'), 'conductor leaves voice notes');
select pg_temp.as_user(2);
select ok(can_upload_media((select v::uuid from ids where k = 'c'), 'voice_note'), 'leader leaves voice notes');
select pg_temp.as_user(3);
select ok(can_upload_media((select v::uuid from ids where k = 'c'), 'take'), 'singer sends takes');
select ok(not can_upload_media((select v::uuid from ids where k = 'c'), 'repertoire'), 'singer adds no repertoire');
select ok(not can_upload_media((select v::uuid from ids where k = 'c'), 'voice_note'), 'singer leaves no voice notes');
select pg_temp.as_user(11);
select ok(not can_upload_media((select v::uuid from ids where k = 'c'), 'take'), 'outsider uploads nothing');

-- Files, as the Edge Functions would leave them.
select pg_temp.as_admin();
insert into media (id, choir_id, kind, owner_id, ext, mime, size_bytes, status, drive_file_id) values
  ('20000000-0000-0000-0000-000000000001', (select v::uuid from ids where k = 'c'), 'repertoire',
   '00000000-0000-0000-0000-000000000001', 'mid', 'audio/midi', 100, 'ready', 'd-midi'),
  ('20000000-0000-0000-0000-000000000003', (select v::uuid from ids where k = 'c'), 'take',
   '00000000-0000-0000-0000-000000000003', 'wav', 'audio/wav', 100, 'ready', 'd-take'),
  ('20000000-0000-0000-0000-000000000004', (select v::uuid from ids where k = 'c'), 'take',
   '00000000-0000-0000-0000-000000000004', 'wav', 'audio/wav', 100, 'pending', null),
  ('20000000-0000-0000-0000-000000000002', (select v::uuid from ids where k = 'c'), 'voice_note',
   '00000000-0000-0000-0000-000000000002', 'wav', 'audio/wav', 100, 'ready', 'd-voice');

-- Items.
select pg_temp.as_user(3);
select throws_ok($$ select put_item((select v::uuid from ids where k = 'c'), 'reference', 'r1',
  jsonb_build_object('id', 'r1', 'choirId', (select v from ids where k = 'c'))) $$,
  'only the conductor edits', 'a singer cannot add repertoire');
select pg_temp.as_user(1);
select throws_ok($$ select put_item((select v::uuid from ids where k = 'c'), 'reference', 'r1',
  jsonb_build_object('id', 'r1', 'choirId', (select v from ids where k = 'c2'))) $$,
  'item does not match', 'an item must name its own choir');
select throws_ok($$ select put_item((select v::uuid from ids where k = 'c'), 'assignment', 'a1',
  jsonb_build_object('id', 'a1', 'choirId', (select v from ids where k = 'c'),
    'pieces', jsonb_build_array(jsonb_build_object('id', 'p1', 'midiReferenceId', 'r9')))) $$,
  'unknown reference', 'an assignment cannot point at missing repertoire');
select lives_ok($$ select put_item((select v::uuid from ids where k = 'c'), 'reference',
  '20000000000000000000000000000001.mid',
  jsonb_build_object('id', '20000000000000000000000000000001.mid', 'choirId', (select v from ids where k = 'c')),
  '20000000-0000-0000-0000-000000000001') $$, 'conductor adds the MIDI');
select lives_ok($$ select put_item((select v::uuid from ids where k = 'c'), 'assignment', 'a1',
  jsonb_build_object('id', 'a1', 'choirId', (select v from ids where k = 'c'),
    'pieces', jsonb_build_array(jsonb_build_object('id', 'p1',
      'midiReferenceId', '20000000000000000000000000000001.mid')))) $$,
  'conductor publishes an assignment using it');

-- Takes must be the singer's own ready file.
select pg_temp.as_user(4);
select throws_ok($$ select submit_take((select v::uuid from ids where k = 'c'), 'a1', 'p1',
  '20000000-0000-0000-0000-000000000003', 1000) $$, 'take needs a recording',
  'nobody sends another singer''s file');
select throws_ok($$ select submit_take((select v::uuid from ids where k = 'c'), 'a1', 'p1',
  '20000000-0000-0000-0000-000000000004', 1000) $$, 'take needs a recording',
  'an unfinished upload cannot be sent');
select throws_ok($$ select submit_take((select v::uuid from ids where k = 'c'), 'a9', 'p1',
  '20000000-0000-0000-0000-000000000004', 1000) $$, 'take needs a recording',
  'nor to a missing assignment');
select pg_temp.as_user(3);
insert into ids values ('s', submit_take((select v::uuid from ids where k = 'c'), 'a1', 'p1',
  '20000000-0000-0000-0000-000000000003', 1000, 'unaccompanied'));

-- Who reads what.
select pg_temp.as_user(4);
select ok(can_read_media('20000000-0000-0000-0000-000000000001'), 'every member opens repertoire');
select ok(not can_read_media('20000000-0000-0000-0000-000000000003'), 'alto cannot hear a soprano take');
select pg_temp.as_user(11);
select ok(not can_read_media('20000000-0000-0000-0000-000000000001'), 'another choir opens nothing');
select pg_temp.as_user(1);
select ok(not can_read_media('20000000-0000-0000-0000-000000000003'), 'conductor waits for forwarding');

select pg_temp.as_user(2);
select ok(can_read_media('20000000-0000-0000-0000-000000000003'), 'leader hears the take');
select lives_ok($$ select leader_decide((select v::uuid from ids where k = 's'), true, 'İyi',
  '{}', '[]', '20000000-0000-0000-0000-000000000002') $$, 'leader forwards with a voice note');

select pg_temp.as_user(1);
select ok(can_read_media('20000000-0000-0000-0000-000000000003'), 'conductor hears it once forwarded');
select ok(can_read_media('20000000-0000-0000-0000-000000000002'), 'and the leader''s voice note');
select pg_temp.as_user(4);
select ok(not can_read_media('20000000-0000-0000-0000-000000000002'), 'another part cannot hear the note');

-- Drive status and the hidden Drive id.
select pg_temp.as_admin();
insert into choir_drive (choir_id, google_email, token_secret_id, root_folder_id, connected_by)
  values ((select v::uuid from ids where k = 'c'), 'koro@gmail.com', gen_random_uuid(), 'root',
          '00000000-0000-0000-0000-000000000001');
select pg_temp.as_user(3);
select is((select row(connected, google_email)::text from drive_status((select v::uuid from ids where k = 'c'))),
          '(t,)', 'a singer sees that Drive is connected, not the account');
select pg_temp.as_user(1);
select is((select google_email from drive_status((select v::uuid from ids where k = 'c'))),
          'koro@gmail.com', 'the conductor sees the account');
select throws_ok($$ select drive_file_id from media $$, '42501', null,
                 'nobody reads Drive file ids');

select * from finish();
rollback;
