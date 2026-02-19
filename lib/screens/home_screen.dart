import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/services.dart';
import '../services/report_service.dart';
import '../widgets/dashboard_charts.dart';
import 'scanner_screen.dart';
import 'inventory_screen.dart';
import 'sales_history_screen.dart';
import 'manual_add_screen.dart';
import 'profile_screen.dart';
import 'shop_selector_screen.dart';
import 'shop_management_screen.dart';
import 'super_admin_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _auth = AuthService();
  final ReportService _reportService = ReportService();
  
  double exchangeRate = 12.50;
  int totalItems = 0;
  int availableItems = 0;
  int soldItems = 0;
  bool isLoading = true;
  
  String? _userRole;
  bool _isSuperAdmin = false;
  bool _isShopOwner = false;
  bool _isShopManager = false;
  String? _shopName;
  String? _shopId;
  
  // WOW Features Data
  List<Map<String, dynamic>> _topProducts = [];
  Map<String, int> _paymentData = {};
  Map<String, dynamic> _salesData = {};
  List<Map<String, dynamic>> _recentSales = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
  setState(() => isLoading = true);
  
  try {
    // Load user role
    _userRole = await _auth.userRoleType;
    _isSuperAdmin = await _auth.isSuperAdmin;
    _isShopOwner = await _auth.isShopOwner;
    _isShopManager = await _auth.isShopManager;
    
    // ===== DEBUG LOGS =====
    print('=' * 50);
    print('🔍 HOME SCREEN DEBUG');
    print('=' * 50);
    print('User Role: $_userRole');
    print('isSuperAdmin: $_isSuperAdmin');
    print('isShopOwner: $_isShopOwner');
    print('User Email: ${_auth.userEmail}');
    print('=' * 50);
    // ======================
    
    // Get shop info
    final shop = await _auth.userShop;
    _shopName = shop?['name'];
    _shopId = shop?['id'];
    
    // Load basic stats
    final rate = await SupabaseService.getExchangeRate();
    final stats = await SupabaseService.getInventoryStats(_shopId);
    
    // Load WOW Features data (for Super Admin and Shop Owners)
    if (_isSuperAdmin || _isShopOwner) {
      await _loadWowFeatures();
    } else {
      print('⚠️ User is not Super Admin or Shop Owner - WOW features hidden');
    }
    
    if (mounted) {
      setState(() {
        exchangeRate = rate;
        totalItems = stats['total'] ?? 0;
        availableItems = stats['available'] ?? 0;
        soldItems = stats['sold'] ?? 0;
        isLoading = false;
      });
    }
  } catch (e) {
    print('❌ Error loading data: $e');
    if (mounted) setState(() => isLoading = false);
  }
}

Future<void> _loadWowFeatures() async {
  try {
    print('📊 Loading WOW features data...');
    
    List<Map<String, dynamic>> sales = [];
    
    if (_isSuperAdmin) {
      // Super Admin: Get sales from ALL shops
      print('👑 Super Admin: Loading sales from all shops...');
      
      // Get all shops first
      final shops = await _auth.getAllShops();
      print('📊 Found ${shops.length} shops');
      
      // Get sales from each shop and combine
      for (var shop in shops) {
        final shopSales = await SupabaseService.getSalesHistory(shop['id']);
        sales.addAll(shopSales);
        print('📊 Shop ${shop['name']}: ${shopSales.length} sales');
      }
    } else {
      // Shop Owner/Manager: Get sales from their shop only
      sales = await SupabaseService.getSalesHistory(_shopId);
    }
    
    print('📊 Total sales data count: ${sales.length}');
    
    // Get top products
    _topProducts = _reportService.getTopModels(sales, 5);
    print('📊 Top products count: ${_topProducts.length}');
    
    // Get payment distribution
    final paymentDist = _reportService.getPaymentDistribution(sales);
    print('📊 Payment distribution: $paymentDist');
    
    _paymentData = {};
    for (var item in paymentDist) {
      _paymentData[item['method']] = (item['count'] as num).toInt();
    }
    
    // Get sales by period
    _salesData = _reportService.getSalesByPeriod(sales, 'week');
    print('📊 Sales data keys: ${_salesData.keys}');
    print('📊 Sales labels: ${_salesData['labels']}');
    print('📊 Sales values: ${_salesData['sales']}');
    
    // Get recent sales
    _recentSales = sales.take(5).toList();
    print('📊 Recent sales count: ${_recentSales.length}');
    
    print('✅ WOW features data loaded');
  } catch (e) {
    print('❌ Error loading WOW features: $e');
  }
}
  
  Future<void> _scan() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );
    
    if (result != null && mounted) {
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('IMEI: $result'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openManualAdd() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ManualAddScreen()),
    );
    
    if (result == true && mounted) {
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Product added successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openShopManagement() async {
    if (_isSuperAdmin) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SuperAdminScreen()),
      );
    } else if (_isShopOwner) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ShopManagementScreen()),
      );
    } else {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ShopSelectorScreen()),
      );
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning ☀️';
    if (hour < 17) return 'Good Afternoon 🌤️';
    return 'Good Evening 🌙';
  }

  Color _getRoleColor() {
    if (_isSuperAdmin) return Colors.purple;
    if (_isShopOwner) return Colors.orange;
    if (_isShopManager) return Colors.teal;
    return Colors.green;
  }

  String _getRoleText() {
    if (_isSuperAdmin) return 'SUPER ADMIN';
    if (_isShopOwner) return 'SHOP OWNER';
    if (_isShopManager) return 'SHOP MANAGER';
    return 'WORKER';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('iPhone Shop Manager'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              ).then((_) => _loadData());
            },
            tooltip: 'Profile',
          ),
          if (_isSuperAdmin || _isShopOwner)
            IconButton(
              icon: const Icon(Icons.store),
              onPressed: _openShopManagement,
              tooltip: 'Shop Management',
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Welcome Card with User Info
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade400, Colors.blue.shade700],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getGreeting(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _auth.userEmail?.split('@').first ?? 'User',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (_shopName != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        _shopName!,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getRoleColor().withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _getRoleText(),
                                    style: TextStyle(
                                      color: _getRoleColor(),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(color: Colors.white30),
                            const SizedBox(height: 8),
                            Text(
                              '1 USD = ${exchangeRate.toStringAsFixed(2)} GHS',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Stats Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total',
                            '$totalItems',
                            Icons.inventory,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Available',
                            '$availableItems',
                            Icons.check_circle,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Sold',
                            '$soldItems',
                            Icons.sell,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Quick Actions Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Text(
                              'QUICK ACTIONS',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildActionButton(
                                    icon: Icons.qr_code_scanner,
                                    label: 'Scan IMEI',
                                    color: Colors.blue,
                                    onTap: _scan,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildActionButton(
                                    icon: Icons.inventory,
                                    label: 'Inventory',
                                    color: Colors.green,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const InventoryScreen()),
                                      ).then((_) => _loadData());
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildActionButton(
                                    icon: Icons.history,
                                    label: 'Sales History',
                                    color: Colors.orange,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const SalesHistoryScreen()),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildActionButton(
                                    icon: Icons.add,
                                    label: 'Add Manual',
                                    color: Colors.purple,
                                    onTap: _openManualAdd,
                                  ),
                                ),
                              ],
                            ),
                            
                            // Admin/Super Admin Section
                            if (_isSuperAdmin || _isShopOwner) ...[
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildActionButton(
                                      icon: Icons.people,
                                      label: 'User Management',
                                      color: Colors.purple,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const ProfileScreen()),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildActionButton(
                                      icon: Icons.settings,
                                      label: 'Settings',
                                      color: Colors.grey,
                                      onTap: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Settings coming soon!'),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    
                    // ========== WOW FEATURES SECTION ==========
                    if (_isSuperAdmin || _isShopOwner) ...[
                      const SizedBox(height: 20),
                      
                      // WOW Features Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getRoleColor().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _getRoleColor().withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome, size: 16, color: _getRoleColor()),
                            const SizedBox(width: 6),
                            Text(
                              'ANALYTICS DASHBOARD',
                              style: TextStyle(
                                fontSize: 12,
                                color: _getRoleColor(),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Sales Chart
                      if (_salesData.isNotEmpty) ...[
                        SalesChart(
                          salesData: _salesData,
                          title: 'Weekly Sales (GHS)',
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Top Products Chart
                      if (_topProducts.isNotEmpty) ...[
                        TopProductsChart(topProducts: _topProducts),
                        const SizedBox(height: 16),
                      ],
                      
                      // Payment Methods Chart
                      if (_paymentData.isNotEmpty) ...[
                        PaymentPieChart(paymentData: _paymentData),
                        const SizedBox(height: 16),
                      ],
                      
                      // Recent Sales List
                      if (_recentSales.isNotEmpty) ...[
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Recent Sales',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const SalesHistoryScreen()),
                                        );
                                      },
                                      child: const Text('View All'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ..._recentSales.take(3).map((sale) {
                                  final inventory = sale['inventory_items'] ?? {};
                                  final product = inventory['products'] ?? {};
                                  final date = DateTime.parse(sale['sold_at']);
                                  
                                  return ListTile(
                                    dense: true,
                                    leading: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.green.shade100,
                                      child: const Icon(Icons.check, color: Colors.green, size: 12),
                                    ),
                                    title: Text(
                                      product['model'] ?? 'iPhone',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    subtitle: Text(
                                      DateFormat('MMM dd, HH:mm').format(date),
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    trailing: Text(
                                      '₵${sale['price_ghs']?.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}