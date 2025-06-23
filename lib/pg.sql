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