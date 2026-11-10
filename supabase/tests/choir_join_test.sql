-- CHOIR-B1b joining extras. Run: supabase test db
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000001', 'sef@t'),
  ('00000000-0000-0000-0000-000000000002', 'yeni@t'),
  ('00000000-0000-0000-0000-000000000003', 'baska@t');

create function pg_temp.as_user(n int) returns void language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims',
           json_build_object('sub', '00000000-0000-0000-0000-0000000000'
             || lpad(n::text, 2, '0'), 'role', 'authenticated')::text, true);
$$;
create temp table ids (k text primary key, v text);
grant all on ids to authenticated;

select pg_temp.as_user(1);
insert into ids values ('c', create_choir('Koro', 'Şef'));
insert into ids values ('inv', create_invite((select v::uuid from ids where k = 'c'), 7, 2));

select pg_temp.as_user(2);
insert into ids values ('r', request_join((select v from ids where k = 'inv'), 'Yeni', 'alto'));
select is((select choir_name from my_join_requests()), 'Koro',
          'a waiting person sees the choir name of their request');
select is((select status::text from my_join_requests()), 'pending', 'status is pending');
select is(request_join((select v from ids where k = 'inv'), 'Yeni', 'alto'),
          (select v::uuid from ids where k = 'r'), 'asking twice returns the same request');

select pg_temp.as_user(3);
select is((select count(*)::int from my_join_requests()), 0,
          'nobody else sees that request');
select throws_ok($$ select cancel_join_request((select v::uuid from ids where k = 'r')) $$,
                 'no such request', 'nobody else can cancel it');
select throws_ok($$ select delete_choir((select v::uuid from ids where k = 'c')) $$,
                 'only the conductor deletes', 'a stranger cannot delete the choir');

select pg_temp.as_user(2);
select lives_ok($$ select cancel_join_request((select v::uuid from ids where k = 'r')) $$,
                'the person withdraws their request');

select pg_temp.as_user(1);
select lives_ok($$ select delete_choir((select v::uuid from ids where k = 'c')) $$,
                'the conductor deletes the choir');
select is((select count(*)::int from choirs), 0, 'nothing of the choir is left');

select * from finish();
rollback;
