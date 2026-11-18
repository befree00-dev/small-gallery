-- Google and Apple sign-ins send the person's name as full_name / name, not display_name.
-- Use it for the profile, falling back to the part of the email before @.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, locale)
  values (
    new.id,
    left(coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
      nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
      nullif(trim(new.raw_user_meta_data ->> 'name'), ''),
      split_part(new.email, '@', 1),
      ''
    ), 40),
    case when new.raw_user_meta_data ->> 'locale' = 'en' then 'en' else 'ko' end
  );
  return new;
end;
$$;
