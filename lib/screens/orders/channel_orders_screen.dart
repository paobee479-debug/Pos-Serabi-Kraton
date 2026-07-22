import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../services/supabase_service.dart';
import '../../widgets/receipt_options_sheet.dart';

/// Karena GoFood/GrabFood/ShopeeFood tidak menyediakan API publik untuk
/// pihak ketiga (integrasi resmi hanya lewat partnership langsung dengan
/// merchant), layar ini berfungsi sebagai input cepat: kasir mencatat
/// pesanan yang masuk dari partner apps ke sistem POS agar stok & laporan
/// tetap sinkron. WhatsApp menggunakan deep-link wa.me untuk kirim struk.
class ChannelOrdersScreen extends StatefulWidget {
  const ChannelOrdersScreen({super.key});

  @override
  State<ChannelOrdersScreen> createState() => _ChannelOrdersScreenState();
}

class _ChannelOrdersScreenState extends State<ChannelOrdersScreen> {
  SalesChannel selectedChannel = SalesChannel.whatsapp;
  List<Product> products = [];
  final Map<String, int> qtyMap = {};
  final phoneCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? _lastOutletId;

  Future<void> _load() async {
    final outletId = context.read<OutletProvider>().selectedOutletId
        ?? context.read<AuthProvider>().profile!.outletId;
    _lastOutletId = outletId;
    products = await SupabaseService.instance.fetchProductsWithHpp(outletId: outletId);
    setState(() => loading = false);
  }

  Future<void> _submitOrder() async {
    final auth = context.read<AuthProvider>();
    final items = <CartItem>[];
    qtyMap.forEach((id, qty) {
      if (qty > 0) {
        final p = products.firstWhere((p) => p.id == id);
        items.add(CartItem(product: p, qty: qty));
      }
    });
    if (items.isEmpty) return;

    final subtotal = items.fold<double>(0, (s, i) => s + i.subtotal);
    final orderOutletId = context.read<OutletProvider>().selectedOutletId
        ?? auth.profile!.outletId
        ?? '';
    final order = await SupabaseService.instance.createOrder(
      items: items,
      channel: selectedChannel,
      subtotal: subtotal,
      discount: 0,
      tax: 0,
      total: subtotal,
      customerName: nameCtrl.text.isEmpty ? null : nameCtrl.text,
      customerPhone: phoneCtrl.text.isEmpty ? null : phoneCtrl.text,
      cashierId: auth.profile!.id,
      outletId: orderOutletId,
    );

    if (selectedChannel == SalesChannel.whatsapp && phoneCtrl.text.isNotEmpty) {
      await _sendWhatsAppConfirmation(phoneCtrl.text, items, subtotal);
    }

    setState(() => qtyMap.clear());
    if (mounted) {
      showReceiptOptions(
        context: context,
        orderNumber: order['order_number'],
        cashierName: auth.profile!.fullName,
        channel: selectedChannel,
        items: items,
        subtotal: subtotal,
        discount: 0,
        tax: 0,
        total: subtotal,
        customerName: nameCtrl.text,
      );
      nameCtrl.clear();
      phoneCtrl.clear();
    }
  }

  Future<void> _sendWhatsAppConfirmation(String phone, List<CartItem> items, double total) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final waPhone = cleaned.startsWith('0') ? '62${cleaned.substring(1)}' : cleaned;
    final itemLines = items.map((i) => '- ${i.product.name} x${i.qty}').join('\n');
    final message = Uri.encodeComponent(
        'Halo! Pesanan Anda di Serabi Solo Kraton sudah kami terima:\n$itemLines\n\nTotal: Rp${total.toStringAsFixed(0)}\nTerima kasih 🙏');
    final url = Uri.parse('https://wa.me/$waPhone?text=$message');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final selectedOutletId = context.watch<OutletProvider>().selectedOutletId;
    if (selectedOutletId != _lastOutletId && !loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    if (loading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: AppColors.pradaGold.withOpacity(0.1),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Catat pesanan yang masuk dari WhatsApp / GoFood / GrabFood / ShopeeFood '
                'agar stok & laporan tetap akurat. Integrasi otomatis butuh partnership resmi '
                'dengan masing-masing platform.',
                style: TextStyle(fontSize: 12.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: SalesChannel.values.where((c) => c != SalesChannel.offline).map((c) {
              return ChoiceChip(
                label: Text(c.label),
                selected: selectedChannel == c,
                onSelected: (_) => setState(() => selectedChannel = c),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          if (selectedChannel == SalesChannel.whatsapp) ...[
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama Pelanggan')),
            const SizedBox(height: 8),
            TextField(controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'No. WhatsApp (untuk kirim konfirmasi)'),
                keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
          ],
          Text('Pilih Produk', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...products.map((p) {
            final qty = qtyMap[p.id] ?? 0;
            return Card(
              child: ListTile(
                title: Text(p.name),
                subtitle: Text('Rp${p.price.toStringAsFixed(0)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.remove_circle_outline),
                        onPressed: qty > 0 ? () => setState(() => qtyMap[p.id] = qty - 1) : null),
                    Text('$qty'),
                    IconButton(icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => setState(() => qtyMap[p.id] = qty + 1)),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('Catat Pesanan & Kirim ke Dapur'),
              onPressed: _submitOrder,
            ),
          ),
        ],
      ),
    );
  }
}
