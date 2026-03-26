-- ═══════════════════════════════════════════════════════
-- Aluguel de Vaga de Garagem — Condomeet
-- Migração aplicada em 2026-03-25 via execute_sql
-- Tabelas: garages, garage_availability, garage_reservations,
--          garage_reviews, garage_earnings, garage_condo_trial
-- ═══════════════════════════════════════════════════════

-- 1. garages
create table if not exists garages (
  id uuid primary key default gen_random_uuid(),
  condominio_id uuid not null references condominios(id) on delete cascade,
  apartamento_id uuid references apartamentos(id),
  owner_id uuid not null references auth.users(id),
  numero_vaga text not null,
  tipo_vaga text not null default 'carro_grande'
    check (tipo_vaga in ('carro_pequeno','carro_grande','moto')),
  descricao text,
  fotos text[] default '{}',
  preco_hora numeric(10,2) default 0,
  preco_dia numeric(10,2) default 0,
  preco_mes numeric(10,2) default 0,
  aluguel_automatico boolean default false,
  ativo boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index if not exists idx_garages_condo on garages(condominio_id);
create index if not exists idx_garages_owner on garages(owner_id);
create index if not exists idx_garages_ativo on garages(condominio_id, ativo);

-- 2. garage_availability
create table if not exists garage_availability (
  id uuid primary key default gen_random_uuid(),
  garage_id uuid not null references garages(id) on delete cascade,
  dia_semana integer not null check (dia_semana between 0 and 6),
  hora_inicio time not null default '08:00',
  hora_fim time not null default '18:00'
);
create index if not exists idx_garage_avail on garage_availability(garage_id);

-- 3. garage_reservations
create table if not exists garage_reservations (
  id uuid primary key default gen_random_uuid(),
  garage_id uuid not null references garages(id) on delete cascade,
  user_id uuid not null references auth.users(id),
  placa text, modelo text, cor text,
  inicio timestamptz not null, fim timestamptz not null,
  tipo_periodo text not null default 'hora'
    check (tipo_periodo in ('hora','dia','mes')),
  valor_total numeric(10,2) default 0,
  status text not null default 'pendente'
    check (status in ('pendente','confirmado','finalizado','cancelado','problema')),
  observacao text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index if not exists idx_garage_res_garage on garage_reservations(garage_id);
create index if not exists idx_garage_res_user on garage_reservations(user_id);
create index if not exists idx_garage_res_status on garage_reservations(status);

-- 4. garage_reviews
create table if not exists garage_reviews (
  id uuid primary key default gen_random_uuid(),
  reservation_id uuid not null references garage_reservations(id) on delete cascade,
  reviewer_id uuid not null references auth.users(id),
  rating integer not null check (rating between 1 and 5),
  comentario text, created_at timestamptz default now(),
  unique(reservation_id, reviewer_id)
);

-- 5. garage_earnings
create table if not exists garage_earnings (
  id uuid primary key default gen_random_uuid(),
  garage_id uuid not null references garages(id) on delete cascade,
  owner_id uuid not null references auth.users(id),
  mes date not null, total_reservas integer default 0,
  valor_total numeric(10,2) default 0,
  unique(garage_id, mes)
);
create index if not exists idx_garage_earn_owner on garage_earnings(owner_id, mes);

-- 6. garage_condo_trial
create table if not exists garage_condo_trial (
  id uuid primary key default gen_random_uuid(),
  condominio_id uuid not null references condominios(id) on delete cascade unique,
  trial_started_at timestamptz default now(),
  trial_ends_at timestamptz default (now() + interval '60 days'),
  is_active boolean default true,
  created_at timestamptz default now()
);

-- ═══════════════════════════════════════════════════════
-- RLS
-- ═══════════════════════════════════════════════════════
alter table garages enable row level security;
alter table garage_availability enable row level security;
alter table garage_reservations enable row level security;
alter table garage_reviews enable row level security;
alter table garage_earnings enable row level security;
alter table garage_condo_trial enable row level security;

create policy "garages_select" on garages for select using (
  exists (select 1 from perfil p where p.id = auth.uid() and p.condominio_id = garages.condominio_id)
);
create policy "garages_insert" on garages for insert with check (owner_id = auth.uid());
create policy "garages_update" on garages for update using (owner_id = auth.uid());
create policy "garages_delete" on garages for delete using (owner_id = auth.uid());

create policy "avail_select" on garage_availability for select using (
  exists (select 1 from garages g join perfil p on p.condominio_id = g.condominio_id where g.id = garage_availability.garage_id and p.id = auth.uid())
);
create policy "avail_insert" on garage_availability for insert with check (
  exists (select 1 from garages g where g.id = garage_availability.garage_id and g.owner_id = auth.uid())
);
create policy "avail_update" on garage_availability for update using (
  exists (select 1 from garages g where g.id = garage_availability.garage_id and g.owner_id = auth.uid())
);
create policy "avail_delete" on garage_availability for delete using (
  exists (select 1 from garages g where g.id = garage_availability.garage_id and g.owner_id = auth.uid())
);

create policy "res_select" on garage_reservations for select using (
  user_id = auth.uid() or exists (select 1 from garages g where g.id = garage_reservations.garage_id and g.owner_id = auth.uid())
);
create policy "res_insert" on garage_reservations for insert with check (user_id = auth.uid());
create policy "res_update" on garage_reservations for update using (
  user_id = auth.uid() or exists (select 1 from garages g where g.id = garage_reservations.garage_id and g.owner_id = auth.uid())
);

create policy "reviews_select" on garage_reviews for select using (true);
create policy "reviews_insert" on garage_reviews for insert with check (reviewer_id = auth.uid());

create policy "earnings_select" on garage_earnings for select using (owner_id = auth.uid());

create policy "trial_select" on garage_condo_trial for select using (
  exists (select 1 from perfil p where p.id = auth.uid() and p.condominio_id = garage_condo_trial.condominio_id)
);
create policy "trial_insert" on garage_condo_trial for insert with check (
  exists (select 1 from perfil p where p.id = auth.uid() and p.condominio_id = garage_condo_trial.condominio_id)
);

-- ═══════════════════════════════════════════════════════
-- RPCs
-- ═══════════════════════════════════════════════════════
create or replace function garage_check_availability(p_garage_id uuid, p_inicio timestamptz, p_fim timestamptz) returns boolean as $$
begin
  return not exists (select 1 from garage_reservations where garage_id = p_garage_id and status in ('pendente','confirmado') and inicio < p_fim and fim > p_inicio);
end;
$$ language plpgsql security definer;

create or replace function garage_calculate_price(p_garage_id uuid, p_tipo text, p_inicio timestamptz, p_fim timestamptz) returns numeric as $$
declare v_garage garages%rowtype; v_hours numeric; v_days numeric;
begin
  select * into v_garage from garages where id = p_garage_id;
  if not found then return 0; end if;
  case p_tipo
    when 'hora' then v_hours := extract(epoch from (p_fim - p_inicio)) / 3600.0; return round(v_hours * v_garage.preco_hora, 2);
    when 'dia' then v_days := extract(epoch from (p_fim - p_inicio)) / 86400.0; return round(ceil(v_days) * v_garage.preco_dia, 2);
    when 'mes' then return v_garage.preco_mes;
    else return 0;
  end case;
end;
$$ language plpgsql security definer;

create or replace function garage_create_reservation(p_garage_id uuid, p_placa text, p_modelo text, p_cor text, p_inicio timestamptz, p_fim timestamptz, p_tipo_periodo text default 'hora', p_observacao text default null) returns jsonb as $$
declare v_available boolean; v_valor numeric; v_garage garages%rowtype; v_reservation_id uuid;
begin
  select * into v_garage from garages where id = p_garage_id and ativo = true;
  if not found then return jsonb_build_object('success', false, 'error', 'Vaga não encontrada ou inativa'); end if;
  if v_garage.owner_id = auth.uid() then return jsonb_build_object('success', false, 'error', 'Você não pode reservar sua própria vaga'); end if;
  v_available := garage_check_availability(p_garage_id, p_inicio, p_fim);
  if not v_available then return jsonb_build_object('success', false, 'error', 'Vaga ocupada neste horário'); end if;
  v_valor := garage_calculate_price(p_garage_id, p_tipo_periodo, p_inicio, p_fim);
  insert into garage_reservations (garage_id, user_id, placa, modelo, cor, inicio, fim, tipo_periodo, valor_total, status, observacao)
  values (p_garage_id, auth.uid(), p_placa, p_modelo, p_cor, p_inicio, p_fim, p_tipo_periodo, v_valor, 'pendente', p_observacao)
  returning id into v_reservation_id;
  return jsonb_build_object('success', true, 'reservation_id', v_reservation_id, 'valor', v_valor);
end;
$$ language plpgsql security definer;
