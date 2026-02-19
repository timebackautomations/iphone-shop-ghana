import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/services.dart';
import '../services/receipt_service.dart';
import '../services/whatsapp_service.dart';

class SellScreen extends StatefulWidget {
  final Map<String, dynamic> inventoryItem;
  
  const SellScreen({super.key, required this.inventoryItem});

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _auth = AuthService();
  
  final TextEditingController priceController = TextEditingController();
  final TextEditingController customerNameController = TextEditingController();
  final TextEditingController customerPhoneController = TextEditingController();
  
  String paymentMethod = 'Cash';
  bool isLoading = false;
  double exchangeRate = 12.50;
  
  final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');
  final ghsFormat = NumberFormat.currency(locale: 'en_US', symbol: '₵');

  @override
  void initState() {
    super.initState();
    _loadExchangeRate();
    final purchasePrice = (widget.inventoryItem['purchase_price'] ?? 0).toDouble();
    // Set default price with 20% profit margin
    priceController.text = (purchasePrice * 1.2).toStringAsFixed(0);
  }

  Future<void> _loadExchangeRate() async {
    final rate = await SupabaseService.getExchangeRate();
    if (mounted) {
      setState(() => exchangeRate = rate);
    }
  }

  Future<void> _completeSale() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => isLoading = true);
    
    try {
      final priceUsd = double.parse(priceController.text);
      final priceGhs = priceUsd * exchangeRate;
      final inventoryId = widget.inventoryItem['id'];
      
      if (inventoryId == null) {
        throw Exception('Inventory ID is null');
      }
      
      final shopId = await _auth.userShopId;
      final userId = _auth.userId;
      
      final success = await SupabaseService.completeSale(
        inventoryId: inventoryId,
        priceUsd: priceUsd,
        priceGhs: priceGhs,
        paymentMethod: paymentMethod,
        customerName: customerNameController.text.isNotEmpty ? customerNameController.text : null,
        customerPhone: customerPhoneController.text.isNotEmpty ? customerPhoneController.text : null,
        shopId: shopId,
        userId: userId,
      );
      
      if (mounted) {
        setState(() => isLoading = false);
        
        if (success) {
          // Generate and show receipt options
          await _generateAndShowReceipt(priceUsd, priceGhs);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Failed to complete sale. Please try again.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
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

  Future<void> _generateAndShowReceipt(double priceUsd, double priceGhs) async {
    try {
      final product = widget.inventoryItem['products'] ?? {};
      final receiptService = ReceiptService();
      
      final pdf = await receiptService.generateReceipt(
        saleId: DateTime.now().millisecondsSinceEpoch.toString(),
        imei: widget.inventoryItem['imei'],
        model: product['model'] ?? 'iPhone',
        priceUsd: priceUsd,
        priceGhs: priceGhs,
        paymentMethod: paymentMethod,
        date: DateTime.now(),
        customerName: customerNameController.text.isNotEmpty ? customerNameController.text : null,
        customerPhone: customerPhoneController.text.isNotEmpty ? customerPhoneController.text : null,
        shopName: 'iPhone Shop Ghana',
        shopAddress: 'Accra, Ghana',
        shopPhone: '+233 123 456 789',
      );
      
      if (mounted) {
        _showReceiptOptions(pdf, priceGhs);
      }
    } catch (e) {
      print('Error generating receipt: $e');
      // Still show success dialog without receipt options
      _showSuccessDialog(priceGhs);
    }
  }

  void _showSuccessDialog(double priceGhs) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 60),
            SizedBox(height: 16),
            Text('Sale Completed!'),
          ],
        ),
        content: Text(
          'Sold for ${ghsFormat.format(priceGhs)}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, true); // Return success
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showReceiptOptions(Uint8List pdf, double priceGhs) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sale Completed! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 10),
            Text(
              '₵${priceGhs.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text('What would you like to do?'),
          ],
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.print, color: Colors.blue),
                onPressed: () async {
                  Navigator.pop(context);
                  await ReceiptService().printReceipt(pdf);
                  if (mounted) {
                    Navigator.pop(context, true);
                  }
                },
                tooltip: 'Print',
              ),
              IconButton(
                icon: const Icon(Icons.share, color: Colors.green),
                onPressed: () async {
                  Navigator.pop(context);
                  await ReceiptService().shareReceipt(pdf, 'sale_${DateTime.now().millisecondsSinceEpoch}');
                  if (mounted) {
                    Navigator.pop(context, true);
                  }
                },
                tooltip: 'Share',
              ),
              IconButton(
                icon: const Icon(Icons.message, color: Color(0xFF25D366)), // Changed from Icons.whatsapp
                onPressed: () async {
                  Navigator.pop(context);
                  if (customerPhoneController.text.isNotEmpty) {
                    await WhatsAppService().sendReceiptViaWhatsApp(
                      phoneNumber: customerPhoneController.text,
                      customerName: customerNameController.text,
                      saleId: DateTime.now().millisecondsSinceEpoch.toString(),
                      amount: priceGhs,
                      date: DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                    );
                    if (mounted) {
                      Navigator.pop(context, true);
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No customer phone number provided'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                tooltip: 'WhatsApp',
              ),
            ],
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true);
            },
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.inventoryItem['products'] ?? {};
    final purchasePrice = (widget.inventoryItem['purchase_price'] ?? 0).toDouble();
    final suggestedPrice = purchasePrice * 1.2;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Sale'),
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
                    // Product Details Card
                    Card(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade50, Colors.white],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PRODUCT DETAILS',
                              style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.phone_iphone, color: Colors.blue),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product['model'] ?? 'Unknown Model',
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'IMEI: ${widget.inventoryItem['imei']}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Purchase Price:'),
                                Text(
                                  currencyFormat.format(purchasePrice),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Suggested Price:'),
                                Text(
                                  '${currencyFormat.format(suggestedPrice)} (20% profit)',
                                  style: TextStyle(color: Colors.green.shade700, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Selling Price
                    TextFormField(
                      controller: priceController,
                      decoration: InputDecoration(
                        labelText: 'Selling Price (USD) *',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.attach_money),
                        suffixText: priceController.text.isNotEmpty
                            ? '≈ ${ghsFormat.format((double.tryParse(priceController.text) ?? 0) * exchangeRate)}'
                            : null,
                        suffixStyle: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w500),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter selling price';
                        }
                        final price = double.tryParse(value);
                        if (price == null) return 'Please enter a valid number';
                        if (price <= 0) return 'Price must be greater than 0';
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Payment Method
                    DropdownButtonFormField<String>(
                      value: paymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.payment),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Cash', child: Text('Cash 💵')),
                        DropdownMenuItem(value: 'Mobile Money', child: Text('Mobile Money 📱')),
                        DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer 🏦')),
                        DropdownMenuItem(value: 'Card', child: Text('Card 💳')),
                      ],
                      onChanged: (value) {
                        setState(() => paymentMethod = value!);
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Customer Information (Optional)
                    const Text(
                      'CUSTOMER INFORMATION (OPTIONAL)',
                      style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    TextFormField(
                      controller: customerNameController,
                      decoration: const InputDecoration(
                        labelText: 'Customer Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    TextFormField(
                      controller: customerPhoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Profit Preview
                    Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Estimated Profit:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              currencyFormat.format(
                                (double.tryParse(priceController.text) ?? 0) - purchasePrice
                              ),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Action Buttons
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
                            onPressed: _completeSale,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('COMPLETE SALE'),
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
    priceController.dispose();
    customerNameController.dispose();
    customerPhoneController.dispose();
    super.dispose();
  }
}