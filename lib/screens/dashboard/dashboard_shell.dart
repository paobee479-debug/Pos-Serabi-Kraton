import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_providers.dart';
import '../../models/models.dart';
import '../pos/pos_screen.dart';
import '../inventory/inventory_screen.dart';
import '../recipe/product_manage_screen.dart';
import '../reports/reports_screen.dart';
import '../orders/channel_orders_screen.dart';
import '../orders/kitchen_screen.dart';

/// Shell utama: NavigationRail untuk tablet/web (lebar > 700px),
/// BottomNavigationBar untuk HP Android.
class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.isOwner) {
        context.read<OutletProvider>().loadOutlets();
      }
    });
  }

  List<_NavItem> _itemsForRole(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return [
          _NavItem('Kasir', Icons.point_of_sale, const PosScreen()),
          _NavItem('Pesanan Channel', Icons.storefront, const ChannelOrdersScreen()),
          _NavItem('Dapur', Icons.soup_kitchen, const KitchenScreen()),
          _NavItem('Stok Bahan', Icons.inventory_2, const InventoryScreen()),
          _NavItem('Produk & HPP', Icons.receipt_long, const ProductManageScreen()),
          _NavItem('Laporan', Icons.bar_chart, const ReportsScreen()),
        ];
      case UserRole.kasir:
        return [
          _NavItem('Kasir', Icons.point_of_sale, const PosScreen()),
          _NavItem('Pesanan Channel', Icons.storefront, const ChannelOrdersScreen()),
        ];
      case UserRole.dapur:
        return [
          _NavItem('Dapur', Icons.soup_kitchen, const KitchenScreen()),
          _NavItem('Stok Bahan', Icons.inventory_2, const InventoryScreen()),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = auth.profile!.role;
    final items = _itemsForRole(role);
    final wide = MediaQuery.of(context).size.width > 700;
    if (index >= items.length) index = 0;

    final body = items[index].screen;

    return Scaffold(
      appBar: AppBar(
        title: Text(items[index].label),
        actions: [
          if (auth.isOwner) _OutletSwitcher(),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(child: Text(auth.profile!.fullName)),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: (i) => setState(() => index = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: items
                      .map((e) => NavigationRailDestination(
                            icon: Icon(e.icon),
                            label: Text(e.label),
                          ))
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => setState(() => index = i),
              destinations: items
                  .map((e) => NavigationDestination(icon: Icon(e.icon), label: e.label))
                  .toList(),
            ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final Widget screen;
  _NavItem(this.label, this.icon, this.screen);
}

/// Dropdown untuk owner memilih outlet aktif. Mengganti pilihan akan
/// memicu semua layar yang watch OutletProvider untuk reload data
/// (produk, stok, laporan) sesuai outlet yang dipilih, atau "Semua Outlet"
/// untuk data gabungan (khusus laporan).
class _OutletSwitcher extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final outletProvider = context.watch<OutletProvider>();
    if (outletProvider.outlets.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: outletProvider.selectedOutletId,
          dropdownColor: Theme.of(context).colorScheme.primary,
          icon: const Icon(Icons.storefront, color: Colors.white70),
          style: const TextStyle(color: Colors.white),
          hint: const Text('Semua Outlet', style: TextStyle(color: Colors.white)),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Semua Outlet')),
            ...outletProvider.outlets.map(
              (o) => DropdownMenuItem<String?>(value: o['id'] as String, child: Text(o['name'])),
            ),
          ],
          onChanged: (id) => outletProvider.selectOutlet(id),
        ),
      ),
    );
  }
}
