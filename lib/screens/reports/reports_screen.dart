import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../services/supabase_service.dart';
import '../../services/export_service.dart';

final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<Map<String, dynamic>> daily = [];
  List<Map<String, dynamic>> byProduct = [];
  bool loading = true;
  String? _lastOutletId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final outletId = context.read<OutletProvider>().selectedOutletId;
    _lastOutletId = outletId;
    daily = await SupabaseService.instance.fetchDailySalesReport(outletId: outletId);
    byProduct = await SupabaseService.instance.fetchProductSalesReport(outletId: outletId);
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final selectedOutletId = context.watch<OutletProvider>().selectedOutletId;
    if (selectedOutletId != _lastOutletId && !loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    if (loading) return const Center(child: CircularProgressIndicator());

    final totalRevenue = daily.fold<double>(0, (s, r) => s + (r['total_revenue'] as num).toDouble());
    final totalProfit = daily.fold<double>(0, (s, r) => s + (r['gross_profit'] as num).toDouble());
    final channelTotals = <String, double>{};
    for (final r in daily) {
      final ch = r['channel'] as String;
      channelTotals[ch] = (channelTotals[ch] ?? 0) + (r['total_revenue'] as num).toDouble();
    }

    return Scaffold(
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'export_excel',
            onPressed: () => ExportService.exportToExcel(dailyReport: daily, productReport: byProduct),
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('Excel'),
          ),
          const SizedBox(width: 10),
          FloatingActionButton.extended(
            heroTag: 'export_pdf',
            onPressed: () => ExportService.exportToPdf(dailyReport: daily, productReport: byProduct),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('PDF'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(child: _statCard('Total Penjualan', _rupiah.format(totalRevenue), AppColors.kratonGreen)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('Laba Kotor', _rupiah.format(totalProfit), AppColors.pradaGold)),
              ],
            ),
            const SizedBox(height: 20),
            Text('Penjualan per Channel', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  barGroups: channelTotals.entries.toList().asMap().entries.map((e) {
                    return BarChartGroupData(x: e.key, barRods: [
                      BarChartRodData(toY: e.value.value, color: AppColors.kratonGreen, width: 18,
                          borderRadius: BorderRadius.circular(4)),
                    ]);
                  }).toList(),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, meta) {
                          final keys = channelTotals.keys.toList();
                          if (v.toInt() >= keys.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(keys[v.toInt()], style: const TextStyle(fontSize: 10)),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Produk Terlaris', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...byProduct.take(10).map((p) => Card(
                  child: ListTile(
                    title: Text(p['product_name']),
                    subtitle: Text('Terjual: ${p['total_qty']} pcs'),
                    trailing: Text(_rupiah.format(p['total_revenue']),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.kratonGreen)),
                  ),
                )),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color.withOpacity(0.8))),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
