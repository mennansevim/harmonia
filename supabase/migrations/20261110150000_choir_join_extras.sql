-- CHOIR-B1b: what the app needs around joining.
-- A person waiting for approval cannot read the choir row (RLS), so their
-- own requests come with the choir name through this function.
create function my_join_requests()
returns table (
  id uuid, choir_id uuid, choir_name text, wanted_part choir_part,
  status join_status, created_at timestamptz
)
language sql stable security definer set search_path = public as $$
  select r.id, r.choir_id, c.name, r.wanted_part, r.status, r.created_at
    from join_requests r join choirs c on c.id = r.choir_id
   where r.user_id = auth.uid()
     and (r.status = 'pending' or r.decided_at > now() - interval '30 days')
   order by r.created_at desc
$$;

-- The person withdraws their own pending request.
create function cancel_join_request(request_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from join_requests
   where id = request_id and user_id = auth.uid() and status = 'pending';
  if not found then raise exception 'no such request'; end if;
end $$;

-- The conductor deletes the whole choir: members, invites, takes, feedback.
-- Drive files are removed by the server job that owns the Drive token.
create function delete_choir(c uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_conductor(c) then raise exception 'only the conductor deletes'; end if;
  delete from choirs where id = c;
end $$;

revoke execute on function my_join_requests, cancel_join_request, delete_choir
  from public, anon;
grant execute on function my_join_requests, cancel_join_request, delete_choir
  to authenticated;
