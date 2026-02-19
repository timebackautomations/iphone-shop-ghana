import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:workmanager/workmanager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final AndroidFlutterLocalNotificationsPlugin _android = AndroidFlutterLocalNotificationsPlugin();
  
  bool _initialized = false;

  // Initialize notifications
  Future<void> initialize() async {
    if (_initialized) return;
    
    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    
    // Request permissions
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    
    _initialized = true;
    
    // Initialize background work
    await _initBackgroundWork();
  }

  // Handle notification tap
  void _onNotificationTap(NotificationResponse response) {
    // Navigate to specific screen based on payload
    final payload = response.payload;
    // Handle navigation
  }

  // Show instant notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? channelId = 'iphone_shop_channel',
    String? channelName = 'iPhone Shop Notifications',
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'iphone_shop_channel',
      'iPhone Shop Notifications',
      channelDescription: 'Notifications from iPhone Shop Management System',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      showWhen: true,
      enableLights: true,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notifications.show(
      id,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  // Schedule notification
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'scheduled_channel',
      'Scheduled Notifications',
      channelDescription: 'Scheduled notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const iosDetails = DarwinNotificationDetails();
    
    final platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  // Cancel notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  // Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  // Update app badge count
  Future<void> updateBadgeCount(int count) async {
    if (await FlutterAppBadger.isAppBadgeSupported()) {
      FlutterAppBadger.updateBadgeCount(count);
    }
  }

  // Remove badge
  Future<void> removeBadge() async {
    if (await FlutterAppBadger.isAppBadgeSupported()) {
      FlutterAppBadger.removeBadge();
    }
  }

  // Initialize background work
  Future<void> _initBackgroundWork() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
  }

  // Register periodic tasks
  void registerPeriodicTasks() {
    Workmanager().registerPeriodicTask(
      'daily-sales-report',
      'dailySalesReport',
      frequency: const Duration(hours: 24),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
        requiresCharging: false,
      ),
    );
    
    Workmanager().registerPeriodicTask(
      'low-stock-check',
      'lowStockCheck',
      frequency: const Duration(hours: 6),
    );
  }

  // Show low stock alert
  Future<void> showLowStockAlert(String model, int count) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '⚠️ Low Stock Alert',
      body: '$model has only $count items left in inventory',
      payload: 'inventory',
    );
  }

  // Show daily sales summary
  Future<void> showDailySalesSummary({
    required double revenue,
    required int salesCount,
    required double profit,
  }) async {
    final date = DateFormat('MMM dd, yyyy').format(DateTime.now());
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '📊 Daily Sales Summary - $date',
      body: 'Sales: $salesCount | Revenue: ₵${revenue.toStringAsFixed(2)} | Profit: ₵${profit.toStringAsFixed(2)}',
      payload: 'reports',
    );
  }

  // Show new sale notification
  Future<void> showNewSaleNotification({
    required String model,
    required double amount,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '💰 New Sale!',
      body: '$model sold for ₵${amount.toStringAsFixed(2)}',
      payload: 'sales',
    );
  }

  // Show exchange rate update
  Future<void> showExchangeRateUpdate(double rate) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '💱 Exchange Rate Updated',
      body: '1 USD = ₵${rate.toStringAsFixed(2)}',
      payload: 'settings',
    );
  }
}

// Background callback dispatcher
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case 'dailySalesReport':
        await _generateDailySalesReport();
        break;
      case 'lowStockCheck':
        await _checkLowStock();
        break;
    }
    return Future.value(true);
  });
}

Future<void> _generateDailySalesReport() async {
  // Get yesterday's sales
  final yesterday = DateTime.now().subtract(const Duration(days: 1));
  final start = DateTime(yesterday.year, yesterday.month, yesterday.day);
  final end = start.add(const Duration(days: 1));
  
  final sales = await Supabase.instance.client
      .from('sales')
      .select('price_ghs')
      .gte('sold_at', start.toIso8601String())
      .lt('sold_at', end.toIso8601String());
  
  double revenue = 0;
  for (var sale in sales) {
    revenue += (sale['price_ghs'] ?? 0).toDouble();
  }
  
  await NotificationService().showDailySalesSummary(
    revenue: revenue,
    salesCount: sales.length,
    profit: revenue * 0.2, // Estimate profit margin
  );
}

Future<void> _checkLowStock() async {
  final inventory = await Supabase.instance.client
      .from('inventory_items')
      .select('*, products(*)')
      .eq('status', 'available');
  
  // Group by model
  final Map<String, int> modelCounts = {};
  for (var item in inventory) {
    final model = item['products']?['model'] ?? 'Unknown';
    modelCounts[model] = (modelCounts[model] ?? 0) + 1;
  }
  
  // Check for low stock (threshold: 3)
  for (var entry in modelCounts.entries) {
    if (entry.value <= 3) {
      await NotificationService().showLowStockAlert(entry.key, entry.value);
    }
  }
}