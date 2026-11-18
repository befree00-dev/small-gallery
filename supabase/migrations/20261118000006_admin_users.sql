-- Admin: the list of signed-up users.
-- Emails come from auth.users, so this is admin-only like every admin_* function.

create or replace function public.admin_users(p_limit integer default 100, p_search text default null)
returns table (
  id uuid, email text, display_name text, plan text, is_admin boolean,
  email_confirmed boolean, created_at timestamptz, last_sign_in_at timestamptz,
  gallery_handle text, artworks bigint
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  q text := nullif(btrim(coalesce(p_search, '')), '');
begin
  perform public.require_admin();
  return query
  select u.id, u.email::text, p.display_name, p.plan,
         exists (select 1 from public.admins a where a.user_id = u.id),
         u.email_confirmed_at is not null,
         u.created_at, u.last_sign_in_at,
         g.handle,
         (select count(*) from public.artworks w where w.gallery_id = g.id)
  from auth.users u
  left join public.profiles p on p.id = u.id
  left join public.galleries g on g.owner_id = u.id
  where q is null
     or u.email ilike '%' || q || '%'
     or p.display_name ilike '%' || q || '%'
     or g.handle ilike '%' || q || '%'
  order by u.created_at desc
  limit least(greatest(p_limit, 1), 1000);
end;
$$;

revoke execute on function public.admin_users(integer, text) from public, anon;
grant execute on function public.admin_users(integer, text) to authenticated;
