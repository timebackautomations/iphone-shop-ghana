import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class WhatsAppService {
  static final WhatsAppService _instance = WhatsAppService._internal();
  factory WhatsAppService() => _instance;
  WhatsAppService._internal();

  // Send message via WhatsApp
  Future<bool> sendWhatsApp({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      // Remove any non-numeric characters
      String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      
      // Add country code if missing (assuming Ghana +233)
      if (cleanPhone.startsWith('0')) {
        cleanPhone = '233${cleanPhone.substring(1)}';
      }
      
      final Uri whatsappUrl = Uri.parse(
        'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}'
      );
      
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    } catch (e) {
      print('Error sending WhatsApp: $e');
      return false;
    }
  }

  // Send receipt via WhatsApp
  Future<void> sendReceiptViaWhatsApp({
    required String phoneNumber,
    required String customerName,
    required String saleId,
    required double amount,
    required String date,
  }) async {
    final message = '''
🛍️ *iPhone Shop Ghana - Receipt*

Hello $customerName,

Thank you for your purchase!

*Receipt ID:* $saleId
*Date:* $date
*Amount:* ₵${amount.toStringAsFixed(2)}

Your phone has been recorded in our system.
For support, please contact us.

Thank you for choosing iPhone Shop Ghana! 📱
''';

    await sendWhatsApp(phoneNumber: phoneNumber, message: message);
  }

  // Send promotion to all customers (for admin)
  Future<void> sendBulkPromotion({
    required List<String> phoneNumbers,
    required String message,
  }) async {
    for (String phone in phoneNumbers) {
      await sendWhatsApp(phoneNumber: phone, message: message);
      await Future.delayed(const Duration(seconds: 2)); // Delay to avoid spam
    }
  }

  // Share via other apps
  Future<void> shareViaOther(String text) async {
    await Share.share(text);
  }
}