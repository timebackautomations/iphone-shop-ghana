import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

// ============================================
// SALES LINE CHART - SIMPLIFIED
// ============================================
class SalesChart extends StatefulWidget {
  final Map<String, dynamic> salesData;
  final String title;
  
  const SalesChart({
    super.key,
    required this.salesData,
    required this.title,
  });

  @override
  State<SalesChart> createState() => _SalesChartState();
}

class _SalesChartState extends State<SalesChart> {
  @override
  Widget build(BuildContext context) {
    final spots = _getSpots();
    if (spots.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade200,
                        strokeWidth: 1,
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade200,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && 
                              value.toInt() < widget.salesData['labels'].length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                widget.salesData['labels'][value.toInt()],
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '₵${value.toInt()}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  minX: 0,
                  maxX: spots.length.toDouble() - 1,
                  minY: 0,
                  maxY: _getMaxY(),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _getSpots() {
    final sales = widget.salesData['sales'] as List<dynamic>?;
    if (sales == null || sales.isEmpty) return [];
    
    return List.generate(sales.length, (i) {
      final value = sales[i] is int 
          ? (sales[i] as int).toDouble() 
          : (sales[i] as num).toDouble();
      return FlSpot(i.toDouble(), value);
    });
  }

  double _getMaxY() {
    final sales = widget.salesData['sales'] as List<dynamic>?;
    if (sales == null || sales.isEmpty) return 10;
    
    final maxValue = sales.map((e) => e is int ? e.toDouble() : (e as num).toDouble())
        .reduce((a, b) => a > b ? a : b);
    return (maxValue * 1.2).ceilToDouble();
  }
}

// ============================================
// TOP PRODUCTS BAR CHART - SIMPLIFIED
// ============================================
class TopProductsChart extends StatelessWidget {
  final List<Map<String, dynamic>> topProducts;
  
  const TopProductsChart({super.key, required this.topProducts});

  @override
  Widget build(BuildContext context) {
    if (topProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Selling Models',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _getMaxCount().toDouble(),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < topProducts.length) {
                            String model = topProducts[value.toInt()]['model'];
                            if (model.length > 8) {
                              model = '${model.substring(0, 6)}...';
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                model,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 10,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: false,
                  ),
                  barGroups: List.generate(topProducts.length, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: topProducts[i]['count'].toDouble(),
                          color: Colors.blue,
                          width: 20,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getMaxCount() {
    if (topProducts.isEmpty) return 5;
    final maxCount = topProducts.map((p) => p['count'] as int).reduce((a, b) => a > b ? a : b);
    return maxCount + 1;
  }
}

// ============================================
// PAYMENT METHODS PIE CHART - SIMPLIFIED
// ============================================
class PaymentPieChart extends StatelessWidget {
  final Map<String, int> paymentData;
  
  const PaymentPieChart({super.key, required this.paymentData});

  @override
  Widget build(BuildContext context) {
    if (paymentData.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
    ];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Methods',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: SizedBox(
                    height: 150,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: _getSections(colors),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: paymentData.entries.map((entry) {
                      final index = paymentData.keys.toList().indexOf(entry.key);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: colors[index % colors.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.key,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Text(
                              '${entry.value}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _getSections(List<Color> colors) {
    int index = 0;
    
    return paymentData.entries.map((entry) {
      final section = PieChartSectionData(
        value: entry.value.toDouble(),
        title: '',
        color: colors[index % colors.length],
        radius: 60,
      );
      index++;
      return section;
    }).toList();
  }
}

// ============================================
// RECENT SALES LIST
// ============================================
class RecentSalesList extends StatelessWidget {
  final List<Map<String, dynamic>> sales;
  
  const RecentSalesList({super.key, required this.sales});

  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Sales',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to sales history
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...sales.take(5).map((sale) {
              final inventory = sale['inventory_items'] ?? {};
              final product = inventory['products'] ?? {};
              final date = DateTime.parse(sale['sold_at']);
              
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.green.shade100,
                  child: const Icon(Icons.check, color: Colors.green, size: 14),
                ),
                title: Text(
                  product['model'] ?? 'iPhone',
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  DateFormat('MMM dd, HH:mm').format(date),
                  style: const TextStyle(fontSize: 10),
                ),
                trailing: Text(
                  '₵${sale['price_ghs']?.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}