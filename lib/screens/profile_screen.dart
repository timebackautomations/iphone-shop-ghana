import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/services.dart';
import 'login_screen.dart'; // ADD THIS MISSING IMPORT

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _auth = AuthService();
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;
  bool _showUsers = false;
  bool _showActivities = false;
  bool _isSuperAdmin = false;
  bool _isShopOwner = false;
  String? _userRole;
  String? _shopId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      print('🔄 Loading profile data...');
      
      // Get user role
      _userRole = await _auth.userRoleType;
      _isSuperAdmin = await _auth.isSuperAdmin;
      _isShopOwner = await _auth.isShopOwner;
      _shopId = await _auth.userShopId;
      
      print('👑 User Role: $_userRole');
      print('👑 isSuperAdmin: $_isSuperAdmin');
      print('👑 isShopOwner: $_isShopOwner');
      print('🏪 Shop ID: $_shopId');
      
      final profile = await _auth.getUserProfile(forceRefresh: true);
      print('📊 Profile loaded: $profile');
      
      final stats = await SupabaseService.getSalesStats(_shopId);
      print('📈 Stats loaded: $stats');
      
      if (_isSuperAdmin || _isShopOwner) {
        final users = await _auth.getAllUsers();
        final activities = await _auth.getActivityLogs();
        if (mounted) {
          setState(() {
            _profile = profile;
            _stats = stats;
            _users = users;
            _activities = activities;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _profile = profile;
            _stats = stats;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading profile: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Error loading profile: $e');
      }
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

  // Profile Update Method
  Future<void> _updateProfile() async {
    final nameController = TextEditingController(text: _profile?['full_name'] ?? '');
    final phoneController = TextEditingController(text: _profile?['phone'] ?? '');
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
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
        print('📤 Sending profile update...');
        print('Name: ${nameController.text}');
        print('Phone: ${phoneController.text}');
        
        final success = await _auth.updateProfile(
          fullName: nameController.text.isNotEmpty ? nameController.text : null,
          phone: phoneController.text.isNotEmpty ? phoneController.text : null,
        );
        
        if (success && mounted) {
          await _loadData();
          _showSuccessSnackBar('✅ Profile updated successfully');
        } else {
          throw Exception('Update failed - check console for details');
        }
      } catch (e) {
        print('❌ Update error: $e');
        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorSnackBar('Error: Could not update profile. Please try again.');
        }
      }
    }
  }

  // Update User Role Method
  Future<void> _updateUserRole(String userId, String currentRole) async {
    final newRole = currentRole == 'super_admin' ? 'shop_owner' : 
                   currentRole == 'shop_owner' ? 'shop_manager' : 
                   currentRole == 'shop_manager' ? 'worker' : 'shop_manager';
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change User Role'),
        content: Text('Change role to $newRole?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      setState(() => _isLoading = true);
      final success = await _auth.updateUserRole(userId, newRole);
      if (success && mounted) {
        await _loadData();
        _showSuccessSnackBar('✅ Role changed to $newRole');
      }
    }
  }

  // Toggle User Status
  Future<void> _toggleUserStatus(String userId, bool currentStatus) async {
    final action = currentStatus ? 'Deactivate' : 'Activate';
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$action User'),
        content: Text('Are you sure you want to $action this user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: currentStatus ? Colors.orange : Colors.green,
            ),
            child: Text(action.toUpperCase()),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      setState(() => _isLoading = true);
      final success = await _auth.toggleUserStatus(userId, !currentStatus);
      if (success && mounted) {
        await _loadData();
        _showSuccessSnackBar('✅ User ${currentStatus ? 'deactivated' : 'activated'}');
      }
    }
  }

  // Sign Out Method - FIXED
  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
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
            child: const Text('SIGN OUT'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        print('🚪 Signing out...');
        await _auth.signOut();
        
        if (mounted) {
          // Clear navigation stack and go to login
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        print('❌ Sign out error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _getRoleDisplay(String roleType) {
    switch (roleType) {
      case 'super_admin':
        return 'SUPER ADMIN';
      case 'shop_owner':
        return 'SHOP OWNER';
      case 'shop_manager':
        return 'SHOP MANAGER';
      default:
        return 'WORKER';
    }
  }

  Color _getRoleColor(String roleType) {
    switch (roleType) {
      case 'super_admin':
        return Colors.purple;
      case 'shop_owner':
        return Colors.orange;
      case 'shop_manager':
        return Colors.teal;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
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
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Profile Header
                    Card(
                      elevation: 4,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_getRoleColor(_userRole ?? 'worker').withOpacity(0.1), Colors.white],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: _getRoleColor(_userRole ?? 'worker').withOpacity(0.2),
                              child: Text(
                                _profile?['full_name']?[0].toUpperCase() ?? 'U',
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: _getRoleColor(_userRole ?? 'worker'),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _profile?['full_name'] ?? 'User',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _profile?['email'] ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            if (_profile?['shop_name'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _profile?['shop_name'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getRoleColor(_userRole ?? 'worker').withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _getRoleDisplay(_userRole ?? 'worker'),
                                style: TextStyle(
                                  color: _getRoleColor(_userRole ?? 'worker'),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Stats Cards
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(
                              'Today',
                              '${_stats?['todayCount'] ?? 0}',
                              Icons.today,
                              Colors.blue,
                            ),
                            _buildStatItem(
                              'Month',
                              '${_stats?['monthCount'] ?? 0}',
                              Icons.date_range,
                              Colors.green,
                            ),
                            _buildStatItem(
                              'Total',
                              '${_stats?['totalCount'] ?? 0}',
                              Icons.shopping_cart,
                              Colors.orange,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Action Buttons
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.edit, color: Colors.blue),
                            ),
                            title: const Text('Edit Profile'),
                            subtitle: const Text('Update your personal information'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: _updateProfile,
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.logout, color: Colors.red),
                            ),
                            title: const Text(
                              'Sign Out',
                              style: TextStyle(color: Colors.red),
                            ),
                            subtitle: const Text('Log out of your account'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: _signOut,
                          ),
                        ],
                      ),
                    ),
                    
                    // Admin/Super Admin Section
                    if (_isSuperAdmin || _isShopOwner) ...[
                      const SizedBox(height: 16),
                      
                      // User Management
                      Card(
                        child: ExpansionTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.people, color: Colors.purple),
                          ),
                          title: const Text('User Management'),
                          subtitle: Text('${_users.length} total users'),
                          children: _users.map((user) {
                            final isCurrentUser = user['id'] == _auth.userId;
                            final userRoleType = user['role_type'] ?? 'worker';
                            
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getRoleColor(userRoleType).withOpacity(0.2),
                                child: Text(
                                  user['full_name']?[0].toUpperCase() ?? 'U',
                                  style: TextStyle(
                                    color: _getRoleColor(userRoleType),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(user['full_name'] ?? ''),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user['email'] ?? ''),
                                  Text(
                                    'Role: ${_getRoleDisplay(userRoleType)} • ${user['is_active'] == true ? 'Active' : 'Inactive'}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: user['is_active'] == true
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: isCurrentUser
                                  ? const Chip(
                                      label: Text('You'),
                                      backgroundColor: Colors.blue,
                                      labelStyle: TextStyle(color: Colors.white, fontSize: 10),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.admin_panel_settings,
                                            color: Colors.blue,
                                          ),
                                          onPressed: () => _updateUserRole(
                                            user['id'],
                                            userRoleType,
                                          ),
                                          tooltip: 'Change Role',
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            user['is_active'] == true
                                                ? Icons.check_circle
                                                : Icons.cancel,
                                            color: user['is_active'] == true
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                          onPressed: () => _toggleUserStatus(
                                            user['id'],
                                            user['is_active'] == true,
                                          ),
                                          tooltip: user['is_active'] == true
                                              ? 'Deactivate'
                                              : 'Activate',
                                        ),
                                      ],
                                    ),
                            );
                          }).toList(),
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Activity Logs
                      if (_isSuperAdmin) ...[
                        Card(
                          child: ExpansionTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.history, color: Colors.orange),
                            ),
                            title: const Text('Activity Logs'),
                            subtitle: Text('${_activities.length} recent activities'),
                            children: _activities.map((log) {
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.orange.shade100,
                                  radius: 20,
                                  child: const Icon(
                                    Icons.history,
                                    color: Colors.orange,
                                    size: 16,
                                  ),
                                ),
                                title: Text(
                                  log['action']?.replaceAll('_', ' ') ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'By: ${log['profiles']?['full_name'] ?? 'Unknown'}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    Text(
                                      DateFormat('MMM dd, yyyy • HH:mm').format(
                                        DateTime.parse(log['created_at']),
                                      ),
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
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

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 4),
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
    );
  }
}