import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/services.dart';
import '../services/export_service.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final AuthService _auth = AuthService();
  List<Map<String, dynamic>> sales = [];
  bool isLoading = true;
  String filter = 'all';
  String? _shopId;
  
  final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');
  final ghsFormat = NumberFormat.currency(locale: 'en_US', symbol: '₵');

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() => isLoading = true);
    
    try {
      _shopId = await _auth.userShopId;
      if (_shopId == null) {
        throw Exception('No shop selected');
      }
      
      final data = await SupabaseService.getSalesHistory(_shopId);
      if (mounted) {
        setState(() {
          sales = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading sales: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _exportSales() async {
    try {
      final exportService = ExportService();
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export Sales'),
          content: const Text('Choose export format:'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() => isLoading = true);
                
                try {
                  final file = await exportService.exportSalesToCSV(sales);
                  await exportService.shareFile(file);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Export successful!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Export failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } finally {
                  setState(() => isLoading = false);
                }
              },
              child: const Text('CSV'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() => isLoading = true);
                
                try {
                  final file = await exportService.exportSalesToExcel(sales);
                  await exportService.shareFile(file);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Export successful!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Export failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } finally {
                  setState(() => isLoading = false);
                }
              },
              child: const Text('EXCEL'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredSales {
    if (filter == 'all') return sales;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    return sales.where((sale) {
      final saleDate = DateTime.parse(sale['sold_at']);
      if (filter == 'today') {
        return saleDate.isAfter(today);
      } else if (filter == 'month') {
        return saleDate.month == now.month && saleDate.year == now.year;
      }
      return true;
    }).toList();
  }

  Map<String, dynamic> get _stats {
    double totalRevenue = 0;
    double totalProfit = 0;
    
    for (var sale in _filteredSales) {
      totalRevenue += (sale['price_ghs'] ?? 0).toDouble();
      totalProfit += (sale['profit'] ?? 0).toDouble();
    }
    
    return {
      'count': _filteredSales.length,
      'revenue': totalRevenue,
      'profit': totalProfit,
    };
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    
    if (date.isAfter(today)) {
      return 'Today ${DateFormat('HH:mm').format(date)}';
    } else if (date.isAfter(yesterday)) {
      return 'Yesterday ${DateFormat('HH:mm').format(date)}';
    } else {
      return DateFormat('MMM dd, HH:mm').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales History'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSales,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportSales,
            tooltip: 'Export Sales',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter Chips
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: filter == 'all',
                        onSelected: (_) => setState(() => filter = 'all'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Today'),
                        selected: filter == 'today',
                        onSelected: (_) => setState(() => filter = 'today'),
                        backgroundColor: Colors.blue.shade50,
                        selectedColor: Colors.blue.shade100,
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('This Month'),
                        selected: filter == 'month',
                        onSelected: (_) => setState(() => filter = 'month'),
                        backgroundColor: Colors.green.shade50,
                        selectedColor: Colors.green.shade100,
                      ),
                    ],
                  ),
                ),
                
                // Stats Cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Sales',
                          '${stats['count']}',
                          Icons.shopping_cart,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Revenue',
                          ghsFormat.format(stats['revenue']),
                          Icons.trending_up,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Profit',
                          ghsFormat.format(stats['profit']),
                          Icons.attach_money,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Sales List
                Expanded(
                  child: _filteredSales.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shopping_cart, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                'No sales found',
                                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadSales,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredSales.length,
                            itemBuilder: (context, index) {
                              final sale = _filteredSales[index];
                              final inventory = sale['inventory_items'] ?? {};
                              final product = inventory['products'] ?? {};
                              return _buildSaleCard(sale, inventory, product);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleCard(Map<String, dynamic> sale, Map<String, dynamic> inventory, Map<String, dynamic> product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check, color: Colors.green, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['model'] ?? 'Unknown Model',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'IMEI: ${inventory['imei'] ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      ghsFormat.format(sale['price_ghs']),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    Text(
                      _formatDate(sale['sold_at']),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.payment, size: 12, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      sale['payment_method'] ?? 'Cash',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                if (sale['customer_name'] != null)
                  Row(
                    children: [
                      Icon(Icons.person, size: 12, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        sale['customer_name'],
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Profit: ${currencyFormat.format(sale['profit'] ?? 0)}',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}