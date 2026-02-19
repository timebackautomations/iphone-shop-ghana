import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() {
    return _instance;
  }
  AuthService._internal();

  late final SupabaseClient _client = Supabase.instance.client;
  
  // Current user
  User? get currentUser => _client.auth.currentUser;
  String? get userId => currentUser?.id;
  String? get userEmail => currentUser?.email;
  
  // User role from profiles table - cached values
  String? _cachedRole;
  String? _cachedRoleType;
  String? _cachedShopId;
  Map<String, dynamic>? _cachedShop;
  
  // Getters that use cached values or fetch from profile
  Future<String?> get userRole async {
    if (_cachedRole != null) return _cachedRole;
    final profile = await getUserProfile();
    _cachedRole = profile?['role'] ?? 'worker';
    return _cachedRole;
  }
  
  Future<String?> get userRoleType async {
    if (_cachedRoleType != null) {
      print('📢 Using cached role type: $_cachedRoleType');
      return _cachedRoleType;
    }
    final profile = await getUserProfile(forceRefresh:true);
    _cachedRoleType = profile?['role_type'] ?? 'worker';
    print('📢 Loaded role type from DB: $_cachedRoleType');
    return _cachedRoleType;
  }
  
  Future<String?> get userShopId async {
    if (_cachedShopId != null) return _cachedShopId;
    final profile = await getUserProfile();
    _cachedShopId = profile?['shop_id'];
    return _cachedShopId;
  }
  
  Future<Map<String, dynamic>?> get userShop async {
    if (_cachedShop != null) return _cachedShop;
    final shopId = await userShopId;
    if (shopId == null) return null;
    
    try {
      final response = await _client
          .from('shops')
          .select('*')
          .eq('id', shopId)
          .maybeSingle();
      _cachedShop = response;
      return response;
    } catch (e) {
      print('❌ Error getting shop: $e');
      return null;
    }
  }
  
  // Role check getters
  Future<bool> get isAdmin async {
    final role = await userRole;
    return role == 'admin';
  }
  
  Future<bool> get isSuperAdmin async {
    final type = await userRoleType;
    print('🔍 Checking isSuperAdmin: $type');
    return type == 'super_admin';
  }
  
  Future<bool> get isShopOwner async {
    final type = await userRoleType;
    print('🔍 Checking isShopOwner: $type');
    return type == 'shop_owner';
  }
  
  Future<bool> get isShopManager async {
    final type = await userRoleType;
    return type == 'shop_manager';
  }
  
  bool get isLoggedIn => currentUser != null;

  // Sign Up
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
        },
      );
      
      print('✅ Sign up successful: ${response.user?.email}');
      await Future.delayed(const Duration(seconds: 1));
      
      return response;
    } catch (e) {
      print('❌ Sign up error: $e');
      rethrow;
    }
  }

  // Sign In - FIXED to properly load role
  // Sign In - with detailed logging
Future<AuthResponse> signIn({
  required String email,
  required String password,
}) async {
  try {
    print('=' * 50);
    print('🔐 SIGN IN ATTEMPT');
    print('=' * 50);
    print('Email: $email');
    
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    
    if (response.user != null) {
      print('✅ Auth successful for user: ${response.user!.id}');
      print('👤 User email: ${response.user!.email}');
      print('👤 User metadata: ${response.user!.userMetadata}');
      
      // Clear cache first
      await _clearCache();
      
      // Small delay to ensure session is fully established
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Force load profile to cache role
      print('🔄 Loading user profile...');
      final profile = await getUserProfile(forceRefresh: true);
      
      if (profile != null) {
        print('✅ Profile loaded:');
        print('   - Name: ${profile['full_name']}');
        print('   - Role: ${profile['role']}');
        print('   - Role Type: ${profile['role_type']}');
        print('   - Shop ID: ${profile['shop_id']}');
      } else {
        print('❌ Profile is NULL!');
      }
      
      // Save session locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', email);
      await prefs.setString('user_id', response.user!.id);
      if (profile != null) {
        await prefs.setString('user_role', profile['role_type'] ?? 'worker');
      }
      
      print('=' * 50);
    }
    
    return response;
  } catch (e) {
    print('❌ Sign in error: $e');
    rethrow;
  }
}

  // Sign Out - FIXED with better error handling
  Future<void> signOut() async {
    try {
      print('🚪 AuthService: Signing out...');
      
      // Sign out from Supabase
      await _client.auth.signOut();
      
      // Clear local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      // Clear cache
      await _clearCache();
      
      print('✅ AuthService: Sign out successful');
    } catch (e) {
      print('❌ AuthService: Sign out error: $e');
      // Even if Supabase sign out fails, clear local data
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        await _clearCache();
      } catch (innerError) {
        print('❌ AuthService: Error clearing local data: $innerError');
      }
      rethrow;
    }
  }

  // Clear cache
  Future<void> _clearCache() async {
    _cachedRole = null;
    _cachedRoleType = null;
    _cachedShopId = null;
    _cachedShop = null;
  }

  // Check existing session
  Future<bool> checkExistingSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSession = prefs.containsKey('user_id');
      
      if (hasSession && _client.auth.currentUser != null) {
        // Reload profile to ensure correct role
        await getUserProfile(forceRefresh: true);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Force refresh user role
  Future<void> refreshUserRole() async {
    print('🔄 Refreshing user role cache...');
    await _clearCache();
    await getUserProfile(forceRefresh: true);
  }

  // Get user profile with shop info - FIXED with force refresh option
 // Get user profile with shop info - with detailed logging
// Get user profile with shop info - with better error handling
Future<Map<String, dynamic>?> getUserProfile({bool forceRefresh = false}) async {
  if (userId == null) {
    print('❌ No user ID found');
    return null;
  }
  
  // If not forcing refresh and we have cached data, return it
  if (!forceRefresh && _cachedRoleType != null) {
    print('📢 Returning cached profile');
    final Map<String, dynamic> profile = {
      'id': userId,
      'email': userEmail,
      'role': _cachedRole,
      'role_type': _cachedRoleType,
      'shop_id': _cachedShopId,
    };
    if (_cachedShop != null) {
      profile['shops'] = _cachedShop;
    }
    return profile;
  }
  
  try {
    print('🔍 Getting fresh profile for user: $userId');
    
    final profile = await _client
        .from('profiles')
        .select('*')
        .eq('id', userId!)
        .maybeSingle();
    
    if (profile == null) {
      print('⚠️ Profile not found in database!');
      print('   User ID: $userId');
      print('   Email: $userEmail');
      
      // Try to create profile
      print('🔄 Attempting to create profile...');
      try {
        await _client.from('profiles').insert({
          'id': userId!,
          'email': userEmail,
          'full_name': currentUser?.userMetadata?['full_name'] ?? 
                      userEmail?.split('@').first ?? 'User',
          'role': 'worker',
          'role_type': 'worker',
          'is_active': true,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        
        print('✅ Profile created, fetching again...');
        return await getUserProfile(forceRefresh: true);
      } catch (insertError) {
        print('❌ Failed to create profile: $insertError');
        return null;
      }
    }
    
    // Cache the values
    _cachedRole = profile['role'];
    _cachedRoleType = profile['role_type'];
    _cachedShopId = profile['shop_id'];
    
    print('✅ Profile loaded from database:');
    print('   - Name: ${profile['full_name']}');
    print('   - Role: ${profile['role']}');
    print('   - Role Type: ${profile['role_type']}');
    print('   - Shop ID: ${profile['shop_id']}');
    
    // Get shop details if available
    if (profile['shop_id'] != null) {
      try {
        final shop = await _client
            .from('shops')
            .select('*')
            .eq('id', profile['shop_id'])
            .maybeSingle();
        profile['shops'] = shop;
        _cachedShop = shop;
        print('   - Shop Name: ${shop?['name']}');
      } catch (e) {
        print('⚠️ Could not fetch shop details: $e');
        profile['shops'] = null;
      }
    }
    
    return profile;
    
  } catch (e) {
    print('❌ Error getting user profile: $e');
    
    // If it's an RLS error, try a simpler query
    if (e.toString().contains('infinite recursion')) {
      print('⚠️ RLS recursion detected, trying fallback query...');
      try {
        // Try a simpler query without any joins
        final fallbackProfile = await _client
            .from('profiles')
            .select('id, email, full_name, role, role_type, shop_id')
            .eq('id', userId!)
            .maybeSingle();
        
        if (fallbackProfile != null) {
          print('✅ Fallback profile query succeeded');
          _cachedRole = fallbackProfile['role'];
          _cachedRoleType = fallbackProfile['role_type'];
          _cachedShopId = fallbackProfile['shop_id'];
          return fallbackProfile;
        }
      } catch (fallbackError) {
        print('❌ Fallback query also failed: $fallbackError');
      }
    }
    
    return null;
  }
}

  // Update profile
  Future<bool> updateProfile({
    String? fullName,
    String? phone,
  }) async {
    if (userId == null) {
      print('❌ No user ID found');
      return false;
    }
    
    try {
      print('📝 Updating profile for user: $userId');
      
      final updates = <String, dynamic>{};
      if (fullName != null && fullName.isNotEmpty) {
        updates['full_name'] = fullName;
      }
      if (phone != null && phone.isNotEmpty) {
        updates['phone'] = phone;
      }
      
      if (updates.isEmpty) {
        print('⚠️ No updates to apply');
        return true;
      }
      
      updates['updated_at'] = DateTime.now().toIso8601String();
      
      print('📤 Sending updates: $updates');
      
      // Update profile
      await _client
          .from('profiles')
          .update(updates)
          .eq('id', userId!);
      
      print('✅ Profile updated successfully');
      
      // Clear cache to force reload
      await _clearCache();
      
      return true;
      
    } catch (e) {
      print('❌ Error updating profile: $e');
      return false;
    }
  }

  // Get all users (Super Admin only)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final response = await _client
          .from('profiles')
          .select('*')
          .order('created_at', ascending: false);
      
      print('✅ Found ${response.length} users');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting users: $e');
      return [];
    }
  }

  // Update user role (Admin only)
  Future<bool> updateUserRole(String userId, String newRole) async {
    try {
      print('🔄 Updating user $userId to role: $newRole');
      
      await _client
          .from('profiles')
          .update({
            'role_type': newRole,
            'updated_at': DateTime.now().toIso8601String()
          })
          .eq('id', userId);
      
      print('✅ Role updated successfully');
      
      // If this is the current user, clear cache
      if (userId == this.userId) {
        await _clearCache();
      }
      
      return true;
    } catch (e) {
      print('❌ Error updating user role: $e');
      return false;
    }
  }

  // Toggle user active status (Admin only)
  Future<bool> toggleUserStatus(String userId, bool isActive) async {
    try {
      await _client
          .from('profiles')
          .update({
            'is_active': isActive,
            'updated_at': DateTime.now().toIso8601String()
          })
          .eq('id', userId);
      
      print('✅ Status updated to $isActive for user: $userId');
      return true;
    } catch (e) {
      print('❌ Error toggling user status: $e');
      return false;
    }
  }

  // Get activity logs (Admin only)
  Future<List<Map<String, dynamic>>> getActivityLogs({int limit = 50}) async {
    try {
      final response = await _client
          .from('activity_logs')
          .select('*, profiles!inner(full_name, email)')
          .order('created_at', ascending: false)
          .limit(limit);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting activity logs: $e');
      return [];
    }
  }

  // ========== SHOP MANAGEMENT METHODS ==========
  
  // Create new shop (Super Admin only)
  Future<bool> createShop({
    required String name,
    required String ownerEmail,
    required String ownerName,
    String? address,
    String? phone,
  }) async {
    try {
      print('🏪 Creating new shop: $name');
      print('👤 Owner: $ownerName ($ownerEmail)');
      
      await _client.rpc('create_shop', params: {
        'shop_name': name,
        'owner_email': ownerEmail,
        'owner_name': ownerName,
      });
      
      print('✅ Shop created successfully');
      return true;
      
    } catch (e) {
      print('❌ Error creating shop: $e');
      if (e is PostgrestException) {
        print('❌ Error code: ${e.code}');
        print('❌ Error message: ${e.message}');
      }
      return false;
    }
  }

  // Get all shops (Super Admin only)
  Future<List<Map<String, dynamic>>> getAllShops() async {
    try {
      final response = await _client
          .from('shops')
          .select('*')
          .order('created_at', ascending: false);
      
      // Get owner details separately
      final shopsWithOwners = await Future.wait(
        response.map((shop) async {
          if (shop['owner_id'] != null) {
            try {
              final owner = await _client
                  .from('profiles')
                  .select('full_name, email')
                  .eq('id', shop['owner_id'])
                  .maybeSingle();
              shop['profiles'] = owner;
            } catch (e) {
              shop['profiles'] = null;
            }
          }
          return shop;
        }),
      );
      
      return List<Map<String, dynamic>>.from(shopsWithOwners);
    } catch (e) {
      print('❌ Error getting shops: $e');
      return [];
    }
  }

  // Get shops for current user
  Future<List<Map<String, dynamic>>> getUserShops() async {
    try {
      if (await isSuperAdmin) {
        return await getAllShops();
      }
      
      final shopId = await userShopId;
      if (shopId == null) return [];
      
      final response = await _client
          .from('shops')
          .select('*')
          .eq('id', shopId);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting user shops: $e');
      return [];
    }
  }

  // Add worker to shop (Shop Owner/Manager only)
  Future<bool> addWorkerToShop({
    required String email,
    required String fullName,
    required String role,
  }) async {
    try {
      final shopId = await userShopId;
      if (shopId == null) {
        print('❌ No shop ID found');
        return false;
      }

      print('📝 Adding worker to shop: $shopId');
      print('👤 Worker: $fullName ($email)');
      print('🔧 Role: $role');

      await _client.rpc('add_worker_to_shop', params: {
        'p_worker_email': email,
        'p_worker_name': fullName,
        'p_shop_id': shopId,
        'p_worker_role': role,
      });

      print('✅ Worker added successfully');
      
      return true;
    } catch (e) {
      print('❌ Error adding worker: $e');
      if (e is PostgrestException) {
        print('❌ Error code: ${e.code}');
        print('❌ Error message: ${e.message}');
      }
      return false;
    }
  }

  // Get workers in current shop
  Future<List<Map<String, dynamic>>> getShopWorkers() async {
    try {
      final shopId = await userShopId;
      if (shopId == null) return [];
      
      final response = await _client
          .from('profiles')
          .select('*')
          .eq('shop_id', shopId)
          .neq('role_type', 'shop_owner')
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting workers: $e');
      return [];
    }
  }

  // Update worker role
  Future<bool> updateWorkerRole(String workerId, String newRole) async {
    try {
      await _client
          .from('profiles')
          .update({
            'role_type': newRole,
            'updated_at': DateTime.now().toIso8601String()
          })
          .eq('id', workerId);
      
      print('✅ Worker role updated');
      return true;
    } catch (e) {
      print('❌ Error updating worker role: $e');
      return false;
    }
  }

  // Remove worker from shop
  Future<bool> removeWorker(String workerId) async {
    try {
      await _client
          .from('profiles')
          .update({
            'shop_id': null, 
            'role_type': 'worker',
            'updated_at': DateTime.now().toIso8601String()
          })
          .eq('id', workerId);
      
      print('✅ Worker removed');
      return true;
    } catch (e) {
      print('❌ Error removing worker: $e');
      return false;
    }
  }

  // Get shop stats
  Future<Map<String, dynamic>> getShopStats() async {
    try {
      final shopId = await userShopId;
      if (shopId == null) return {};
      
      final response = await _client
          .rpc('get_shop_stats', params: {'p_shop_id': shopId});
      
      return response;
    } catch (e) {
      print('❌ Error getting shop stats: $e');
      return {};
    }
  }

  // Switch shop (for multi-shop owners)
  Future<bool> switchShop(String newShopId) async {
    try {
      await _client
          .from('profiles')
          .update({
            'shop_id': newShopId,
            'updated_at': DateTime.now().toIso8601String()
          })
          .eq('id', userId!);
      
      await _clearCache();
      
      print('✅ Switched to shop: $newShopId');
      return true;
    } catch (e) {
      print('❌ Error switching shop: $e');
      return false;
    }
  }

  // Get shop details (Super Admin only)
  Future<Map<String, dynamic>> getShopDetails(String shopId) async {
    try {
      final shop = await _client
          .from('shops')
          .select('*')
          .eq('id', shopId)
          .single();
      
      final workers = await _client
          .from('profiles')
          .select('id, full_name, email, role_type, is_active')
          .eq('shop_id', shopId);
      
      final stats = await _client
          .rpc('get_shop_stats', params: {'p_shop_id': shopId});
      
      return {
        'shop': shop,
        'workers': workers,
        'stats': stats,
      };
    } catch (e) {
      print('❌ Error getting shop details: $e');
      return {};
    }
  }

  // Delete shop (Super Admin only)
  Future<bool> deleteShop(String shopId) async {
    try {
      // First, remove shop_id from all profiles
      await _client
          .from('profiles')
          .update({
            'shop_id': null, 
            'role_type': 'worker',
            'updated_at': DateTime.now().toIso8601String()
          })
          .eq('shop_id', shopId);
      
      // Then delete the shop
      await _client
          .from('shops')
          .delete()
          .eq('id', shopId);
      
      print('✅ Shop deleted successfully');
      return true;
    } catch (e) {
      print('❌ Error deleting shop: $e');
      return false;
    }
  }
}