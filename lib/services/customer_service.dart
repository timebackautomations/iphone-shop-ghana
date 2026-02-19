import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class CustomerService {
  static final CustomerService _instance = CustomerService._internal();
  factory CustomerService() => _instance;
  CustomerService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  // Create customer
  Future<Map<String, dynamic>> createCustomer({
    required String name,
    required String phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    final response = await _client.from('customers').insert({
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'notes': notes,
      'total_purchases': 0,
      'purchase_count': 0,
      'loyalty_points': 0,
      'tier': 'Bronze',
      'created_at': DateTime.now().toIso8601String(),
    }).select().single();
    
    return response;
  }

  // Get all customers
  Future<List<Map<String, dynamic>>> getCustomers() async {
    final response = await _client
        .from('customers')
        .select('*')
        .order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }

  // Search customers
  Future<List<Map<String, dynamic>>> searchCustomers(String query) async {
    final response = await _client
        .from('customers')
        .select('*')
        .or('name.ilike.%$query%,phone.ilike.%$query%,email.ilike.%$query%')
        .order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }

  // Get customer by ID
  Future<Map<String, dynamic>?> getCustomerById(String id) async {
    final response = await _client
        .from('customers')
        .select('*')
        .eq('id', id)
        .single();
    
    return response;
  }

  // Update customer
  Future<void> updateCustomer({
    required String id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (phone != null) updates['phone'] = phone;
    if (email != null) updates['email'] = email;
    if (address != null) updates['address'] = address;
    if (notes != null) updates['notes'] = notes;
    updates['updated_at'] = DateTime.now().toIso8601String();
    
    await _client.from('customers').update(updates).eq('id', id);
  }

  // Add purchase to customer
  Future<void> addCustomerPurchase({
    required String customerId,
    required double amount,
    required String saleId,
  }) async {
    // Get customer
    final customer = await getCustomerById(customerId);
    if (customer == null) return;
    
    // Update totals
    final totalPurchases = (customer['total_purchases'] ?? 0) + amount;
    final purchaseCount = (customer['purchase_count'] ?? 0) + 1;
    final loyaltyPoints = (customer['loyalty_points'] ?? 0) + (amount / 10).floor();
    
    // Determine tier
    String tier = 'Bronze';
    if (totalPurchases >= 50000) {
      tier = 'Platinum';
    } else if (totalPurchases >= 20000) tier = 'Gold';
    else if (totalPurchases >= 5000) tier = 'Silver';
    
    // Update customer
    await _client.from('customers').update({
      'total_purchases': totalPurchases,
      'purchase_count': purchaseCount,
      'loyalty_points': loyaltyPoints,
      'tier': tier,
      'last_purchase': DateTime.now().toIso8601String(),
    }).eq('id', customerId);
    
    // Record purchase history
    await _client.from('customer_purchases').insert({
      'customer_id': customerId,
      'sale_id': saleId,
      'amount': amount,
      'points_earned': (amount / 10).floor(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // Get customer purchase history
  Future<List<Map<String, dynamic>>> getCustomerPurchases(String customerId) async {
    final response = await _client
        .from('customer_purchases')
        .select('*, sales(*)')
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }

  // Get customer statistics
  Map<String, dynamic> getCustomerStats(List<Map<String, dynamic>> customers) {
    final totalCustomers = customers.length;
    double totalRevenue = 0;
    final tierCounts = {'Bronze': 0, 'Silver': 0, 'Gold': 0, 'Platinum': 0};
    
    for (var customer in customers) {
      totalRevenue += (customer['total_purchases'] ?? 0).toDouble();
      final tier = customer['tier'] ?? 'Bronze';
      tierCounts[tier] = tierCounts[tier]! + 1;
    }
    
    final avgPurchase = totalCustomers > 0 ? totalRevenue / totalCustomers : 0;
    
    return {
      'totalCustomers': totalCustomers,
      'totalRevenue': totalRevenue,
      'avgPurchase': avgPurchase,
      'tierDistribution': tierCounts,
    };
  }

  // Send SMS to customer (requires Twilio or similar)
  Future<void> sendSMS(String phone, String message) async {
    // Integrate with SMS provider
    await _client.functions.invoke('send-sms', body: {
      'phone': phone,
      'message': message,
    });
  }

  // Send WhatsApp message
  Future<void> sendWhatsApp(String phone, String message) async {
    final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';
    // Open WhatsApp
  }

  // Calculate loyalty discount
  double calculateLoyaltyDiscount(int points, double amount) {
    // 100 points = 1% discount, max 20%
    final discountPercent = (points / 100).clamp(0, 20);
    return amount * (discountPercent / 100);
  }
}