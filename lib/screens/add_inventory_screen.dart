import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../services/services.dart';

class AddInventoryScreen extends StatefulWidget {
  final String imei;
  
  const AddInventoryScreen({super.key, required this.imei});

  @override
  State<AddInventoryScreen> createState() => _AddInventoryScreenState();
}

class _AddInventoryScreenState extends State<AddInventoryScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController modelController = TextEditingController();
  final TextEditingController colorController = TextEditingController();
  final TextEditingController storageController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  
  double batteryHealth = 85.0;
  String condition = 'Good';
  bool isLoading = false;
  double exchangeRate = 12.50;

  @override
  void initState() {
    super.initState();
    _loadExchangeRate();
  }

  Future<void> _loadExchangeRate() async {
    final rate = await SupabaseService.getExchangeRate();
    setState(() => exchangeRate = rate);
  }

Future<void> _saveInventory() async {
if (!_formKey.currentState!.validate()) return;

setState(() => isLoading = true);

try {
  final shopId = await AuthService().userShopId;
  final userId = await AuthService().userId;
final success = await SupabaseService.addToInventory(
  imei: widget.imei,
  model: modelController.text,
  color: colorController.text.isEmpty ? 'Unknown' : colorController.text,
  storage: storageController.text.isEmpty ? 'Unknown' : storageController.text,
  batteryHealth: batteryHealth,
  condition: condition,
  purchasePrice: double.parse(priceController.text),
  shopId: shopId,
  userId: userId,
);
      
      if (mounted) {
        setState(() => isLoading = false);
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Product added to inventory!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Failed to add product'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add to Inventory'),
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
                    // IMEI Card
                    Card(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade50, Colors.white],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.qr_code, color: Colors.blue),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'IMEI SCANNED',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  Text(
                                    widget.imei,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
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
                      initialValue: condition,
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
    modelController.dispose();
    colorController.dispose();
    storageController.dispose();
    priceController.dispose();
    super.dispose();
  }
}