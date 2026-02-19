import 'package:flutter/material.dart';
import '../services/services.dart';

class ShopManagementScreen extends StatefulWidget {
  const ShopManagementScreen({super.key});

  @override
  State<ShopManagementScreen> createState() => _ShopManagementScreenState();
}

class _ShopManagementScreenState extends State<ShopManagementScreen> {
  final AuthService _auth = AuthService();
  List<Map<String, dynamic>> _workers = [];
  Map<String, dynamic>? _shopStats;
  Map<String, dynamic>? _shop;
  bool _isLoading = true;
  String _selectedTab = 'workers';
  String? _shopId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      print('🔄 Loading shop management data...');
      
      _shopId = await _auth.userShopId;
      print('🏪 Shop ID: $_shopId');
      
      final shop = await _auth.userShop;
      final workers = await _auth.getShopWorkers();
      final stats = await _auth.getShopStats();
      
      print('📊 Stats loaded: $stats');
      print('👥 Workers loaded: ${workers.length}');
      
      setState(() {
        _shop = shop;
        _workers = workers;
        _shopStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading shop data: $e');
      setState(() => _isLoading = false);
      _showErrorSnackBar('Error loading data: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _addWorker() async {
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    String selectedRole = 'worker';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Worker'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedRole,
              decoration: const InputDecoration(
                labelText: 'Role *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.admin_panel_settings),
              ),
              items: const [
                DropdownMenuItem(value: 'shop_manager', child: Text('Shop Manager')),
                DropdownMenuItem(value: 'worker', child: Text('Worker')),
              ],
              onChanged: (value) => selectedRole = value!,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || emailController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all required fields'),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('ADD'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      setState(() => _isLoading = true);
      
      try {
        print('🚀 Adding worker:');
        print('   Email: ${emailController.text}');
        print('   Name: ${nameController.text}');
        print('   Role: $selectedRole');
        print('   Shop ID: $_shopId');
        
        final success = await _auth.addWorkerToShop(
          email: emailController.text,
          fullName: nameController.text,
          role: selectedRole,
        );
        
        if (success && mounted) {
          await _loadData();
          _showSuccessSnackBar('✅ Worker added successfully');
        } else {
          throw Exception('Failed to add worker');
        }
      } catch (e) {
        print('❌ Error adding worker: $e');
        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorSnackBar('Error: $e');
        }
      }
    }
  }

  Future<void> _editWorker(Map<String, dynamic> worker) async {
    final nameController = TextEditingController(text: worker['full_name']);
    String selectedRole = worker['role_type'];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Worker'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedRole,
              decoration: const InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.admin_panel_settings),
              ),
              items: const [
                DropdownMenuItem(value: 'shop_manager', child: Text('Shop Manager')),
                DropdownMenuItem(value: 'worker', child: Text('Worker')),
              ],
              onChanged: (value) => selectedRole = value!,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      setState(() => _isLoading = true);
      
      try {
        final success = await _auth.updateWorkerRole(worker['id'], selectedRole);
        
        if (success && mounted) {
          await _loadData();
          _showSuccessSnackBar('✅ Worker updated');
        }
      } catch (e) {
        print('❌ Error updating worker: $e');
        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorSnackBar('Error: $e');
        }
      }
    }
  }

  Future<void> _removeWorker(String workerId, String workerName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Worker'),
        content: Text('Remove $workerName from shop?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final success = await _auth.removeWorker(workerId);
        
        if (success && mounted) {
          await _loadData();
          _showSuccessSnackBar('✅ Worker removed');
        }
      } catch (e) {
        print('❌ Error removing worker: $e');
        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorSnackBar('Error: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop Management'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Shop Header
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue.shade50,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.store, color: Colors.blue, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _shop?['name'] ?? 'Shop Name',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_shop?['address'] != null)
                              Text(
                                _shop!['address'],
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Stats Cards
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Inventory',
                          '${_shopStats?['totalInventory'] ?? 0}',
                          Icons.inventory,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Workers',
                          '${_workers.length}',
                          Icons.people,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Sales',
                          '${_shopStats?['todaySales'] ?? 0}',
                          Icons.today,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Tab Bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTab('Workers', 'workers'),
                      ),
                      Expanded(
                        child: _buildTab('Activity', 'activity'),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Content
                Expanded(
                  child: _selectedTab == 'workers'
                      ? _buildWorkersList()
                      : _buildActivityLog(),
                ),
              ],
            ),
      floatingActionButton: _selectedTab == 'workers'
          ? FloatingActionButton.extended(
              onPressed: _addWorker,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Worker'),
              backgroundColor: Colors.blue,
            )
          : null,
    );
  }

  Widget _buildTab(String label, String value) {
    final isSelected = _selectedTab == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
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
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkersList() {
    if (_workers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No workers yet',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Add workers to help manage your shop',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _workers.length,
      itemBuilder: (context, index) {
        final worker = _workers[index];
        final isManager = worker['role_type'] == 'shop_manager';
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isManager ? Colors.purple.shade100 : Colors.green.shade100,
              child: Text(
                worker['full_name']?[0].toUpperCase() ?? '?',
                style: TextStyle(
                  color: isManager ? Colors.purple : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(worker['full_name'] ?? ''),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(worker['email'] ?? ''),
                Text(
                  isManager ? 'Shop Manager' : 'Worker',
                  style: TextStyle(
                    fontSize: 11,
                    color: isManager ? Colors.purple : Colors.green,
                  ),
                ),
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit, color: Colors.blue),
                    title: Text('Edit Role'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('Remove', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  _editWorker(worker);
                } else if (value == 'remove') {
                  _removeWorker(worker['id'], worker['full_name']);
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivityLog() {
    return const Center(
      child: Text('Activity log coming soon...'),
    );
  }
}