import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';

class ReportService {
  static final ReportService _instance = ReportService._internal();
  factory ReportService() => _instance;
  ReportService._internal();

  // Sales by period
  Map<String, dynamic> getSalesByPeriod(
    List<Map<String, dynamic>> sales,
    String period, // 'day', 'week', 'month', 'year'
  ) {
    final Map<String, double> salesByDate = {};
    final Map<String, int> countByDate = {};
    
    final now = DateTime.now();
    DateTime startDate;
    
    switch (period) {
      case 'day':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        startDate = now.subtract(Duration(days: 7));
        break;
      case 'month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'year':
        startDate = DateTime(now.year, 1, 1);
        break;
      default:
        startDate = DateTime(now.year, now.month, 1);
    }
    
    for (var sale in sales) {
      final date = DateTime.parse(sale['sold_at']);
      if (date.isBefore(startDate)) continue;
      
      final key = DateFormat('yyyy-MM-dd').format(date);
      salesByDate[key] = (salesByDate[key] ?? 0) + (sale['price_ghs'] ?? 0).toDouble();
      countByDate[key] = (countByDate[key] ?? 0) + 1;
    }
    
    // Sort by date
    final sortedKeys = salesByDate.keys.toList()..sort();
    final sortedSales = sortedKeys.map((key) => salesByDate[key]!).toList();
    final sortedCounts = sortedKeys.map((key) => countByDate[key]!).toList();
    
    return {
      'labels': sortedKeys,
      'sales': sortedSales,
      'counts': sortedCounts,
      'total': sortedSales.fold(0.0, (sum, val) => sum + val),
      'average': sortedSales.isEmpty ? 0 : sortedSales.fold(0.0, (sum, val) => sum + val) / sortedSales.length,
    };
  }

  // Top selling models
  List<Map<String, dynamic>> getTopModels(
    List<Map<String, dynamic>> sales,
    int limit,
  ) {
    final Map<String, Map<String, dynamic>> modelStats = {};
    
    for (var sale in sales) {
      final inventory = sale['inventory_items'] ?? {};
      final product = inventory['products'] ?? {};
      final model = product['model'] ?? 'Unknown';
      
      if (!modelStats.containsKey(model)) {
        modelStats[model] = {
          'model': model,
          'count': 0,
          'revenue': 0.0,
          'profit': 0.0,
        };
      }
      
      modelStats[model]!['count'] = modelStats[model]!['count'] + 1;
      modelStats[model]!['revenue'] = (modelStats[model]!['revenue'] ?? 0) + (sale['price_ghs'] ?? 0).toDouble();
    }
    
    final sorted = modelStats.values.toList()
      ..sort((a, b) => b['count'].compareTo(a['count']));
    
    return sorted.take(limit).toList();
  }

  // Payment method distribution
  List<Map<String, dynamic>> getPaymentDistribution(
    List<Map<String, dynamic>> sales,
  ) {
    final Map<String, double> distribution = {};
    
    for (var sale in sales) {
      final method = sale['payment_method'] ?? 'Cash';
      distribution[method] = (distribution[method] ?? 0) + 1;
    }
    
    return distribution.entries.map((e) => {
      'method': e.key,
      'count': e.value,
      'percentage': (e.value / sales.length * 100),
    }).toList();
  }

  // Profit analysis
  Map<String, dynamic> getProfitAnalysis(
    List<Map<String, dynamic>> sales,
    List<Map<String, dynamic>> inventory,
  ) {
    double totalRevenue = 0;
    double totalCost = 0;
    
    for (var sale in sales) {
      totalRevenue += (sale['price_ghs'] ?? 0).toDouble();
      
      // Find purchase price
      final imei = sale['inventory_items']?['imei'];
      final item = inventory.firstWhere(
        (i) => i['imei'] == imei,
        orElse: () => {},
      );
      totalCost += (item['purchase_price'] ?? 0).toDouble();
    }
    
    final profit = totalRevenue - totalCost;
    final margin = totalRevenue > 0 ? (profit / totalRevenue * 100) : 0;
    
    return {
      'revenue': totalRevenue,
      'cost': totalCost,
      'profit': profit,
      'margin': margin,
    };
  }

  // Chart data for line chart
  List<FlSpot> getLineChartData(Map<String, dynamic> salesData) {
    final sales = salesData['sales'] as List<double>;
    return List.generate(sales.length, (i) => FlSpot(i.toDouble(), sales[i]));
  }

  // Chart data for bar chart
  List<BarChartGroupData> getBarChartData(List<Map<String, dynamic>> topModels) {
    return List.generate(topModels.length, (i) {
      final model = topModels[i];
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: model['count'].toDouble(),
            color: Colors.blue,
            width: 20,
          ),
        ],
      );
    });
  }

  // Chart data for pie chart
  List<PieChartSectionData> getPieChartData(List<Map<String, dynamic>> distribution) {
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red];
    
    return List.generate(distribution.length, (i) {
      final item = distribution[i];
      return PieChartSectionData(
        value: item['count'].toDouble(),
        title: '${item['method']}\n${item['percentage'].toStringAsFixed(1)}%',
        color: colors[i % colors.length],
        radius: 100,
        titleStyle: const TextStyle(fontSize: 12, color: Colors.white),
      );
    });
  }

  // Export report as PDF
  Future<Uint8List> exportReportPDF(Map<String, dynamic> reportData) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Sales Report - ${DateFormat('MMMM yyyy').format(DateTime.now())}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text('Total Revenue'),
                        pw.Text(
                          '₵${reportData['totalRevenue'].toStringAsFixed(2)}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text('Total Profit'),
                        pw.Text(
                          '₵${reportData['profit'].toStringAsFixed(2)}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text('Top Selling Models', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Model'),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Units Sold'),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Revenue'),
                    ),
                  ],
                ),
                ...reportData['topModels'].map((model) => 
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(model['model']),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(model['count'].toString()),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('₵${model['revenue'].toStringAsFixed(2)}'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    
    return await pdf.save();
  }
}