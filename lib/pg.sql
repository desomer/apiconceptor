create table public.attributs (
  created_at timestamp with time zone not null default now(),
  company_id text not null,
  namespace text not null,
  category text not null,
  schema_id text not null,
  attr_id text not null,
  path text not null,
  prop jsonb not null,
  version text not null,
  state text null,
  constraint attributs_pkey primary key (company_id, namespace, schema_id, attr_id)
) TABLESPACE pg_default;


create table public.models (
  created_at timestamp with time zone not null default now(),
  compagny_id text not null,
  model_id text not null,
  json jsonb null,
  constraint models_pkey primary key (compagny_id, model_id)
) TABLESPACE pg_default;


create table public.customer_subscriptions (
  id uuid not null default gen_random_uuid (),
  email text not null,
  plan text not null,
  status text not null,
  stripe_customer_id text null,
  stripe_subscription_id text null,
  updated_at timestamp with time zone not null default timezone ('utc'::text, now()),
  created_at timestamp with time zone not null default timezone ('utc'::text, now()),
  company_id text null,
  company_name text null,
  constraint customer_subscriptions_pkey primary key (id),
  constraint customer_subscriptions_plan_check check (
    (
      plan = any (array['free'::text, 'starter'::text, 'pro'::text])
    )
  )
) TABLESPACE pg_default;



create or replace function search_attributs(
  q text,
  lang regconfig,
  company_id text
)
returns setof attributs
language sql stable as $$
  select *
  from attributs
  where attributs.company_id = company_id
    and to_tsvector(
      lang,
      coalesce(prop->>'title', '') || ' ' ||
      coalesce(prop->>'description', '') || ' ' ||
      coalesce(path, '')
    ) @@ websearch_to_tsquery(lang, q);
$$;

