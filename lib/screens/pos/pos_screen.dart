import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../services/supabase_service.dart';
import '../../widgets/receipt_options_sheet.dart';

final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  List<Product> products = [];
  bool loading = true;
  String search = '';
  String? _lastOutletId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final outletId = context.read<OutletProvider>().selectedOutletId
          ?? context.read<AuthProvider>().profile!.outletId;
      _lastOutletId = outletId;
      products = await SupabaseService.instance.fetchProductsWithHpp(outletId: outletId);
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedOutletId = context.watch<OutletProvider>().selectedOutletId;
    if (selectedOutletId != _lastOutletId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    final cart = context.watch<CartProvider>();
    final wide = MediaQuery.of(context).size.width > 700;
    final filtered = products.where((p) => p.name.toLowerCase().contains(search.toLowerCase())).toList();

    final productGrid = Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(hintText: 'Cari produk...', prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => search = v),
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.1,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final p = filtered[i];
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => cart.addProduct(p),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: AppColors.pradaGold.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.local_dining, size: 36, color: AppColors.kratonGreen),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(_rupiah.format(p.price),
                                  style: const TextStyle(color: AppColors.kratonGreen, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );

    final cartPanel = _CartPanel(onCheckoutDone: _load);

    if (wide) {
      return Row(
        children: [
          Expanded(flex: 3, child: productGrid),
          const VerticalDivider(width: 1),
          Expanded(flex: 2, child: cartPanel),
        ],
      );
    }
    // Mobile: produk full-screen + tombol keranjang mengambang
    return Stack(
      children: [
        productGrid,
        if (cart.items.isNotEmpty)
          Positioned(
            bottom: 16, left: 16, right: 16,
            child: ElevatedButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => FractionallySizedBox(
                  heightFactor: 0.85,
                  child: cartPanel,
                ),
              ),
              child: Text('Keranjang (${cart.items.length}) • ${_rupiah.format(cart.total)}'),
            ),
          ),
      ],
    );
  }
}

class _CartPanel extends StatelessWidget {
  final VoidCallback onCheckoutDone;
  const _CartPanel({required this.onCheckoutDone});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final auth = context.read<AuthProvider>();

    return Container(
      color: AppColors.santanWhite,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<SalesChannel>(
              value: cart.channel,
              decoration: const InputDecoration(labelText: 'Channel Penjualan'),
              items: SalesChannel.values
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                  .toList(),
              onChanged: (c) => c != null ? cart.setChannel(c) : null,
            ),
          ),
          Expanded(
            child: cart.items.isEmpty
                ? const Center(child: Text('Keranjang kosong'))
                : ListView.builder(
                    itemCount: cart.items.length,
                    itemBuilder: (_, i) {
                      final item = cart.items[i];
                      return ListTile(
                        title: Text(item.product.name),
                        subtitle: Text(_rupiah.format(item.product.price)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => cart.decreaseQty(item.product.id)),
                            Text('${item.qty}'),
                            IconButton(icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => cart.addProduct(item.product)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _summaryRow('Subtotal', cart.subtotal),
                _summaryRow('Diskon', -cart.discount),
                _summaryRow('Pajak', cart.tax),
                const Divider(),
                _summaryRow('Total', cart.total, bold: true),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: cart.items.isEmpty
                        ? null
                        : () async {
                            final checkedOutItems = List<CartItem>.from(cart.items);
                            final channel = cart.channel;
                            final subtotal = cart.subtotal;
                            final discount = cart.discount;
                            final tax = cart.tax;
                            final total = cart.total;

                            final orderOutletId = context.read<OutletProvider>().selectedOutletId
                                ?? auth.profile!.outletId
                                ?? '';
                            final order = await SupabaseService.instance.createOrder(
                              items: checkedOutItems,
                              channel: channel,
                              subtotal: subtotal,
                              discount: discount,
                              tax: tax,
                              total: total,
                              cashierId: auth.profile!.id,
                              outletId: orderOutletId,
                            );
                            cart.clear();
                            onCheckoutDone();
                            if (context.mounted) {
                              Navigator.of(context).maybePop();
                              showReceiptOptions(
                                context: context,
                                orderNumber: order['order_number'],
                                cashierName: auth.profile!.fullName,
                                channel: channel,
                                items: checkedOutItems,
                                subtotal: subtotal,
                                discount: discount,
                                tax: tax,
                                total: total,
                              );
                            }
                          },
                    child: const Text('Bayar & Kirim ke Dapur'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(_rupiah.format(value), style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
