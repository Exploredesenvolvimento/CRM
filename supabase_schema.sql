-- ═══════════════════════════════════════════════
-- EXPLORE CRM — Schema Supabase
-- Cole este SQL no Supabase SQL Editor e execute
-- ═══════════════════════════════════════════════

-- Habilitar extensões
create extension if not exists "uuid-ossp";

-- ── PERFIS DE USUÁRIO ──────────────────────────
create table if not exists profiles (
  id uuid references auth.users on delete cascade primary key,
  nome text not null,
  cargo text,
  email text,
  avatar_url text,
  created_at timestamptz default now()
);

-- ── EMPRESAS (Leads e Clientes) ────────────────
create table if not exists empresas (
  id uuid default uuid_generate_v4() primary key,
  nome text not null,
  segmento text,
  cnpj text,
  cidade text,
  estado text,
  site text,
  linkedin text,
  funcionarios text,
  status text default 'Lead' check (status in ('Lead','Prospect','Cliente Ativo','Cliente Inativo','Parceiro')),
  origem text check (origem in ('Indicação','Site','LinkedIn','Prospecção Ativa','Evento','Outro')),
  responsavel_id uuid references profiles(id),
  notas text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ── CONTATOS ──────────────────────────────────
create table if not exists contatos (
  id uuid default uuid_generate_v4() primary key,
  empresa_id uuid references empresas(id) on delete cascade,
  nome text not null,
  cargo text,
  email text,
  whatsapp text,
  principal boolean default false,
  created_at timestamptz default now()
);

-- ── OPORTUNIDADES (Pipeline) ──────────────────
create table if not exists oportunidades (
  id uuid default uuid_generate_v4() primary key,
  empresa_id uuid references empresas(id) on delete cascade,
  titulo text not null,
  servico text check (servico in ('Diagnóstico Organizacional','Recrutamento & Seleção','Desenvolvimento de Liderança','Planejamento Estratégico','Estruturação de Processos','Gestão de Pessoas','NR-1','Programa Completo')),
  etapa text default 'Prospecção' check (etapa in ('Prospecção','Qualificação','Proposta Enviada','Negociação','Fechado Ganho','Fechado Perdido')),
  valor numeric(12,2),
  probabilidade integer default 20 check (probabilidade between 0 and 100),
  responsavel_id uuid references profiles(id),
  data_proximo_contato date,
  link_proposta text,
  link_formulario text,
  notas text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ── PROJETOS ATIVOS ───────────────────────────
create table if not exists projetos (
  id uuid default uuid_generate_v4() primary key,
  empresa_id uuid references empresas(id) on delete cascade,
  oportunidade_id uuid references oportunidades(id),
  titulo text not null,
  servico text,
  valor_contrato numeric(12,2),
  data_inicio date,
  data_prevista_fim date,
  responsavel_id uuid references profiles(id),
  status text default 'Em Andamento' check (status in ('Em Andamento','Pausado','Concluído','Cancelado')),
  link_proposta text,
  link_formulario text,
  notas text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ── ENTREGAS DO PROJETO ───────────────────────
create table if not exists entregas (
  id uuid default uuid_generate_v4() primary key,
  projeto_id uuid references projetos(id) on delete cascade,
  titulo text not null,
  descricao text,
  data_prevista date,
  data_realizada date,
  status text default 'Pendente' check (status in ('Pendente','Em Andamento','Concluído','Atrasado')),
  responsavel_id uuid references profiles(id),
  created_at timestamptz default now()
);

-- ── INTERAÇÕES ────────────────────────────────
create table if not exists interacoes (
  id uuid default uuid_generate_v4() primary key,
  empresa_id uuid references empresas(id) on delete cascade,
  oportunidade_id uuid references oportunidades(id),
  projeto_id uuid references projetos(id),
  tipo text check (tipo in ('Ligação','Reunião','E-mail','WhatsApp','Proposta Enviada','Contrato','Outro')),
  descricao text not null,
  data timestamptz default now(),
  usuario_id uuid references profiles(id),
  created_at timestamptz default now()
);

-- ── PROSPECÇÃO ────────────────────────────────
create table if not exists prospeccao (
  id uuid default uuid_generate_v4() primary key,
  empresa_id uuid references empresas(id) on delete cascade,
  canal text check (canal in ('WhatsApp','Ligação','E-mail','LinkedIn','Visita','Evento')),
  status text default 'Não Contatado' check (status in ('Não Contatado','Tentativa','Contatado','Sem Interesse','Qualificado')),
  tentativas integer default 0,
  ultima_tentativa timestamptz,
  proximo_followup date,
  responsavel_id uuid references profiles(id),
  notas text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ── ROW LEVEL SECURITY ────────────────────────
alter table profiles enable row level security;
alter table empresas enable row level security;
alter table contatos enable row level security;
alter table oportunidades enable row level security;
alter table projetos enable row level security;
alter table entregas enable row level security;
alter table interacoes enable row level security;
alter table prospeccao enable row level security;

-- Políticas: apenas usuários autenticados acessam
create policy "Autenticados leem profiles" on profiles for select using (auth.role() = 'authenticated');
create policy "Autenticados gerenciam empresas" on empresas for all using (auth.role() = 'authenticated');
create policy "Autenticados gerenciam contatos" on contatos for all using (auth.role() = 'authenticated');
create policy "Autenticados gerenciam oportunidades" on oportunidades for all using (auth.role() = 'authenticated');
create policy "Autenticados gerenciam projetos" on projetos for all using (auth.role() = 'authenticated');
create policy "Autenticados gerenciam entregas" on entregas for all using (auth.role() = 'authenticated');
create policy "Autenticados gerenciam interacoes" on interacoes for all using (auth.role() = 'authenticated');
create policy "Autenticados gerenciam prospeccao" on prospeccao for all using (auth.role() = 'authenticated');

-- Criar perfil automaticamente ao cadastrar usuário
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, nome)
  values (new.id, new.email, split_part(new.email, '@', 1));
  return new;
end;
$$ language plpgsql security definer;

create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ── DADOS INICIAIS ────────────────────────────
-- Inserir etapas de referência para ordenação
comment on column oportunidades.etapa is 'Ordem: Prospecção(1) > Qualificação(2) > Proposta Enviada(3) > Negociação(4) > Fechado Ganho(5) > Fechado Perdido(6)';
