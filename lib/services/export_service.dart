import 'dart:io';
import 'dart:convert'; // Add this for utf8
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  final DateFormat dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  final NumberFormat currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '₵');
  final NumberFormat usdFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');

  // Helper method to convert String to CellValue
  CellValue _toCellValue(String value) {
    return TextCellValue(value);
  }

  // Helper method to convert to List<CellValue?>
  List<CellValue?> _toCellValueList(List<String> values) {
    return values.map((v) => _toCellValue(v)).toList();
  }

  // Export Sales to Excel
  Future<File> exportSalesToExcel(List<Map<String, dynamic>> sales) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sales'];
      
      // Set column widths
      sheetObject.setColumnWidth(0, 20); // Date
      sheetObject.setColumnWidth(1, 15); // Receipt ID
      sheetObject.setColumnWidth(2, 20); // Model
      sheetObject.setColumnWidth(3, 25); // IMEI
      sheetObject.setColumnWidth(4, 20); // Customer
      sheetObject.setColumnWidth(5, 15); // Payment Method
      sheetObject.setColumnWidth(6, 15); // Amount (GHS)
      sheetObject.setColumnWidth(7, 15); // Profit (USD)
      sheetObject.setColumnWidth(8, 20); // Sold By
      
      // Headers
      var headers = _toCellValueList([
        'Date',
        'Receipt ID',
        'Model',
        'IMEI',
        'Customer',
        'Payment Method',
        'Amount (GHS)',
        'Profit (USD)',
        'Sold By',
      ]);
      
      sheetObject.appendRow(headers);
      
      // Style headers
      var headerRow = sheetObject.row(0);
      for (var cell in headerRow) {
        cell?.cellStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString('#1E88E5'),
          fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
          bold: true,
          fontSize: 12,
        );
      }
      
      // Data rows
      for (var sale in sales) {
        try {
          final inventory = sale['inventory_items'] ?? {};
          final product = inventory['products'] ?? {};
          final soldBy = sale['profiles'] ?? {};
          
          var row = _toCellValueList([
            dateFormat.format(DateTime.parse(sale['sold_at'])),
            sale['id']?.toString().substring(0, 8) ?? 'N/A',
            product['model']?.toString() ?? 'Unknown',
            inventory['imei']?.toString() ?? 'N/A',
            sale['customer_name']?.toString() ?? 'Walk-in',
            sale['payment_method']?.toString() ?? 'Cash',
            (sale['price_ghs'] ?? 0).toString(),
            (sale['profit'] ?? 0).toString(),
            soldBy['full_name']?.toString() ?? 'Unknown',
          ]);
          
          sheetObject.appendRow(row);
        } catch (e) {
          print('Error processing sale row: $e');
          continue;
        }
      }
      
      // Get downloads directory
      final directory = await getDownloadsDirectory();
      if (directory == null) {
        throw Exception('Could not access downloads directory');
      }
      
      final fileName = 'sales_report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(excel.encode()!);
      
      return file;
    } catch (e) {
      print('Error exporting sales to Excel: $e');
      rethrow;
    }
  }

  // Export Inventory to Excel
  Future<File> exportInventoryToExcel(List<Map<String, dynamic>> inventory) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Inventory'];
      
      // Set column widths
      sheetObject.setColumnWidth(0, 20); // Date Added
      sheetObject.setColumnWidth(1, 25); // IMEI
      sheetObject.setColumnWidth(2, 20); // Model
      sheetObject.setColumnWidth(3, 15); // Color
      sheetObject.setColumnWidth(4, 15); // Storage
      sheetObject.setColumnWidth(5, 12); // Battery %
      sheetObject.setColumnWidth(6, 12); // Condition
      sheetObject.setColumnWidth(7, 15); // Purchase Price
      sheetObject.setColumnWidth(8, 12); // Status
      sheetObject.setColumnWidth(9, 20); // Added By
      
      // Headers
      var headers = _toCellValueList([
        'Date Added',
        'IMEI',
        'Model',
        'Color',
        'Storage',
        'Battery %',
        'Condition',
        'Purchase Price',
        'Status',
        'Added By',
      ]);
      
      sheetObject.appendRow(headers);
      
      // Style headers
      var headerRow = sheetObject.row(0);
      for (var cell in headerRow) {
        cell?.cellStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString('#4CAF50'),
          fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
          bold: true,
          fontSize: 12,
        );
      }
      
      // Data rows
      for (var item in inventory) {
        try {
          final product = item['products'] ?? {};
          final addedBy = item['profiles'] ?? {};
          
          var row = _toCellValueList([
            dateFormat.format(DateTime.parse(item['created_at'])),
            item['imei']?.toString() ?? 'N/A',
            product['model']?.toString() ?? 'Unknown',
            product['color']?.toString() ?? 'Unknown',
            product['storage']?.toString() ?? 'Unknown',
            (item['battery_health'] ?? 0).toString(),
            item['condition']?.toString() ?? 'Good',
            (item['purchase_price'] ?? 0).toString(),
            item['status']?.toString() ?? 'available',
            addedBy['full_name']?.toString() ?? 'Unknown',
          ]);
          
          sheetObject.appendRow(row);
        } catch (e) {
          print('Error processing inventory row: $e');
          continue;
        }
      }
      
      final directory = await getDownloadsDirectory();
      if (directory == null) {
        throw Exception('Could not access downloads directory');
      }
      
      final fileName = 'inventory_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(excel.encode()!);
      
      return file;
    } catch (e) {
      print('Error exporting inventory to Excel: $e');
      rethrow;
    }
  }

  // Export Sales to CSV
  Future<File> exportSalesToCSV(List<Map<String, dynamic>> sales) async {
    try {
      final buffer = StringBuffer();
      
      // Headers
      buffer.writeln('Date,Receipt ID,Model,IMEI,Customer,Payment Method,Amount (GHS),Profit (USD),Sold By');
      
      // Data
      for (var sale in sales) {
        try {
          final inventory = sale['inventory_items'] ?? {};
          final product = inventory['products'] ?? {};
          final soldBy = sale['profiles'] ?? {};
          
          final row = [
            dateFormat.format(DateTime.parse(sale['sold_at'])),
            sale['id']?.toString().substring(0, 8) ?? 'N/A',
            _escapeCSV(product['model']?.toString() ?? 'Unknown'),
            _escapeCSV(inventory['imei']?.toString() ?? 'N/A'),
            _escapeCSV(sale['customer_name']?.toString() ?? 'Walk-in'),
            _escapeCSV(sale['payment_method']?.toString() ?? 'Cash'),
            (sale['price_ghs'] ?? 0).toString(),
            (sale['profit'] ?? 0).toString(),
            _escapeCSV(soldBy['full_name']?.toString() ?? 'Unknown'),
          ].join(',');
          
          buffer.writeln(row);
        } catch (e) {
          print('Error processing sale row for CSV: $e');
          continue;
        }
      }
      
      final directory = await getDownloadsDirectory();
      if (directory == null) {
        throw Exception('Could not access downloads directory');
      }
      
      final fileName = 'sales_report_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(buffer.toString(), encoding: Encoding.getByName('utf-8')!);
      
      return file;
    } catch (e) {
      print('Error exporting sales to CSV: $e');
      rethrow;
    }
  }

  // Export Inventory to CSV
  Future<File> exportInventoryToCSV(List<Map<String, dynamic>> inventory) async {
    try {
      final buffer = StringBuffer();
      
      // Headers
      buffer.writeln('Date Added,IMEI,Model,Color,Storage,Battery %,Condition,Purchase Price,Status,Added By');
      
      // Data
      for (var item in inventory) {
        try {
          final product = item['products'] ?? {};
          final addedBy = item['profiles'] ?? {};
          
          final row = [
            dateFormat.format(DateTime.parse(item['created_at'])),
            _escapeCSV(item['imei']?.toString() ?? 'N/A'),
            _escapeCSV(product['model']?.toString() ?? 'Unknown'),
            _escapeCSV(product['color']?.toString() ?? 'Unknown'),
            _escapeCSV(product['storage']?.toString() ?? 'Unknown'),
            (item['battery_health'] ?? 0).toString(),
            _escapeCSV(item['condition']?.toString() ?? 'Good'),
            (item['purchase_price'] ?? 0).toString(),
            _escapeCSV(item['status']?.toString() ?? 'available'),
            _escapeCSV(addedBy['full_name']?.toString() ?? 'Unknown'),
          ].join(',');
          
          buffer.writeln(row);
        } catch (e) {
          print('Error processing inventory row for CSV: $e');
          continue;
        }
      }
      
      final directory = await getDownloadsDirectory();
      if (directory == null) {
        throw Exception('Could not access downloads directory');
      }
      
      final fileName = 'inventory_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(buffer.toString(), encoding: Encoding.getByName('utf-8')!);
      
      return file;
    } catch (e) {
      print('Error exporting inventory to CSV: $e');
      rethrow;
    }
  }

  // Export Sales Summary Report
  Future<File> exportSalesSummary(Map<String, dynamic> summary) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Summary'];
      
      // Headers
      sheetObject.appendRow(_toCellValueList(['Sales Summary Report']));
      sheetObject.appendRow(_toCellValueList([
        'Generated:', 
        dateFormat.format(DateTime.now())
      ]));
      sheetObject.appendRow(_toCellValueList([]));
      
      // Summary Data
      sheetObject.appendRow(_toCellValueList([
        'Total Sales:', 
        summary['totalSales']?.toString() ?? '0'
      ]));
      sheetObject.appendRow(_toCellValueList([
        'Total Revenue:', 
        '₵${(summary['totalRevenue'] as num?)?.toStringAsFixed(2) ?? '0.00'}'
      ]));
      sheetObject.appendRow(_toCellValueList([
        'Total Profit:', 
        '\$${(summary['totalProfit'] as num?)?.toStringAsFixed(2) ?? '0.00'}'
      ]));
      sheetObject.appendRow(_toCellValueList([
        'Average Sale:', 
        '₵${(summary['averageSale'] as num?)?.toStringAsFixed(2) ?? '0.00'}'
      ]));
      
      // Style the header
      var headerRow = sheetObject.row(0);
      for (var cell in headerRow) {
        cell?.cellStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString('#1E88E5'),
          fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
          bold: true,
          fontSize: 14,
        );
      }
      
      final directory = await getDownloadsDirectory();
      if (directory == null) {
        throw Exception('Could not access downloads directory');
      }
      
      final fileName = 'sales_summary_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(excel.encode()!);
      
      return file;
    } catch (e) {
      print('Error exporting sales summary: $e');
      rethrow;
    }
  }

  // Share file
  Future<void> shareFile(File file) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Exported data from iPhone Shop Ghana',
      );
    } catch (e) {
      print('Error sharing file: $e');
      rethrow;
    }
  }

  // Share multiple files
  Future<void> shareMultipleFiles(List<File> files) async {
    try {
      final xFiles = files.map((file) => XFile(file.path)).toList();
      await Share.shareXFiles(
        xFiles,
        text: 'Exported data from iPhone Shop Ghana',
      );
    } catch (e) {
      print('Error sharing files: $e');
      rethrow;
    }
  }

  // Get file size in readable format
  String getFileSize(File file) {
    try {
      final bytes = file.lengthSync();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(2)} KB';
      if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(2)} MB';
      return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
    } catch (e) {
      return 'Unknown size';
    }
  }

  // Delete file after sharing (optional)
  Future<void> deleteFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
        print('File deleted: ${file.path}');
      }
    } catch (e) {
      print('Error deleting file: $e');
    }
  }

  // Helper method to escape CSV fields
  String _escapeCSV(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  // Get file extension
  String getFileExtension(String fileName) {
    return fileName.split('.').last;
  }

  // Check if file exists
  Future<bool> fileExists(String path) async {
    final file = File(path);
    return await file.exists();
  }
}