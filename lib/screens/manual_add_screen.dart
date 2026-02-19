import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/services.dart';

class ManualAddScreen extends StatefulWidget {
  const ManualAddScreen({super.key});

  @override
  State<ManualAddScreen> createState() => _ManualAddScreenState();
}

class _ManualAddScreenState extends State<ManualAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _auth = AuthService();
  
  final TextEditingController imeiController = TextEditingController();
  final TextEditingController modelController = TextEditingController();
  final TextEditingController colorController = TextEditingController();
  final TextEditingController storageController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  
  double batteryHealth = 85.0;
  String condition = 'Good';
  bool isLoading = false;
  bool isCheckingImei = false;
  double exchangeRate = 12.50;
  String? _shopId;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final rate = await SupabaseService.getExchangeRate();
    _shopId = await _auth.userShopId;
    _userId = _auth.userId;
    setState(() => exchangeRate = rate);
  }

  Future<void> _checkImei() async {
    final imei = imeiController.text.trim();
    if (imei.isEmpty || imei.length != 15) {
      _showMessage('Please enter a valid 15-digit IMEI', Colors.orange);
      return;
    }

    setState(() => isCheckingImei = true);

    try {
      if (_shopId == null) {
        throw Exception('No shop selected');
      }
      
      final exists = await SupabaseService.checkImeiExists(imei, shopId: _shopId);
      
      if (mounted) {
        if (exists) {
          _showDialog(
            'IMEI Already Exists',
            'IMEI: $imei\n\nThis IMEI is already in your inventory.',
          );
        } else {
          _showMessage('✅ IMEI is available', Colors.green);
        }
      }
    } catch (e) {
      _showMessage('Error checking IMEI: $e', Colors.red);
    } finally {
      if (mounted) setState(() => isCheckingImei = false);
    }
  }

  Future<void> _saveInventory() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => isLoading = true);
    
    try {
      if (_shopId == null || _userId == null) {
        throw Exception('Shop ID or User ID not available');
      }
      
      final success = await SupabaseService.addToInventory(
        imei: imeiController.text.trim(),
        model: modelController.text,
        color: colorController.text.isEmpty ? 'Unknown' : colorController.text,
        storage: storageController.text.isEmpty ? 'Unknown' : storageController.text,
        batteryHealth: batteryHealth,
        condition: condition,
        purchasePrice: double.parse(priceController.text),
        shopId: _shopId,
        userId: _userId,
      );
      
      if (mounted) {
        setState(() => isLoading = false);
        
        if (success) {
          _showMessage('✅ Product added to inventory!', Colors.green);
          Navigator.pop(context, true);
        } else {
          _showMessage('❌ Failed to add product', Colors.red);
        }
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showMessage('Error: $e', Colors.red);
    }
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Color _getBatteryColor(double health) {
    if (health >= 85) return Colors.green;
    if (health >= 70) return Colors.lightGreen;
    if (health >= 50) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Manually'),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // IMEI Field with Check Button
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: imeiController,
                            decoration: const InputDecoration(
                              labelText: 'IMEI *',
                              hintText: 'Enter 15-digit IMEI',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.qr_code),
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 15,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter IMEI';
                              }
                              if (value.length != 15) {
                                return 'IMEI must be 15 digits';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: isCheckingImei ? null : _checkImei,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            child: isCheckingImei
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.check),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Model Field
                    TextFormField(
                      controller: modelController,
                      decoration: const InputDecoration(
                        labelText: 'Model *',
                        hintText: 'e.g., iPhone 14 Pro Max',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone_iphone),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter model';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Color Field
                    TextFormField(
                      controller: colorController,
                      decoration: const InputDecoration(
                        labelText: 'Color',
                        hintText: 'e.g., Deep Purple',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.palette),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Storage Field
                    TextFormField(
                      controller: storageController,
                      decoration: const InputDecoration(
                        labelText: 'Storage',
                        hintText: 'e.g., 128GB, 256GB',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.storage),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Battery Health Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  '🔋 Battery Health',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getBatteryColor(batteryHealth).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${batteryHealth.round()}%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _getBatteryColor(batteryHealth),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Slider(
                              value: batteryHealth,
                              min: 0,
                              max: 100,
                              divisions: 100,
                              activeColor: _getBatteryColor(batteryHealth),
                              onChanged: (value) {
                                setState(() {
                                  batteryHealth = value;
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Poor', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                Text('Good', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                Text('Excellent', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Condition Dropdown
                    DropdownButtonFormField<String>(
                      value: condition,
                      decoration: const InputDecoration(
                        labelText: 'Condition',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.health_and_safety),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Mint', child: Text('Mint')),
                        DropdownMenuItem(value: 'Good', child: Text('Good')),
                        DropdownMenuItem(value: 'Fair', child: Text('Fair')),
                        DropdownMenuItem(value: 'Poor', child: Text('Poor')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          condition = value!;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Purchase Price
                    TextFormField(
                      controller: priceController,
                      decoration: InputDecoration(
                        labelText: 'Purchase Price (USD) *',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.attach_money),
                        suffixText: priceController.text.isNotEmpty
                            ? '≈ ${(double.tryParse(priceController.text) ?? 0) * exchangeRate} GHS'
                            : null,
                        suffixStyle: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter purchase price';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('CANCEL'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saveInventory,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('SAVE'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    imeiController.dispose();
    modelController.dispose();
    colorController.dispose();
    storageController.dispose();
    priceController.dispose();
    super.dispose();
  }
}