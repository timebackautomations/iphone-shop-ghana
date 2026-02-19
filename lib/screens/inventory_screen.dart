import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/services.dart';
import '../services/export_service.dart';
import 'sell_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final AuthService _auth = AuthService();
  List<Map<String, dynamic>> inventory = [];
  bool isLoading = true;
  String searchQuery = '';
  String filterStatus = 'all';
  String? _shopId;
  
  final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    setState(() => isLoading = true);
    
    try {
      _shopId = await _auth.userShopId;
      if (_shopId == null) {
        throw Exception('No shop selected');
      }
      
      final data = await SupabaseService.getInventory(_shopId);
      if (mounted) {
        setState(() {
          inventory = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showSnackBar('Error loading inventory: $e', Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _exportInventory() async {
    try {
      final exportService = ExportService();
      
      // Show export options dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export Inventory'),
          content: const Text('Choose export format:'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() => isLoading = true);
                
                try {
                  final file = await exportService.exportInventoryToCSV(inventory);
                  await exportService.shareFile(file);
                  _showSnackBar('Export successful!', Colors.green);
                } catch (e) {
                  _showSnackBar('Export failed: $e', Colors.red);
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
                  final file = await exportService.exportInventoryToExcel(inventory);
                  await exportService.shareFile(file);
                  _showSnackBar('Export successful!', Colors.green);
                } catch (e) {
                  _showSnackBar('Export failed: $e', Colors.red);
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
      _showSnackBar('Export error: $e', Colors.red);
    }
  }

  List<Map<String, dynamic>> get _filteredInventory {
    List<Map<String, dynamic>> filtered = inventory;
    
    if (filterStatus != 'all') {
      filtered = filtered.where((item) => item['status'] == filterStatus).toList();
    }
    
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((item) {
        final imei = item['imei']?.toLowerCase() ?? '';
        final model = item['products']?['model']?.toLowerCase() ?? '';
        return imei.contains(searchQuery.toLowerCase()) ||
               model.contains(searchQuery.toLowerCase());
      }).toList();
    }
    
    return filtered;
  }

  Map<String, dynamic> get _stats {
    int total = inventory.length;
    int available = inventory.where((i) => i['status'] == 'available').length;
    int sold = inventory.where((i) => i['status'] == 'sold').length;
    double totalValue = 0;
    
    for (var item in inventory.where((i) => i['status'] == 'available')) {
      totalValue += (item['purchase_price'] ?? 0).toDouble();
    }
    
    return {
      'total': total,
      'available': available,
      'sold': sold,
      'totalValue': totalValue,
    };
  }

  void _showItemOptions(Map<String, dynamic> item, Map<String, dynamic> product) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            if (item['status'] == 'available')
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child: const Icon(Icons.sell, color: Colors.green),
                ),
                title: const Text('Sell this item'),
                subtitle: Text(product['model'] ?? 'Unknown Model'),
                onTap: () {
                  Navigator.pop(context);
                  _sellItem(item);
                },
              ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                child: const Icon(Icons.info, color: Colors.blue),
              ),
              title: const Text('View details'),
              subtitle: Text('IMEI: ${item['imei']}'),
              onTap: () {
                Navigator.pop(context);
                _showDetails(item, product);
              },
            ),
            if (item['status'] == 'available')
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red.shade100,
                  child: const Icon(Icons.delete, color: Colors.red),
                ),
                title: const Text('Delete item'),
                subtitle: const Text('Remove from inventory'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(item);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _sellItem(Map<String, dynamic> item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SellScreen(inventoryItem: item),
      ),
    );
    
    if (result == true && mounted) {
      _loadInventory();
      _showSnackBar('✅ Sale completed successfully!', Colors.green);
    }
  }

  void _showDetails(Map<String, dynamic> item, Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product['model'] ?? 'Product Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('IMEI', item['imei']),
            _buildDetailRow('Color', product['color'] ?? 'Unknown'),
            _buildDetailRow('Storage', product['storage'] ?? 'Unknown'),
            _buildDetailRow('Battery', '${item['battery_health']}%'),
            _buildDetailRow('Condition', item['condition']),
            _buildDetailRow('Purchase Price', currencyFormat.format(item['purchase_price'])),
            if (item['selling_price'] != null)
              _buildDetailRow('Sold Price', currencyFormat.format(item['selling_price'])),
            _buildDetailRow('Added', DateFormat('MMM dd, yyyy').format(DateTime.parse(item['created_at']))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete IMEI: ${item['imei']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm == true && mounted) {
      final success = await SupabaseService.deleteItem(item['imei'], _shopId);
      if (success && mounted) {
        _loadInventory();
        _showSnackBar('✅ Item deleted', Colors.green);
      }
    }
  }

  Color _getBatteryColor(double health) {
    if (health >= 85) return Colors.green;
    if (health >= 70) return Colors.lightGreen;
    if (health >= 50) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInventory,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportInventory,
            tooltip: 'Export Inventory',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by IMEI or Model...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),
          
          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: Text('All (${stats['total']})'),
                  selected: filterStatus == 'all',
                  onSelected: (_) => setState(() => filterStatus = 'all'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text('Available (${stats['available']})'),
                  selected: filterStatus == 'available',
                  onSelected: (_) => setState(() => filterStatus = 'available'),
                  backgroundColor: Colors.green.shade50,
                  selectedColor: Colors.green.shade100,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text('Sold (${stats['sold']})'),
                  selected: filterStatus == 'sold',
                  onSelected: (_) => setState(() => filterStatus = 'sold'),
                  backgroundColor: Colors.grey.shade50,
                  selectedColor: Colors.grey.shade200,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Stats Card
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Total', '${stats['total']}', Colors.blue),
                  _buildStatItem('Available', '${stats['available']}', Colors.green),
                  _buildStatItem('Sold', '${stats['sold']}', Colors.orange),
                  _buildStatItem('Value', '\$${stats['totalValue'].toStringAsFixed(0)}', Colors.purple),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Inventory List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredInventory.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              searchQuery.isNotEmpty 
                                  ? 'No matching items found'
                                  : 'No items in inventory',
                              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                            ),
                            if (searchQuery.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    searchQuery = '';
                                  });
                                },
                                child: const Text('Clear Search'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadInventory,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredInventory.length,
                          itemBuilder: (context, index) {
                            final item = _filteredInventory[index];
                            final product = item['products'] ?? {};
                            return _buildInventoryCard(item, product);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> item, Map<String, dynamic> product) {
    final status = item['status'] ?? 'available';
    final statusColor = status == 'available' ? Colors.green : Colors.grey;
    final battery = (item['battery_health'] ?? 0).toDouble();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showItemOptions(item, product),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: status != 'available'
              ? BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Status Indicator
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Battery Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getBatteryColor(battery).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.battery_full,
                    color: _getBatteryColor(battery),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['model'] ?? 'Unknown Model',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'IMEI: ${item['imei']}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getBatteryColor(battery).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${battery.round()}%',
                              style: TextStyle(
                                fontSize: 10,
                                color: _getBatteryColor(battery),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item['condition'] ?? 'Good',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Price and Status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currencyFormat.format(item['purchase_price'] ?? 0),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}