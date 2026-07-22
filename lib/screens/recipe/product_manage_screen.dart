import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../services/supabase_service.dart';
import 'recipe_edit_screen.dart';

final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

/// Layar kelola menu: tambah produk baru, edit nama/harga/kategori,
/// nonaktifkan produk (soft delete), dan langsung masuk ke editor resep
/// per produk untuk mengatur HPP.
class ProductManageScreen extends StatefulWidget {
  const ProductManageScreen({super.key});

  @override
  State<ProductManageScreen> createState() => _ProductManageScreenState();
}

class _ProductManageScreenState extends State<ProductManageScreen> {
  List<Product> products = [];
  bool loading = true;
  String? _lastOutletId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final outletId = context.read<OutletProvider>().selectedOutletId
        ?? context.read<AuthProvider>().profile!.outletId;
    _lastOutletId = outletId;
    products = await SupabaseService.instance.fetchProductsWithHpp(outletId: outletId);
    setState(() => loading = false);
  }

  void _showProductForm({Product? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final categoryCtrl = TextEditingController(text: existing?.category ?? '');
    final priceCtrl = TextEditingController(text: existing != null ? existing.price.toStringAsFixed(0) : '');
    final outletId = context.read<OutletProvider>().selectedOutletId
        ?? context.read<AuthProvider>().profile!.outletId
        ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Tambah Produk Baru' : 'Edit Produk'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama Produk')),
            const SizedBox(height: 8),
            TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'Kategori (opsional)')),
            const SizedBox(height: 8),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Harga Jual (Rp)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text) ?? 0;
              if (name.isEmpty || price <= 0) return;

              if (existing == null) {
                await SupabaseService.instance.createProduct(
                  name: name,
                  category: categoryCtrl.text.trim().isEmpty ? null : categoryCtrl.text.trim(),
                  price: price,
                  outletId: outletId,
                );
              } else {
                await SupabaseService.instance.updateProduct(
                  id: existing.id,
                  name: name,
                  category: categoryCtrl.text.trim().isEmpty ? null : categoryCtrl.text.trim(),
                  price: price,
                );
              }
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Product p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nonaktifkan Produk?'),
        content: Text('"${p.name}" tidak akan muncul lagi di kasir, tapi histori transaksi tetap aman.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.dapurRed),
            onPressed: () async {
              await SupabaseService.instance.deleteProduct(p.id);
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: const Text('Nonaktifkan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedOutletId = context.watch<OutletProvider>().selectedOutletId;
    if (selectedOutletId != _lastOutletId && !loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductForm(),
        icon: const Icon(Icons.add),
        label: const Text('Produk Baru'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: products.length,
                itemBuilder: (_, i) {
                  final p = products[i];
                  return Card(
                    child: ListTile(
                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          '${p.category ?? "Tanpa kategori"} • ${_rupiah.format(p.price)} • HPP ${_rupiah.format(p.hpp)}'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => RecipeEditScreen(product: p)),
                      ).then((_) => _load()),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit), onPressed: () => _showProductForm(existing: p)),
                          IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.dapurRed),
                              onPressed: () => _confirmDelete(p)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
