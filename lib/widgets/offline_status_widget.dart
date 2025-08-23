import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';
import '../services/offline_service.dart';

class OfflineStatusWidget extends StatelessWidget {
  const OfflineStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConnectivityService, OfflineService>(
      builder: (context, connectivity, offline, child) {
        if (connectivity.isOnline && !offline.hasPendingOperations) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: connectivity.isOffline
              ? Colors.red.shade100
              : Colors.orange.shade100,
          child: Row(
            children: [
              Icon(
                connectivity.isOffline ? Icons.wifi_off : Icons.sync_problem,
                color: connectivity.isOffline
                    ? Colors.red.shade700
                    : Colors.orange.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  connectivity.isOffline
                      ? 'İnternet bağlantısı yok'
                      : '${offline.pendingOperationsCount} bekleyen işlem',
                  style: TextStyle(
                    color: connectivity.isOffline
                        ? Colors.red.shade700
                        : Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              if (offline.hasPendingOperations && connectivity.isOnline)
                TextButton(
                  onPressed: () => _showSyncDialog(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                  child: Text(
                    'Senkronize Et',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showSyncDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const SyncPendingOperationsDialog(),
    );
  }
}

class SyncPendingOperationsDialog extends StatefulWidget {
  const SyncPendingOperationsDialog({super.key});

  @override
  State<SyncPendingOperationsDialog> createState() =>
      _SyncPendingOperationsDialogState();
}

class _SyncPendingOperationsDialogState
    extends State<SyncPendingOperationsDialog> {
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineService>(
      builder: (context, offlineService, child) {
        final operations = offlineService.pendingOperations;
        final stats = offlineService.getOperationStats();

        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.sync, color: Colors.blue),
              SizedBox(width: 8),
              Text('Bekleyen İşlemler'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${operations.length} bekleyen işlem bulundu.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),

                // İstatistikler
                if (stats.isNotEmpty) ...[
                  const Text(
                    'İşlem Türleri:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ...stats.entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_getOperationTypeName(entry.key)),
                            Text('${entry.value} adet'),
                          ],
                        ),
                      )),
                  const SizedBox(height: 16),
                ],

                // Veri boyutu
                Text(
                  'Tahmini boyut: ${offlineService.getDataSizeEstimate()}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 16),

                // Son işlemler
                const Text(
                  'Son İşlemler:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: operations.length > 5 ? 5 : operations.length,
                    itemBuilder: (context, index) {
                      final operation =
                          operations[operations.length - 1 - index];
                      final timestamp = DateTime.parse(operation['timestamp']);

                      return ListTile(
                        dense: true,
                        leading: Icon(
                          _getOperationIcon(operation['type']),
                          size: 16,
                          color: Colors.blue,
                        ),
                        title: Text(
                          operation['description'],
                          style: const TextStyle(fontSize: 12),
                        ),
                        subtitle: Text(
                          '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isSyncing ? null : () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton.icon(
              onPressed: _isSyncing ? null : _syncOperations,
              icon: _isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label:
                  Text(_isSyncing ? 'Senkronize Ediliyor...' : 'Senkronize Et'),
            ),
          ],
        );
      },
    );
  }

  String _getOperationTypeName(String type) {
    switch (type) {
      case 'product_add':
        return 'Ürün Ekle';
      case 'product_update':
        return 'Ürün Güncelle';
      case 'product_delete':
        return 'Ürün Sil';
      case 'sale_add':
        return 'Satış';
      case 'supplier_add':
        return 'Tedarikçi Ekle';
      case 'supplier_update':
        return 'Tedarikçi Güncelle';
      default:
        return type;
    }
  }

  IconData _getOperationIcon(String type) {
    switch (type) {
      case 'product_add':
      case 'product_update':
        return Icons.inventory;
      case 'product_delete':
        return Icons.delete;
      case 'sale_add':
        return Icons.receipt;
      case 'supplier_add':
      case 'supplier_update':
        return Icons.business;
      default:
        return Icons.sync;
    }
  }

  Future<void> _syncOperations() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      final offlineService = context.read<OfflineService>();
      final success = await offlineService.syncPendingOperations();

      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tüm işlemler başarıyla senkronize edildi'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Senkronizasyon sırasında hata oluştu'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }
}
