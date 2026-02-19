import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  final AuthService _auth = AuthService();
  List<Map<String, dynamic>> _shops = [];
  bool _isLoading = true;
  String? _selectedShopId;

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  Future<void> _loadShops() async {
    setState(() => _isLoading = true);
    
    try {
      print('🔄 Loading shops for super admin...');
      final shops = await _auth.getAllShops();
      print('✅ Loaded ${shops.length} shops');
      setState(() {
        _shops = shops;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading shops: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createShop() async {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final ownerController = TextEditingController();
  final addressController = TextEditingController();
  final phoneController = TextEditingController();

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Create New Shop'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Shop Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.store),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Owner Email *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ownerController,
              decoration: const InputDecoration(
                labelText: 'Owner Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: 'Shop Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (nameController.text.isEmpty || 
                emailController.text.isEmpty || 
                ownerController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please fill all required fields'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            Navigator.pop(context, true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
          ),
          child: const Text('CREATE'),
        ),
      ],
    ),
  );
  
  if (result == true) {
    setState(() => _isLoading = true);
    
    try {
      print('🚀 Attempting to create shop...');
      print('Name: ${nameController.text}');
      print('Email: ${emailController.text}');
      print('Owner: ${ownerController.text}');
      
      final success = await _auth.createShop(
        name: nameController.text,
        ownerEmail: emailController.text,
        ownerName: ownerController.text,
        address: addressController.text.isNotEmpty ? addressController.text : null,
        phone: phoneController.text.isNotEmpty ? phoneController.text : null,
      );
      
      if (success && mounted) {
        await _loadShops();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Shop created successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        throw Exception('Shop creation failed');
      }
    } catch (e) {
      print('❌ Error in shop creation: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
  Future<void> _viewShopDetails(Map<String, dynamic> shop) async {
    setState(() => _selectedShopId = shop['id']);
    
    try {
      final details = await _auth.getShopDetails(shop['id']);
      
      if (!mounted) return;
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.store, color: Colors.purple, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shop['name'],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Owner: ${shop['profiles']?['full_name'] ?? 'Unknown'}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              
              // Stats Row
              Row(
                children: [
                  Expanded(
                    child: _buildDetailStat(
                      'Inventory',
                      '${details['stats']?['totalInventory'] ?? 0}',
                      Icons.inventory,
                    ),
                  ),
                  Expanded(
                    child: _buildDetailStat(
                      'Workers',
                      '${details['workers']?.length ?? 0}',
                      Icons.people,
                    ),
                  ),
                  Expanded(
                    child: _buildDetailStat(
                      'Sales',
                      '${details['stats']?['totalSales'] ?? 0}',
                      Icons.sell,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Workers List
              const Text(
                'Workers',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: details['workers'] == null || details['workers'].isEmpty
                    ? Center(
                        child: Text(
                          'No workers yet',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        itemCount: details['workers'].length,
                        itemBuilder: (context, index) {
                          final worker = details['workers'][index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: worker['role_type'] == 'shop_manager'
                                  ? Colors.orange.shade100
                                  : Colors.green.shade100,
                              child: Text(
                                worker['full_name']?[0].toUpperCase() ?? '?',
                                style: TextStyle(
                                  color: worker['role_type'] == 'shop_manager'
                                      ? Colors.orange
                                      : Colors.green,
                                ),
                              ),
                            ),
                            title: Text(worker['full_name'] ?? ''),
                            subtitle: Text(worker['email'] ?? ''),
                            trailing: Chip(
                              label: Text(worker['role_type'] ?? 'worker'),
                              backgroundColor: worker['role_type'] == 'shop_manager'
                                  ? Colors.orange.shade50
                                  : Colors.green.shade50,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      print('Error loading shop details: $e');
    } finally {
      setState(() => _selectedShopId = null);
    }
  }

  Widget _buildDetailStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.purple, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Future<void> _deleteShop(String shopId, String shopName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Shop'),
        content: Text('Are you sure you want to delete "$shopName"?\n\nThis will remove all workers and data associated with this shop.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      setState(() => _isLoading = true);
      final success = await _auth.deleteShop(shopId);
      if (success && mounted) {
        await _loadShops();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Shop deleted'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin Dashboard'),
        centerTitle: true,
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadShops,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _shops.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.store, size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No shops created yet',
                        style: TextStyle(fontSize: 20, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Click the + button to create your first shop',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _shops.length,
                  itemBuilder: (context, index) {
                    final shop = _shops[index];
                    final owner = shop['profiles'] ?? {};
                    final isSelected = _selectedShopId == shop['id'];
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => _viewShopDetails(shop),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: isSelected
                                ? Border.all(color: Colors.purple, width: 2)
                                : null,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.store, color: Colors.purple),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          shop['name'],
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Owner: ${owner['full_name'] ?? 'Unknown'}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        if (shop['address'] != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            shop['address'],
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton(
                                    icon: const Icon(Icons.more_vert),
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: ListTile(
                                          leading: Icon(Icons.edit, color: Colors.blue),
                                          title: Text('Edit Shop'),
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: ListTile(
                                          leading: Icon(Icons.delete, color: Colors.red),
                                          title: Text('Delete Shop'),
                                        ),
                                      ),
                                    ],
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        // Edit shop
                                      } else if (value == 'delete') {
                                        _deleteShop(shop['id'], shop['name']);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createShop,
        icon: const Icon(Icons.add_business),
        label: const Text('New Shop'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
    );
  }
}