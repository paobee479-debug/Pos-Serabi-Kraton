import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final _tanggalFile = DateFormat('yyyyMMdd_HHmm');
final _tanggalTampil = DateFormat('dd/MM/yyyy');

/// Export laporan penjualan (harian per channel & per produk) ke Excel
/// atau PDF, lalu langsung dibagikan lewat share sheet (email, WhatsApp,
/// Google Drive, dll) — bekerja di Android, tablet, maupun web.
class ExportService {
  static Future<void> exportToExcel({
    required List<Map<String, dynamic>> dailyReport,
    required List<Map<String, dynamic>> productReport,
  }) async {
    final excel = Excel.createExcel();

    // Sheet 1: Penjualan per Channel
    final sheet1 = excel['Penjualan per Channel'];
    excel.delete('Sheet1');
    sheet1.appendRow([
      TextCellValue('Tanggal'), TextCellValue('Channel'), TextCellValue('Jumlah Order'),
      TextCellValue('Total Penjualan'), TextCellValue('Total HPP'), TextCellValue('Laba Kotor'),
    ]);
    for (final row in dailyReport) {
      final date = DateTime.tryParse(row['sale_date'] ?? '');
      sheet1.appendRow([
        TextCellValue(date != null ? _tanggalTampil.format(date) : '-'),
        TextCellValue(row['channel'] ?? '-'),
        IntCellValue((row['total_orders'] as num?)?.toInt() ?? 0),
        DoubleCellValue((row['total_revenue'] as num?)?.toDouble() ?? 0),
        DoubleCellValue((row['total_hpp'] as num?)?.toDouble() ?? 0),
        DoubleCellValue((row['gross_profit'] as num?)?.toDouble() ?? 0),
      ]);
    }

    // Sheet 2: Produk Terlaris
    final sheet2 = excel['Produk Terlaris'];
    sheet2.appendRow([
      TextCellValue('Nama Produk'), TextCellValue('Kali Terjual'),
      TextCellValue('Total Qty'), TextCellValue('Total Pendapatan'), TextCellValue('Total HPP'),
    ]);
    for (final row in productReport) {
      sheet2.appendRow([
        TextCellValue(row['product_name'] ?? '-'),
        IntCellValue((row['times_sold'] as num?)?.toInt() ?? 0),
        IntCellValue((row['total_qty'] as num?)?.toInt() ?? 0),
        DoubleCellValue((row['total_revenue'] as num?)?.toDouble() ?? 0),
        DoubleCellValue((row['total_hpp'] as num?)?.toDouble() ?? 0),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) return;

    final fileName = 'Laporan-Serabi-${_tanggalFile.format(DateTime.now())}.xlsx';
    await Share.shareXFiles(
      [
        XFile.fromData(
          Uint8List.fromList(bytes),
          name: fileName,
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      ],
      text: 'Laporan penjualan Serabi Solo Kraton',
    );
  }

  static Future<void> exportToPdf({
    required List<Map<String, dynamic>> dailyReport,
    required List<Map<String, dynamic>> productReport,
  }) async {
    final doc = pw.Document();
    final totalRevenue = dailyReport.fold<double>(0, (s, r) => s + ((r['total_revenue'] as num?)?.toDouble() ?? 0));
    final totalProfit = dailyReport.fold<double>(0, (s, r) => s + ((r['gross_profit'] as num?)?.toDouble() ?? 0));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text('Laporan Penjualan - Serabi Solo Kraton',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Text('Dicetak: ${_tanggalTampil.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              pw.Expanded(child: _summaryBox('Total Penjualan', _rupiah.format(totalRevenue))),
              pw.SizedBox(width: 10),
              pw.Expanded(child: _summaryBox('Laba Kotor', _rupiah.format(totalProfit))),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text('Penjualan per Channel', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table.fromTextArray(
            headers: ['Tanggal', 'Channel', 'Order', 'Penjualan', 'HPP', 'Laba'],
            data: dailyReport.map((r) {
              final date = DateTime.tryParse(r['sale_date'] ?? '');
              return [
                date != null ? _tanggalTampil.format(date) : '-',
                r['channel'] ?? '-',
                '${r['total_orders'] ?? 0}',
                _rupiah.format((r['total_revenue'] as num?)?.toDouble() ?? 0),
                _rupiah.format((r['total_hpp'] as num?)?.toDouble() ?? 0),
                _rupiah.format((r['gross_profit'] as num?)?.toDouble() ?? 0),
              ];
            }).toList(),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 20),
          pw.Text('Produk Terlaris', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table.fromTextArray(
            headers: ['Produk', 'Kali Terjual', 'Qty', 'Pendapatan', 'HPP'],
            data: productReport.map((r) {
              return [
                r['product_name'] ?? '-',
                '${r['times_sold'] ?? 0}',
                '${r['total_qty'] ?? 0}',
                _rupiah.format((r['total_revenue'] as num?)?.toDouble() ?? 0),
                _rupiah.format((r['total_hpp'] as num?)?.toDouble() ?? 0),
              ];
            }).toList(),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    final fileName = 'Laporan-Serabi-${_tanggalFile.format(DateTime.now())}.pdf';
    await Share.shareXFiles(
      [XFile.fromData(bytes, name: fileName, mimeType: 'application/pdf')],
      text: 'Laporan penjualan Serabi Solo Kraton',
    );
  }

  static pw.Widget _summaryBox(String label, String value) => pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(6)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );
}
