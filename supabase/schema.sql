-- ============================================================
-- POS Serabi Solo Kraton - Supabase Schema
-- Multi-platform F&B POS: kasir, stok, HPP, laporan, multi-channel
-- ============================================================

-- 1. ROLES & USERS -------------------------------------------------
create type user_role as enum ('owner', 'kasir', 'dapur');

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role user_role not null default 'kasir',
  outlet_id uuid,
  is_active boolean default true,
  created_at timestamptz default now()
);

create table outlets (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address text,
  created_at timestamptz default now()
);

alter table profiles
  add constraint fk_outlet foreign key (outlet_id) references outlets(id);

-- 2. BAHAN BAKU (INGREDIENTS) & STOK --------------------------------
create table ingredients (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  unit text not null,              -- gram, ml, pcs, dll
  stock_qty numeric not null default 0,
  min_stock numeric default 0,     -- untuk alert stok menipis
  cost_per_unit numeric not null default 0, -- harga beli per unit satuan
  outlet_id uuid references outlets(id),
  updated_at timestamptz default now()
);

create table stock_movements (
  id uuid primary key default gen_random_uuid(),
  ingredient_id uuid references ingredients(id) on delete cascade,
  type text not null check (type in ('in','out','adjustment','waste')),
  qty numeric not null,
  note text,
  ref_order_id uuid,
  created_by uuid references profiles(id),
  created_at timestamptz default now()
);

-- 3. PRODUK & RESEP (untuk HPP) --------------------------------------
create table products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text,
  price numeric not null,
  image_url text,
  is_active boolean default true,
  outlet_id uuid references outlets(id),
  created_at timestamptz default now()
);

create table recipe_items (
  id uuid primary key default gen_random_uuid(),
  product_id uuid references products(id) on delete cascade,
  ingredient_id uuid references ingredients(id) on delete cascade,
  qty_used numeric not null   -- jumlah bahan per 1 porsi produk
);

-- View HPP otomatis: total biaya bahan per produk
create view product_hpp as
select
  p.id as product_id,
  p.name as product_name,
  p.price as sell_price,
  coalesce(sum(ri.qty_used * i.cost_per_unit), 0) as hpp,
  p.price - coalesce(sum(ri.qty_used * i.cost_per_unit), 0) as margin,
  case when p.price > 0 then
    round(((p.price - coalesce(sum(ri.qty_used * i.cost_per_unit), 0)) / p.price) * 100, 2)
  else 0 end as margin_percent
from products p
left join recipe_items ri on ri.product_id = p.id
left join ingredients i on i.id = ri.ingredient_id
group by p.id, p.name, p.price;

-- 4. CHANNEL PENJUALAN -------------------------------------------------
create type sales_channel as enum ('offline','whatsapp','gofood','grabfood','shopeefood');

-- 5. ORDER / TRANSAKSI --------------------------------------------------
create type order_status as enum ('pending','in_kitchen','ready','completed','cancelled');

create table orders (
  id uuid primary key default gen_random_uuid(),
  order_number text unique not null,
  channel sales_channel not null default 'offline',
  status order_status not null default 'pending',
  customer_name text,
  customer_phone text,
  subtotal numeric not null default 0,
  discount numeric default 0,
  tax numeric default 0,
  total numeric not null default 0,
  payment_method text,
  outlet_id uuid references outlets(id),
  cashier_id uuid references profiles(id),
  notes text,
  created_at timestamptz default now(),
  completed_at timestamptz
);

create table order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references orders(id) on delete cascade,
  product_id uuid references products(id),
  qty integer not null,
  price numeric not null,
  hpp_snapshot numeric default 0,  -- HPP saat transaksi (untuk laporan akurat)
  note text
);

-- 6. TRIGGER: potong stok otomatis saat order completed ------------------
create or replace function fn_deduct_stock_on_order_complete()
returns trigger as $$
begin
  if new.status = 'completed' and old.status <> 'completed' then
    insert into stock_movements (ingredient_id, type, qty, note, ref_order_id, created_by)
    select ri.ingredient_id, 'out', ri.qty_used * oi.qty,
           'Auto deduct order ' || new.order_number, new.id, new.cashier_id
    from order_items oi
    join recipe_items ri on ri.product_id = oi.product_id
    where oi.order_id = new.id;

    update ingredients i
    set stock_qty = stock_qty - sub.total_qty, updated_at = now()
    from (
      select ri.ingredient_id, sum(ri.qty_used * oi.qty) as total_qty
      from order_items oi
      join recipe_items ri on ri.product_id = oi.product_id
      where oi.order_id = new.id
      group by ri.ingredient_id
    ) sub
    where i.id = sub.ingredient_id;
  end if;
  return new;
end;
$$ language plpgsql security definer;

create trigger trg_deduct_stock
after update on orders
for each row execute function fn_deduct_stock_on_order_complete();

-- 7. VIEW LAPORAN PENJUALAN ------------------------------------------
create view sales_report_daily as
select
  date_trunc('day', o.created_at) as sale_date,
  o.channel,
  o.outlet_id,
  count(distinct o.id) as total_orders,
  sum(o.total) as total_revenue,
  sum(oi.qty * oi.hpp_snapshot) as total_hpp,
  sum(o.total) - sum(oi.qty * oi.hpp_snapshot) as gross_profit
from orders o
join order_items oi on oi.order_id = o.id
where o.status = 'completed'
group by 1, 2, 3
order by 1 desc;

create view sales_report_by_product as
select
  p.name as product_name,
  o.outlet_id,
  count(oi.id) as times_sold,
  sum(oi.qty) as total_qty,
  sum(oi.qty * oi.price) as total_revenue,
  sum(oi.qty * oi.hpp_snapshot) as total_hpp
from order_items oi
join products p on p.id = oi.product_id
join orders o on o.id = oi.order_id
where o.status = 'completed'
group by p.name, o.outlet_id
order by total_revenue desc;

-- 8. ROW LEVEL SECURITY -------------------------------------------------
alter table orders enable row level security;
alter table order_items enable row level security;
alter table ingredients enable row level security;
alter table products enable row level security;
alter table profiles enable row level security;

-- Owner: full access
create policy owner_full_access on orders for all
  using (exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'owner'));

-- Kasir: bisa lihat & buat order di outlet-nya
create policy kasir_order_access on orders for all
  using (
    exists (
      select 1 from profiles p
      where p.id = auth.uid() and p.role = 'kasir' and p.outlet_id = orders.outlet_id
    )
  );

-- Dapur: hanya bisa lihat & update status order (read + update status)
create policy dapur_read_orders on orders for select
  using (exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'dapur'));

create policy dapur_update_status on orders for update
  using (exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'dapur'));

-- Semua user login bisa baca produk & ingredient (read-only untuk non-owner)
create policy read_products on products for select using (auth.role() = 'authenticated');
create policy read_ingredients on ingredients for select using (auth.role() = 'authenticated');
create policy owner_manage_products on products for insert with check (
  exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'owner')
);
create policy owner_manage_ingredients on ingredients for all using (
  exists (select 1 from profiles p where p.id = auth.uid() and p.role = 'owner')
);

create policy own_profile on profiles for select using (auth.uid() = id or exists(
  select 1 from profiles p where p.id = auth.uid() and p.role = 'owner'
));
