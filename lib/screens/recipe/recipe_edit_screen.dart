import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../services/supabase_service.dart';

final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

/// Layar edit resep untuk 1 produk: tambah/ubah/hapus bahan baku + takaran.
/// HPP dihitung ulang secara live di layar ini (sum qty_used x cost_per_unit)
/// sebelum disimpan, jadi owner bisa lihat dampak perubahan resep langsung.
class RecipeEditScreen extends StatefulWidget {
  final Product product;
  const RecipeEditScreen({super.key, required this.product});

  @override
  State<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends State<RecipeEditScreen> {
  List<Map<String, dynamic>> recipeItems = [];
  List<Ingredient> allIngredients = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    recipeItems = await SupabaseService.instance.fetchRecipeItems(widget.product.id);
    allIngredients = await SupabaseService.instance.fetchIngredients();
    setState(() => loading = false);
  }

  double get _liveHpp {
    return recipeItems.fold<double>(0, (sum, item) {
      final qty = (item['qty_used'] as num).toDouble();
      final cost = (item['ingredients']['cost_per_unit'] as num).toDouble();
      return sum + (qty * cost);
    });
  }

  void _showAddIngredientDialog() {
    final usedIds = recipeItems.map((e) => e['ingredient_id']).toSet();
    final available = allIngredients.where((i) => !usedIds.contains(i.id)).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua bahan sudah ditambahkan ke resep ini')),
      );
      return;
    }
    Ingredient? selected = available.first;
    final qtyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Tambah Bahan ke Resep'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Ingredient>(
                value: selected,
                decoration: const InputDecoration(labelText: 'Bahan Baku'),
                items: available
                    .map((i) => DropdownMenuItem(value: i, child: Text('${i.name} (${i.unit})')))
                    .toList(),
                onChanged: (v) => setSt(() => selected = v),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Takaran per porsi (${selected?.unit ?? ''})',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                final qty = double.tryParse(qtyCtrl.text) ?? 0;
                if (qty <= 0 || selected == null) return;
                await SupabaseService.instance.addRecipeItem(
                  productId: widget.product.id,
                  ingredientId: selected!.id,
                  qtyUsed: qty,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('Tambah'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditQtyDialog(Map<String, dynamic> item) {
    final qtyCtrl = TextEditingController(text: '${item['qty_used']}');
    final ingredientName = item['ingredients']['name'];
    final unit = item['ingredients']['unit'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ubah Takaran: $ingredientName'),
        content: TextField(
          controller: qtyCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Takaran per porsi ($unit)'),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await SupabaseService.instance.deleteRecipeItem(item['id']);
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: const Text('Hapus Bahan', style: TextStyle(color: AppColors.dapurRed)),
          ),
          ElevatedButton(
            onPressed: () async {
              final qty = double.tryParse(qtyCtrl.text) ?? 0;
              if (qty <= 0) return;
              await SupabaseService.instance.updateRecipeItemQty(item['id'], qty);
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hpp = _liveHpp;
    final margin = widget.product.price - hpp;
    final marginPercent = widget.product.price == 0 ? 0 : (margin / widget.product.price) * 100;

    return Scaffold(
      appBar: AppBar(title: Text('Resep: ${widget.product.name}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddIngredientDialog,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Bahan'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: AppColors.kratonGreen.withOpacity(0.06),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Harga Jual: ${_rupiah.format(widget.product.price)}'),
                              Text('HPP (live): ${_rupiah.format(hpp)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.dapurRed)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Margin', style: TextStyle(fontSize: 12)),
                            Text('${marginPercent.toStringAsFixed(1)}%',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.kratonGreen, fontSize: 18)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Daftar Bahan (per 1 porsi)', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (recipeItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('Belum ada bahan di resep ini. Tap "Tambah Bahan".')),
                  ),
                ...recipeItems.map((item) {
                  final ing = item['ingredients'];
                  final qty = (item['qty_used'] as num).toDouble();
                  final cost = (ing['cost_per_unit'] as num).toDouble();
                  return Card(
                    child: ListTile(
                      title: Text(ing['name']),
                      subtitle: Text('${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2)} ${ing['unit']} × ${_rupiah.format(cost)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_rupiah.format(qty * cost), style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _showEditQtyDialog(item)),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 80), // ruang untuk FAB
              ],
            ),
    );
  }
}
