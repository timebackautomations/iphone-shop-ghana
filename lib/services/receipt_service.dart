import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

class ReceiptService {
  static final ReceiptService _instance = ReceiptService._internal();
  factory ReceiptService() => _instance;
  ReceiptService._internal();

  final pdfFormat = NumberFormat.currency(locale: 'en_US', symbol: '₵');
  final usdFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');

  // Generate PDF Receipt with QR Code
  Future<Uint8List> generateReceipt({
    required String saleId,
    required String imei,
    required String model,
    required double priceUsd,
    required double priceGhs,
    required String paymentMethod,
    required DateTime date,
    String? customerName,
    String? customerPhone,
    String? shopName,
    String? shopAddress,
    String? shopPhone,
  }) async {
    final pdf = pw.Document();
    final qrData = 'SALE:$saleId\nIMEI:$imei\nAMOUNT:₵${priceGhs.toStringAsFixed(2)}\nDATE:${DateFormat('yyyy-MM-dd').format(date)}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a6,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  shopName ?? 'iPhone Shop Ghana',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue,
                  ),
                ),
                if (shopAddress != null)
                  pw.Text(shopAddress, style: const pw.TextStyle(fontSize: 8)),
                if (shopPhone != null)
                  pw.Text('Tel: $shopPhone', style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 10),
                pw.Container(
                  height: 1,
                  width: double.infinity,
                  color: PdfColors.grey300,
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 10),
          
          pw.Center(
            child: pw.Text(
              'SALES RECEIPT',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          
          pw.SizedBox(height: 10),
          
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Receipt #:', style: const pw.TextStyle(fontSize: 10)),
              pw.Text(saleId.substring(0, 8).toUpperCase(), 
                style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Date:', style: const pw.TextStyle(fontSize: 10)),
              pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(date), 
                style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Payment:', style: const pw.TextStyle(fontSize: 10)),
              pw.Text(paymentMethod, style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
          
          pw.SizedBox(height: 10),
          pw.Container(height: 1, color: PdfColors.grey300),
          pw.SizedBox(height: 10),
          
          pw.Table(
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Description', 
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Qty', 
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Price', 
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(model, style: const pw.TextStyle(fontSize: 9)),
                        pw.Text('IMEI: $imei', 
                          style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                      ],
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('1', style: const pw.TextStyle(fontSize: 9)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      usdFormat.format(priceUsd),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          pw.SizedBox(height: 10),
          
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text('Subtotal: ', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(usdFormat.format(priceUsd), 
                      style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text('Total (GHS): ', 
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                      pdfFormat.format(priceGhs),
                      style: pw.TextStyle(
                        fontSize: 14, 
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),
          
          pw.Center(
            child: pw.Container(
              width: 80,
              height: 80,
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: qrData,
                width: 80,
                height: 80,
              ),
            ),
          ),
          
          pw.SizedBox(height: 10),
          
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text('Thank you for your purchase!', 
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text('Visit us again', style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Scan QR code to verify receipt',
                  style: pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return await pdf.save();
  }

  // Print Receipt
  Future<void> printReceipt(Uint8List pdfData) async {
    await Printing.layoutPdf(
      onLayout: (format) => pdfData,
      name: 'Sales_Receipt',
    );
  }

  // Share Receipt
  Future<void> shareReceipt(Uint8List pdfData, String saleId) async {
    await Printing.sharePdf(
      bytes: pdfData,
      filename: 'receipt_$saleId.pdf',
    );
  }

  // Preview Receipt
  Future<void> previewReceipt(Uint8List pdfData) async {
    await Printing.layoutPdf(
      onLayout: (format) => pdfData,
    );
  }
}