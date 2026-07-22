# POS Serabi Solo Kraton — Flutter + Supabase

Aplikasi POS F&B multi-platform (Android, tablet, web desktop) dengan tema
hijau-emas terinspirasi Kraton Surakarta & jajanan Serabi Solo.

## Fitur yang sudah dibangun

| Fitur | Status | Lokasi |
|---|---|---|
| POS kasir (grid produk + keranjang) | ✅ | `lib/screens/pos/pos_screen.dart` |
| Stok bahan baku + alert menipis | ✅ | `lib/screens/inventory/inventory_screen.dart` |
| HPP otomatis dari resep | ✅ | `supabase/schema.sql` (view `product_hpp`) + `lib/screens/recipe/recipe_screen.dart` |
| Laporan penjualan (grafik + per produk) | ✅ | `lib/screens/reports/reports_screen.dart` |
| Layar dapur real-time | ✅ | `lib/screens/orders/kitchen_screen.dart` |
| Input pesanan Offline/WA/GoFood/GrabFood/ShopeeFood | ✅ (manual entry, lihat catatan di bawah) | `lib/screens/orders/channel_orders_screen.dart` |
| Role owner/kasir/dapur + RLS | ✅ | `supabase/schema.sql` + `dashboard_shell.dart` |
| CRUD produk (tambah/edit/nonaktifkan menu) | ✅ | `lib/screens/recipe/product_manage_screen.dart` |
| CRUD bahan baku (master data) | ✅ | `lib/screens/inventory/inventory_screen.dart` |
| CRUD resep per produk + preview HPP live | ✅ | `lib/screens/recipe/recipe_edit_screen.dart` |
| Cetak PDF & bagikan JPG struk (thermal 58mm/80mm) | ✅ | `lib/services/receipt_service.dart` |
| Export laporan ke Excel & PDF | ✅ | `lib/services/export_service.dart` |
| Multi-outlet switching (owner) | ✅ | `lib/providers/app_providers.dart` (`OutletProvider`) + dropdown di AppBar |
| Responsif Android/tablet/web | ✅ | `NavigationRail` (lebar) vs `NavigationBar` (HP) |
| Tema hijau-emas Serabi Solo Kraton | ✅ | `lib/core/theme/app_theme.dart` |

## ⚠️ Catatan penting soal integrasi channel online

**GoFood, GrabFood, dan ShopeeFood tidak menyediakan API publik untuk pihak
ketiga.** Integrasi otomatis (auto-sync pesanan, auto-update menu) hanya
tersedia lewat partnership resmi antara pemilik resto dengan masing-masing
platform (butuh pengajuan merchant API/webhook langsung ke Gojek, Grab, atau
Shopee). Tanpa itu, cara kerja yang legal dan umum dipakai resto kecil-menengah:

1. **Manual/cepat input** — kasir mencatat pesanan yang masuk dari tablet
   partner (GoFood/GrabFood/ShopeeFood merchant app) ke POS ini lewat layar
   "Pesanan Channel", supaya stok bahan tetap otomatis terpotong dan laporan
   tetap akurat per channel.
2. **WhatsApp** — sudah diimplementasikan 2 cara:
   - Deep link `wa.me` untuk mengirim konfirmasi pesanan ke pelanggan (sudah jalan, tanpa approval apa pun).
   - Untuk chatbot otomatis / auto-reply order via WhatsApp, perlu **WhatsApp
     Business API** resmi (lewat Meta Business atau BSP seperti Qontak/Woztell) —
     ini butuh proses approval terpisah dan biaya per pesan.

Jika ke depan sudah punya akses partnership resmi, cukup ganti layer di
`lib/services/supabase_service.dart` dengan pemanggilan webhook/API partner,
struktur database (`sales_channel`, `orders`) sudah siap menampungnya.

## Setup

### 1. Supabase
1. Buat project baru di [supabase.com](https://supabase.com).
2. Buka **SQL Editor**, jalankan `supabase/schema.sql`.
3. (Opsional, untuk testing) jalankan `supabase/seed_data.sql`.
4. Buat user lewat **Authentication > Users**, lalu insert baris di tabel
   `profiles` dengan `role` = `owner` / `kasir` / `dapur` dan `outlet_id`
   sesuai outlet yang dibuat.
5. Aktifkan **Realtime** untuk tabel `orders` (Database > Replication) agar
   layar dapur bisa update live.
6. Salin `Project URL` dan `anon public key` dari Settings > API.

### 2. Flutter
```bash
flutter pub get

flutter run \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=xxxxxxxx
```

Untuk build web (desktop browser):
```bash
flutter build web \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=xxxxxxxx
```

Untuk build Android:
```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=xxxxxxxx
```

> Jangan hardcode URL/anon key di source code untuk repo publik — selalu
> pakai `--dart-define` atau file `.env` yang di-gitignore.

## Struktur Database Singkat

- `profiles` — user + role (owner/kasir/dapur), terhubung ke `auth.users`.
- `ingredients` — bahan baku + stok + harga per unit.
- `stock_movements` — histori masuk/keluar/waste/adjustment stok.
- `products` — menu jual.
- `recipe_items` — bahan baku per produk (dasar kalkulasi HPP).
- `product_hpp` (view) — HPP & margin dihitung otomatis dari resep.
- `orders` / `order_items` — transaksi, dengan `channel` (offline/whatsapp/
  gofood/grabfood/shopeefood) dan `hpp_snapshot` supaya laporan laba tetap
  akurat walau harga bahan berubah di kemudian hari.
- Trigger `fn_deduct_stock_on_order_complete` — otomatis potong stok bahan
  saat order berstatus `completed`.
- `sales_report_daily` / `sales_report_by_product` (view) — dasar laporan.
- Row Level Security aktif per role.

## Cara kerja cetak/bagikan struk

Setelah checkout berhasil (Kasir maupun Pesanan Channel), muncul bottom sheet
dengan 2 pilihan:

1. **Bagikan sebagai JPG** — struk dirender jadi gambar (via rasterisasi PDF
   ke PNG lalu di-encode ke JPG kualitas 90), kemudian dibuka lewat share
   sheet native (bisa langsung kirim ke WhatsApp, simpan ke galeri, dll).
   Ini yang paling praktis untuk dikirim ke pelanggan lewat chat, dan
   berjalan sama di Android, tablet, maupun web (`XFile.fromData`, tidak
   pakai akses filesystem langsung sehingga aman untuk web).
2. **Cetak PDF** — untuk printer thermal fisik, lewat `Printing.layoutPdf()`
   dari package `printing`. Di Android/tablet membuka dialog print/share, di
   web browser membuka print dialog atau unduh PDF.

Kedua opsi memakai layout struk yang sama (`ReceiptService._buildDoc`),
ukuran default 58mm (bisa diganti ke 80mm lewat parameter `paperWidth`).

## Build & Deploy Versi Web (Cara Paling Mudah — Direkomendasikan)

Sudah disediakan `.github/workflows/deploy-web.yml`. Setiap kamu push ke
branch `main`, GitHub otomatis build versi web dan publish ke GitHub Pages
— jadi kasir/dapur/owner tinggal buka satu link lewat browser (HP, tablet,
atau desktop), tanpa install apa pun.

**Setup sekali saja:**

1. Upload project ini ke repo GitHub (nama bebas, misal `pos-serabi-kraton`).
2. Buka repo → **Settings → Pages** → di bagian "Build and deployment",
   pilih **Source: GitHub Actions**.
3. Buka repo → **Settings → Secrets and variables → Actions** → **New
   repository secret**, tambahkan 2 secret:
   - `SUPABASE_URL` → Project URL dari Supabase Settings > API
   - `SUPABASE_ANON_KEY` → anon public key dari Supabase Settings > API
4. Push project (atau kalau sudah pernah push, cukup buat perubahan kecil
   lalu push lagi, atau jalankan workflow manual lewat tab **Actions →
   Build & Deploy Web → Run workflow**).
5. Tunggu ~3-5 menit, cek tab **Actions** sampai centang hijau muncul.
6. Buka `https://USERNAME.github.io/pos-serabi-kraton/` (ganti `USERNAME`
   dan nama repo sesuai punya kamu) — aplikasi sudah bisa dipakai.

**Kelebihan jalur ini dibanding build APK Android:**
- Tidak perlu Codemagic, tidak perlu install APK manual, tidak ada warning
  "sumber tidak dikenal" di Android.
- Update otomatis: push kode baru → refresh browser → langsung dapat versi
  terbaru, tanpa install ulang.
- Bagikan struk (JPG) tetap jalan lewat Web Share API browser di HP (Chrome/
  Safari Android & iOS umumnya mendukung share file langsung ke WhatsApp).
  Di browser desktop, dukungan share file lewat Web Share API bervariasi —
  kalau tidak didukung, package `share_plus` akan mencoba fallback (biasanya
  unduh file). Untuk kasir yang kerja dari HP/tablet, ini seharusnya lancar.
- Cetak PDF ke printer thermal Bluetooth kurang optimal lewat web
  dibanding native Android — kalau printer fisik jadi kebutuhan wajib nanti,
  APK Android (lewat Codemagic, lihat bagian di bawah) lebih cocok. Untuk
  sekarang karena fokusnya share struk lewat WhatsApp, versi web ini sudah cukup.

## Build APK Tanpa PC (Opsional, via Codemagic — untuk nanti kalau butuh print fisik)

Sudah disediakan `codemagic.yaml` di root project. Cara pakai:

1. Upload project ini ke repository GitHub (private disarankan, karena nanti
   ada kredensial Supabase yang disimpan sebagai environment variable).
2. Daftar di [codemagic.io](https://codemagic.io) pakai akun GitHub yang sama.
3. **Add application** → pilih repo project ini. Codemagic otomatis mendeteksi
   `codemagic.yaml`.
4. Buka **Environment variables** di dashboard Codemagic, buat grup baru
   bernama `supabase_credentials`, isi 2 variable:
   - `SUPABASE_URL` → Project URL dari Supabase Settings > API
   - `SUPABASE_ANON_KEY` → anon public key dari Supabase Settings > API
   - Centang "Secure" supaya nilainya terenkripsi.
5. Edit baris `recipients` di `codemagic.yaml` dengan email kamu (opsional,
   untuk notifikasi saat build selesai).
6. Jalankan **Start new build** → pilih workflow `android-workflow`.
7. Setelah build selesai (~10-15 menit), APK bisa diunduh langsung dari
   halaman build Codemagic (bagian **Artifacts**), lalu install di HP Android.

> Build pertama biasanya lebih lama karena Codemagic perlu download semua
> dependency. Build berikutnya jauh lebih cepat karena ada caching.


Hanya **owner** yang melihat dropdown outlet di AppBar (ikon toko).
Pilihan "Semua Outlet" menggabungkan data dari semua cabang (khusus di
layar Laporan); memilih outlet tertentu akan memfilter Kasir, Stok, Produk,
Dapur, dan Laporan supaya hanya menampilkan data outlet itu. Kasir dan dapur
tidak melihat dropdown ini — mereka otomatis terkunci ke `outlet_id` yang
tertaut di profil masing-masing (tabel `profiles`).

Jika kamu sudah pernah menjalankan `schema.sql` versi lama sebelum fitur ini
ditambahkan, jalankan `supabase/migration_001_outlet_reports.sql` supaya
view laporan punya kolom `outlet_id`. Instalasi baru cukup pakai
`schema.sql` (sudah termasuk perubahan ini).

## Yang masih perlu dikembangkan (belum termasuk di scaffold ini)

- Login biometrik/PIN cepat untuk kasir di tablet.
- Push notification ke dapur (saat ini mengandalkan Supabase Realtime +
  polling UI, belum ada notifikasi push saat app di background).

## Struktur Folder

```
lib/
  core/theme/app_theme.dart        # warna hijau-emas Serabi Solo Kraton
  models/models.dart               # semua model data
  services/supabase_service.dart   # semua query Supabase
  providers/app_providers.dart     # auth & cart state
  screens/
    auth/login_screen.dart
    dashboard/dashboard_shell.dart # navigasi berbasis role, responsif
    pos/pos_screen.dart
    inventory/inventory_screen.dart      # + CRUD master data bahan baku
    recipe/product_manage_screen.dart    # CRUD produk
    recipe/recipe_edit_screen.dart       # CRUD bahan per produk + preview HPP live
    reports/reports_screen.dart
    orders/channel_orders_screen.dart
    orders/kitchen_screen.dart
supabase/
  schema.sql
  seed_data.sql
```
