import 'package:digital_twin_shop/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  // !!! REPLACE WITH YOUR ACTUAL SUPABASE CREDENTIALS !!!
  static const String _supabaseUrl = 'https://lrvhugkrkuttucowhccx.supabase.co';
  static const String _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxydmh1Z2tya3V0dHVjb3doY2N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE0MDc5MjgsImV4cCI6MjA4Njk4MzkyOH0.Fr2Ww0NNdNzgRqCTF__5zJEcEwFnARenRUB0XIhwxGU';
  
  static bool _isInitialized = false;
  static SupabaseClient? _client;
  
  static bool get isInitialized => _isInitialized;
  
  static Future<void> initialize() async {
    print('🔄 Initializing Supabase...');
    print('URL: $_supabaseUrl');
    
    if (_isInitialized) {
      print('✅ Supabase already initialized');
      return;
    }
    
    try {
      await Supabase.initialize(
        url: _supabaseUrl,
        anonKey: _supabaseAnonKey,
      );
      
      _client = Supabase.instance.client;
      _isInitialized = true;
      print('✅ Supabase initialized successfully');
      
      // Test connection
      try {
        await _client!.from('global_settings').select('count').limit(1);
        print('✅ Database connection test passed');
      } catch (e) {
        print('⚠️ Database connection test failed: $e');
      }
      
    } catch (e) {
      print('❌ Supabase initialization failed: $e');
      rethrow;
    }
  }
  
  static SupabaseClient get client {
    if (!_isInitialized || _client == null) {
      throw Exception('Supabase not initialized. Call initialize() first.');
    }
    return _client!;
  }
  
  // ----- EXCHANGE RATE -----
  static Future<double> getExchangeRate() async {
    try {
      final response = await client
          .from('global_settings')
          .select('usd_to_ghs_rate')
          .eq('id', 1)
          .maybeSingle();
      return (response?['usd_to_ghs_rate'] ?? 12.50).toDouble();
    } catch (e) {
      print('Error getting exchange rate: $e');
      return 12.50;
    }
  }
  
  // ----- INVENTORY METHODS -----
  static Future<bool> checkImeiExists(String imei, {String? shopId}) async {
    try {
      if (shopId == null) return false;
      
      final response = await client
          .from('inventory_items')
          .select('imei')
          .eq('imei', imei)
          .eq('shop_id', shopId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      print('Error checking IMEI: $e');
      return false;
    }
  }
  
  // Add to inventory with shop_id - FIXED for Super Admin
static Future<bool> addToInventory({
  required String imei,
  required String model,
  required String color,
  required String storage,
  required double batteryHealth,
  required String condition,
  required double purchasePrice,
  required String? shopId,
  required String? userId,
}) async {
  try {
    print('📤 Adding product to inventory:');
    print('IMEI: $imei');
    print('Model: $model');
    print('Color: $color');
    print('Storage: $storage');
    print('Battery: $batteryHealth');
    print('Condition: $condition');
    print('Price: $purchasePrice');
    print('Shop ID: $shopId');
    print('User ID: $userId');
    
    // Check if user is Super Admin (has no shop)
    final isSuperAdmin = await AuthService().isSuperAdmin;
    
    if (isSuperAdmin) {
      print('👑 Super Admin adding product - no shop assignment needed');
      
      // For Super Admin, we need to assign to a shop
      // Get the first available shop or let user choose
      final shops = await AuthService().getAllShops();
      if (shops.isEmpty) {
        print('❌ No shops available for Super Admin to add product');
        return false;
      }
      
      // Use the first shop for now
      final targetShopId = shops.first['id'];
      print('📦 Assigning product to shop: ${shops.first['name']} ($targetShopId)');
      
      // Insert product with shop_id
      final productResponse = await client
          .from('products')
          .insert({
            'model': model,
            'color': color,
            'storage': storage,
            'shop_id': targetShopId,
          })
          .select('id')
          .single();
      
      final productId = productResponse['id'];
      
      // Insert inventory item
      await client
          .from('inventory_items')
          .insert({
            'imei': imei,
            'product_id': productId,
            'battery_health': batteryHealth,
            'condition': condition,
            'purchase_price': purchasePrice,
            'status': 'available',
            'shop_id': targetShopId,
            'added_by': userId,
          });
      
      print('✅ Product added to shop: ${shops.first['name']}');
      return true;
    }
    
    // For regular users (shop owners/managers)
    if (shopId == null || userId == null) {
      print('❌ Shop ID or User ID is null for non-admin user');
      return false;
    }
    
    // Check if IMEI exists in this shop
    if (await checkImeiExists(imei, shopId: shopId)) {
      print('❌ IMEI already exists in this shop');
      return false;
    }
    
    // Insert product
    final productResponse = await client
        .from('products')
        .insert({
          'model': model,
          'color': color,
          'storage': storage,
          'shop_id': shopId,
        })
        .select('id')
        .single();
    
    final productId = productResponse['id'];
    
    // Insert inventory item
    await client
        .from('inventory_items')
        .insert({
          'imei': imei,
          'product_id': productId,
          'battery_health': batteryHealth,
          'condition': condition,
          'purchase_price': purchasePrice,
          'status': 'available',
          'shop_id': shopId,
          'added_by': userId,
        });
    
    print('✅ Product added to inventory');
    return true;
    
  } catch (e) {
    print('❌ Error adding to inventory: $e');
    if (e is PostgrestException) {
      print('❌ Error code: ${e.code}');
      print('❌ Error message: ${e.message}');
    }
    return false;
  }
}
  static Future<List<Map<String, dynamic>>> getInventory(String? shopId) async {
    try {
      if (shopId == null) return [];
      
      final response = await client
          .from('inventory_items')
          .select('''
            *,
            products(*),
            profiles!inventory_items_added_by_fkey(full_name, email)
          ''')
          .eq('shop_id', shopId)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting inventory: $e');
      return [];
    }
  }
  
  static Future<List<Map<String, dynamic>>> getAvailableInventory(String? shopId) async {
    try {
      if (shopId == null) return [];
      
      final response = await client
          .from('inventory_items')
          .select('''
            *,
            products(*)
          ''')
          .eq('shop_id', shopId)
          .eq('status', 'available')
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting available inventory: $e');
      return [];
    }
  }
  
  static Future<Map<String, dynamic>> getInventoryStats(String? shopId) async {
    try {
      if (shopId == null) {
        return {'total': 0, 'available': 0, 'sold': 0, 'totalValue': 0};
      }
      
      final response = await client
          .from('inventory_items')
          .select('status, purchase_price')
          .eq('shop_id', shopId);
      
      int total = response.length;
      int available = 0;
      int sold = 0;
      double totalValue = 0;
      
      for (var item in response) {
        if (item['status'] == 'available') {
          available++;
          totalValue += (item['purchase_price'] ?? 0).toDouble();
        } else if (item['status'] == 'sold') {
          sold++;
        }
      }
      
      return {
        'total': total,
        'available': available,
        'sold': sold,
        'totalValue': totalValue,
      };
    } catch (e) {
      return {'total': 0, 'available': 0, 'sold': 0, 'totalValue': 0};
    }
  }
  
  static Future<bool> deleteItem(String imei, String? shopId) async {
    try {
      if (shopId == null) return false;
      
      await client
          .from('inventory_items')
          .delete()
          .eq('imei', imei)
          .eq('shop_id', shopId);
      
      return true;
    } catch (e) {
      print('Error deleting item: $e');
      return false;
    }
  }
  
  // ----- SALES METHODS -----
  static Future<bool> completeSale({
    required String inventoryId,
    required double priceUsd,
    required double priceGhs,
    required String paymentMethod,
    String? customerName,
    String? customerPhone,
    required String? shopId,
    required String? userId,
  }) async {
    try {
      if (shopId == null || userId == null) return false;
      
      final item = await client
          .from('inventory_items')
          .select('purchase_price, status')
          .eq('id', inventoryId)
          .eq('shop_id', shopId)
          .single();
      
      if (item['status'] != 'available') return false;
      
      final profit = priceUsd - (item['purchase_price'] ?? 0).toDouble();
      
      await client
          .from('sales')
          .insert({
            'inventory_id': inventoryId,
            'shop_id': shopId,
            'sold_by': userId,
            'price_usd': priceUsd,
            'price_ghs': priceGhs,
            'payment_method': paymentMethod,
            'customer_name': customerName,
            'customer_phone': customerPhone,
            'profit': profit,
          });
      
      await client
          .from('inventory_items')
          .update({
            'status': 'sold',
            'selling_price': priceUsd,
            'sold_at': DateTime.now().toIso8601String(),
            'sold_by': userId,
          })
          .eq('id', inventoryId);
      
      return true;
    } catch (e) {
      print('Error completing sale: $e');
      return false;
    }
  }
  
  static Future<List<Map<String, dynamic>>> getSalesHistory(String? shopId) async {
    try {
      if (shopId == null) return [];
      
      final response = await client
          .from('sales')
          .select('''
            *,
            inventory_items!inner(
              id,
              imei,
              products(*)
            ),
            profiles!sales_sold_by_fkey(full_name, email)
          ''')
          .eq('shop_id', shopId)
          .order('sold_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting sales history: $e');
      return [];
    }
  }
  
  static Future<Map<String, dynamic>> getSalesStats(String? shopId) async {
    try {
      if (shopId == null) {
        return {
          'todayRevenue': 0, 'todayProfit': 0, 'todayCount': 0,
          'monthRevenue': 0, 'monthProfit': 0, 'monthCount': 0,
          'totalCount': 0,
        };
      }
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      
      final todaySales = await client
          .from('sales')
          .select('price_ghs, profit')
          .eq('shop_id', shopId)
          .gte('sold_at', today.toIso8601String())
          .lt('sold_at', tomorrow.toIso8601String());
      
      double todayRevenue = 0;
      double todayProfit = 0;
      for (var sale in todaySales) {
        todayRevenue += (sale['price_ghs'] ?? 0).toDouble();
        todayProfit += (sale['profit'] ?? 0).toDouble();
      }
      
      final monthSales = await client
          .from('sales')
          .select('price_ghs, profit')
          .eq('shop_id', shopId)
          .gte('sold_at', firstDayOfMonth.toIso8601String());
      
      double monthRevenue = 0;
      double monthProfit = 0;
      for (var sale in monthSales) {
        monthRevenue += (sale['price_ghs'] ?? 0).toDouble();
        monthProfit += (sale['profit'] ?? 0).toDouble();
      }
      
      final totalSales = await client
          .from('sales')
          .select('id')
          .eq('shop_id', shopId);
      
      return {
        'todayRevenue': todayRevenue,
        'todayProfit': todayProfit,
        'todayCount': todaySales.length,
        'monthRevenue': monthRevenue,
        'monthProfit': monthProfit,
        'monthCount': monthSales.length,
        'totalCount': totalSales.length,
      };
    } catch (e) {
      return {
        'todayRevenue': 0, 'todayProfit': 0, 'todayCount': 0,
        'monthRevenue': 0, 'monthProfit': 0, 'monthCount': 0,
        'totalCount': 0,
      };
    }
  }
}