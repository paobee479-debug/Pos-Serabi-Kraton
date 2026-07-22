import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../services/supabase_service.dart';

/// Layar dapur menampilkan antrian pesanan secara real-time (Supabase
/// Realtime stream) yang berstatus 'pending' atau 'in_kitchen'.
/// Dapur cukup tap kartu untuk memindahkan status: pending -> in_kitchen
/// -> ready -> completed (yang otomatis memicu potong stok bahan baku
/// lewat trigger `fn_deduct_stock_on_order_complete`).
/// Jika owner sedang memilih outlet tertentu (bukan "Semua Outlet"), hanya
/// order dari outlet itu yang tampil. Kasir/dapur otomatis terbatas ke
/// outlet mereka sendiri.
class KitchenScreen extends StatelessWidget {
  const KitchenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final outletProvider = context.watch<OutletProvider>();
    final auth = context.read<AuthProvider>();
    final filterOutletId = outletProvider.selectedOutletId ?? auth.profile!.outletId;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.instance.watchKitchenOrders(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var orders = snapshot.data!;
        if (filterOutletId != null) {
          orders = orders.where((o) => o['outlet_id'] == filterOutletId).toList();
        }
        if (orders.isEmpty) {
          return const Center(child: Text('Tidak ada pesanan aktif 🎉'));
        }
        final wide = MediaQuery.of(context).size.width > 700;
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: wide ? 4 : 2,
            childAspectRatio: 0.9,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: orders.length,
          itemBuilder: (_, i) => _OrderCard(order: orders[i]),
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  const _OrderCard({required this.order});

  Color get _statusColor {
    switch (order['status']) {
      case 'pending':
        return AppColors.dapurRed;
      case 'in_kitchen':
        return AppColors.pradaGold;
      default:
        return AppColors.kratonGreen;
    }
  }

  String get _nextStatus {
    switch (order['status']) {
      case 'pending':
        return 'in_kitchen';
      case 'in_kitchen':
        return 'ready';
      default:
        return 'completed';
    }
  }

  String get _actionLabel {
    switch (order['status']) {
      case 'pending':
        return 'Mulai Masak';
      case 'in_kitchen':
        return 'Tandai Siap';
      default:
        return 'Selesai / Diambil';
    }
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.tryParse(order['created_at'] ?? '') ?? DateTime.now();
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _statusColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt, color: _statusColor, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(order['order_number'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            Text(order['channel'] ?? '', style: TextStyle(color: _statusColor, fontSize: 12)),
            Text(DateFormat('HH:mm').format(createdAt), style: const TextStyle(fontSize: 12)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _statusColor),
                onPressed: () => SupabaseService.instance.updateOrderStatus(order['id'], _nextStatus),
                child: Text(_actionLabel, style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
