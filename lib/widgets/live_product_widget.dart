import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../models/product.dart';
import '../utils/currency_formatter.dart';

class LiveProductWidget extends StatefulWidget {
  const LiveProductWidget({super.key});

  @override
  State<LiveProductWidget> createState() => _LiveProductWidgetState();
}

class _LiveProductWidgetState extends State<LiveProductWidget> {
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
                  Icons.inventory_2,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Anlık Ürün Durumu',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Consumer<ProductProvider>(
              builder: (context, productProvider, child) {
                final products = productProvider.products;
                final lowStockProducts = products.where((p) => p.stock < 10).toList();
                final totalValue = products.fold<double>(
                  0,
                  (sum, product) => sum + (product.salePrice * product.stock),
                );

                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMetricCard(
                          'Toplam Ürün',
                          products.length.toString(),
                          Icons.inventory,
                          Colors.blue,
                        ),
                        _buildMetricCard(
                          'Düşük Stok',
                          lowStockProducts.length.toString(),
                          Icons.warning,
                          Colors.orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMetricCard(
                          'Toplam Değer',
                          CurrencyFormatter.format(totalValue),
                          Icons.monetization_on,
                          Colors.green,
                        ),
                        _buildMetricCard(
                          'Son Güncelleme',
                          _getLastUpdate(),
                          Icons.access_time,
                          Colors.grey,
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

  String _getLastUpdate() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}
