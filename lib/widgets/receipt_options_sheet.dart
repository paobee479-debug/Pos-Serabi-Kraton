import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/models.dart';
import '../services/receipt_service.dart';

/// Menampilkan bottom sheet setelah checkout berhasil, dengan 2 pilihan:
/// - Cetak PDF (untuk printer thermal)
/// - Bagikan JPG (untuk kirim cepat lewat WhatsApp/chat lain)
void showReceiptOptions({
  required BuildContext context,
  required String orderNumber,
  required String cashierName,
  required SalesChannel channel,
  required List<CartItem> items,
  required double subtotal,
  required double discount,
  required double tax,
  required double total,
  String? customerName,
  String outletName = 'Serabi Solo Kraton',
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Pesanan berhasil dibuat ($orderNumber)')),
  );

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Bagikan Struk', style: Theme.of(ctx).textTheme.titleMedium),
            Text('Pesanan $orderNumber', style: TextStyle(color: AppColors.kratonGreen.withOpacity(0.7))),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.image_outlined),
              label: const Text('Bagikan sebagai JPG (WhatsApp/Chat)'),
              onPressed: () {
                Navigator.pop(ctx);
                ReceiptService.shareReceiptAsJpg(
                  orderNumber: orderNumber,
                  outletName: outletName,
                  cashierName: cashierName,
                  channel: channel,
                  items: items,
                  subtotal: subtotal,
                  discount: discount,
                  tax: tax,
                  total: total,
                  customerName: customerName,
                );
              },
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.print_outlined),
              label: const Text('Cetak PDF (Printer Thermal)'),
              onPressed: () {
                Navigator.pop(ctx);
                ReceiptService.printReceipt(
                  orderNumber: orderNumber,
                  outletName: outletName,
                  cashierName: cashierName,
                  channel: channel,
                  items: items,
                  subtotal: subtotal,
                  discount: discount,
                  tax: tax,
                  total: total,
                  customerName: customerName,
                );
              },
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Lewati'),
            ),
          ],
        ),
      ),
    ),
  );
}
