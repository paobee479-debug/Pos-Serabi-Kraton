import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:image/image.dart' as img;
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final _tanggal = DateFormat('dd/MM/yyyy HH:mm');

/// Generate & cetak/bagikan struk sebagai PDF. Menggunakan package `printing`
/// yang cross-platform: di Android/tablet akan membuka dialog print/share,
/// di web desktop akan membuka print dialog browser atau download PDF.
/// Format ukuran struk 58mm/80mm cocok untuk thermal printer umum.
class ReceiptService {
  static Future<void> printReceipt({
    required String orderNumber,
    required String outletName,
    required String cashierName,
    required SalesChannel channel,
    required List<CartItem> items,
    required double subtotal,
    required double discount,
    required double tax,
    required double total,
    String? customerName,
    String paperWidth = '58mm', // '58mm' atau '80mm'
  }) async {
    final doc = _buildDoc(
      orderNumber: orderNumber, outletName: outletName, cashierName: cashierName,
      channel: channel, items: items, subtotal: subtotal, discount: discount,
      tax: tax, total: total, customerName: customerName, paperWidth: paperWidth,
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'Struk-$orderNumber.pdf',
    );
  }

  /// Render struk sebagai gambar JPG lalu bagikan lewat share sheet
  /// (WhatsApp, Galeri, dll). Lebih praktis dibanding PDF untuk dikirim
  /// ke pelanggan lewat chat. Aman untuk Android, tablet, maupun web
  /// (memakai XFile.fromData, tanpa akses filesystem langsung).
  static Future<void> shareReceiptAsJpg({
    required String orderNumber,
    required String outletName,
    required String cashierName,
    required SalesChannel channel,
    required List<CartItem> items,
    required double subtotal,
    required double discount,
    required double tax,
    required double total,
    String? customerName,
    String paperWidth = '58mm',
  }) async {
    final doc = _buildDoc(
      orderNumber: orderNumber, outletName: outletName, cashierName: cashierName,
      channel: channel, items: items, subtotal: subtotal, discount: discount,
      tax: tax, total: total, customerName: customerName, paperWidth: paperWidth,
    );

    // Rasterisasi halaman PDF pertama menjadi gambar PNG mentah,
    // dengan DPI tinggi supaya teks tetap tajam saat dijadikan JPG.
    final pageBytes = await doc.save();
    final pages = Printing.raster(pageBytes, dpi: 200);
    final firstPage = await pages.first;
    final pngBytes = await firstPage.toPng();

    // Konversi PNG -> JPG (kualitas 90) memakai package `image`.
    final decoded = img.decodePng(pngBytes);
    if (decoded == null) return;
    final jpgBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 90));

    await Share.shareXFiles(
      [XFile.fromData(jpgBytes, name: 'Struk-$orderNumber.jpg', mimeType: 'image/jpeg')],
      text: 'Struk pesanan $orderNumber - $outletName',
    );
  }

  static pw.Document _buildDoc({
    required String orderNumber,
    required String outletName,
    required String cashierName,
    required SalesChannel channel,
    required List<CartItem> items,
    required double subtotal,
    required double discount,
    required double tax,
    required double total,
    String? customerName,
    String paperWidth = '58mm',
  }) {
    final doc = pw.Document();
    final width = paperWidth == '80mm' ? 80.0 * PdfPageFormat.mm : 58.0 * PdfPageFormat.mm;
    final pageFormat = PdfPageFormat(width, double.infinity, marginAll: 8 * PdfPageFormat.mm);

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text(outletName,
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Center(child: pw.Text('Serabi Solo Kraton', style: const pw.TextStyle(fontSize: 9))),
              pw.SizedBox(height: 6),
              _divider(),
              pw.Text('No: $orderNumber', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Tanggal: ${_tanggal.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Kasir: $cashierName', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Channel: ${channel.label}', style: const pw.TextStyle(fontSize: 9)),
              if (customerName != null && customerName.isNotEmpty)
                pw.Text('Pelanggan: $customerName', style: const pw.TextStyle(fontSize: 9)),
              _divider(),
              ...items.map((item) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(item.product.name, style: const pw.TextStyle(fontSize: 9)),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('${item.qty} x ${_rupiah.format(item.product.price)}',
                                style: const pw.TextStyle(fontSize: 8)),
                            pw.Text(_rupiah.format(item.subtotal), style: const pw.TextStyle(fontSize: 9)),
                          ],
                        ),
                      ],
                    ),
                  )),
              _divider(),
              _summaryRow('Subtotal', subtotal),
              if (discount > 0) _summaryRow('Diskon', -discount),
              if (tax > 0) _summaryRow('Pajak', tax),
              _divider(),
              _summaryRow('TOTAL', total, bold: true),
              pw.SizedBox(height: 10),
              pw.Center(child: pw.Text('Terima kasih! 🙏', style: const pw.TextStyle(fontSize: 9))),
              pw.Center(child: pw.Text('Sampai jumpa lagi', style: const pw.TextStyle(fontSize: 8))),
            ],
          );
        },
      ),
    );
    return doc;
  }

  static pw.Widget _divider() => pw.Container(
        margin: const pw.EdgeInsets.symmetric(vertical: 4),
        height: 0.7,
        color: PdfColors.grey700,
      );

  static pw.Widget _summaryRow(String label, double value, {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: bold ? 11 : 9,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text(_rupiah.format(value), style: style),
      ],
    );
  }
}
