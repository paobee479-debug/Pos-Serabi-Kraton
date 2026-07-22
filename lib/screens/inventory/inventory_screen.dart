import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../services/supabase_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Ingredient> ingredients = [];
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
    ingredients = await SupabaseService.instance.fetchIngredients(outletId: outletId);
    setState(() => loading = false);
  }

  void _showAdjustDialog(Ingredient ing) {
    final qtyCtrl = TextEditingController();
    String type = 'in';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('Update Stok: ${ing.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: type,
                items: const [
                  DropdownMenuItem(value: 'in', child: Text('Stok Masuk (pembelian)')),
                  DropdownMenuItem(value: 'out', child: Text('Stok Keluar (manual)')),
                  DropdownMenuItem(value: 'waste', child: Text('Waste / Rusak')),
                  DropdownMenuItem(value: 'adjustment', child: Text('Penyesuaian')),
                ],
                onChanged: (v) => setSt(() => type = v!),
              ),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Jumlah (${ing.unit})'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                final qty = double.tryParse(qtyCtrl.text) ?? 0;
                if (qty <= 0) return;
                await SupabaseService.instance.adjustStock(ingredientId: ing.id, qty: qty, type: type);
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMasterDataForm({Ingredient? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final unitCtrl = TextEditingController(text: existing?.unit ?? '');
    final stockCtrl = TextEditingController(text: existing != null ? existing.stockQty.toStringAsFixed(0) : '0');
    final minStockCtrl = TextEditingController(text: existing?.minStock.toStringAsFixed(0) ?? '');
    final costCtrl = TextEditingController(text: existing?.costPerUnit.toStringAsFixed(0) ?? '');
    final outletId = context.read<OutletProvider>().selectedOutletId
        ?? context.read<AuthProvider>().profile!.outletId
        ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Tambah Bahan Baku Baru' : 'Edit Data Bahan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama Bahan')),
              const SizedBox(height: 8),
              TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'Satuan (gram/ml/pcs)')),
              const SizedBox(height: 8),
              if (existing == null) ...[
                TextField(controller: stockCtrl, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Stok Awal')),
                const SizedBox(height: 8),
              ],
              TextField(controller: minStockCtrl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Batas Stok Minimum (alert)')),
              const SizedBox(height: 8),
              TextField(controller: costCtrl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Harga Beli per Satuan (Rp)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          if (existing != null)
            TextButton(
              onPressed: () async {
                await SupabaseService.instance.deleteIngredient(existing.id);
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('Hapus', style: TextStyle(color: AppColors.dapurRed)),
            ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final unit = unitCtrl.text.trim();
              final minStock = double.tryParse(minStockCtrl.text) ?? 0;
              final cost = double.tryParse(costCtrl.text) ?? 0;
              if (name.isEmpty || unit.isEmpty) return;

              if (existing == null) {
                final stock = double.tryParse(stockCtrl.text) ?? 0;
                await SupabaseService.instance.createIngredient(
                  name: name, unit: unit, stockQty: stock,
                  minStock: minStock, costPerUnit: cost, outletId: outletId,
                );
              } else {
                await SupabaseService.instance.updateIngredient(
                  id: existing.id, name: name, unit: unit,
                  minStock: minStock, costPerUnit: cost,
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

  @override
  Widget build(BuildContext context) {
    final selectedOutletId = context.watch<OutletProvider>().selectedOutletId;
    if (selectedOutletId != _lastOutletId && !loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    if (loading) return const Center(child: CircularProgressIndicator());
    final lowStock = ingredients.where((i) => i.isLowStock).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showMasterDataForm(),
        icon: const Icon(Icons.add),
        label: const Text('Bahan Baru'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (lowStock.isNotEmpty)
              Card(
                color: AppColors.dapurRed.withOpacity(0.08),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: AppColors.dapurRed),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${lowStock.length} bahan menipis: ${lowStock.map((e) => e.name).join(", ")}'),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            ...ingredients.map((ing) => Card(
                  child: ListTile(
                    leading: Icon(Icons.inventory_2,
                        color: ing.isLowStock ? AppColors.dapurRed : AppColors.kratonGreen),
                    title: Text(ing.name),
                    subtitle: Text('Stok: ${ing.stockQty} ${ing.unit} • Min: ${ing.minStock} ${ing.unit} • Harga: Rp${ing.costPerUnit.toStringAsFixed(0)}/${ing.unit}'),
                    onTap: () => _showMasterDataForm(existing: ing),
                    trailing: IconButton(
                      icon: const Icon(Icons.sync_alt),
                      tooltip: 'Update stok (masuk/keluar/waste)',
                      onPressed: () => _showAdjustDialog(ing),
                    ),
                  ),
                )),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
