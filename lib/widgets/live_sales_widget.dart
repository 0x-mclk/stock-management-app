import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sales_provider.dart';
import '../utils/currency_formatter.dart';

class LiveSalesWidget extends StatefulWidget {
  const LiveSalesWidget({super.key});

  @override
  State<LiveSalesWidget> createState() => _LiveSalesWidgetState();
}

class _LiveSalesWidgetState extends State<LiveSalesWidget> {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.trending_up,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Anlık Satış Durumu',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Consumer<SalesProvider>(
              builder: (context, salesProvider, child) {
                final sales = salesProvider.sales;
                final today = DateTime.now();
                final todaySales = sales.where((sale) {
                  return sale.createdAt.year == today.year &&
                         sale.createdAt.month == today.month &&
                         sale.createdAt.day == today.day;
                }).toList();

                final todayTotal = todaySales.fold<double>(
                  0,
                  (sum, sale) => sum + sale.totalAmount,
                );

                final thisMonth = sales.where((sale) {
                  return sale.createdAt.year == today.year &&
                         sale.createdAt.month == today.month;
                }).toList();

                final monthlyTotal = thisMonth.fold<double>(
                  0,
                  (sum, sale) => sum + sale.totalAmount,
                );

                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMetricCard(
                          'Günlük Satış',
                          todaySales.length.toString(),
                          Icons.today,
                          Colors.blue,
                        ),
                        _buildMetricCard(
                          'Günlük Ciro',
                          CurrencyFormatter.format(todayTotal),
                          Icons.monetization_on,
                          Colors.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMetricCard(
                          'Aylık Satış',
                          thisMonth.length.toString(),
                          Icons.calendar_month,
                          Colors.purple,
                        ),
                        _buildMetricCard(
                          'Aylık Ciro',
                          CurrencyFormatter.format(monthlyTotal),
                          Icons.trending_up,
                          Colors.orange,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 14,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
