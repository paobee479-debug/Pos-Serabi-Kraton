-- Migrasi: tambah outlet_id ke view laporan penjualan (untuk multi-outlet switching)
-- Jalankan ini di SQL Editor Supabase JIKA sebelumnya sudah menjalankan schema.sql versi lama.
-- Jika baru setup dari nol, cukup jalankan schema.sql (sudah termasuk perubahan ini).

drop view if exists sales_report_daily;
drop view if exists sales_report_by_product;

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
