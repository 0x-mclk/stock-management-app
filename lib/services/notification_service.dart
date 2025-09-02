class NotificationService {
  static Future<void> initialize() async {
    // Notification service initialization
    // Will be implemented with proper package when needed
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    // Notification implementation
    // // Debug print removed // Removed for production
  }

  static Future<void> showLowStockNotification(String productName, int stock) async {
    await showNotification(
      id: 1,
      title: 'Düşük Stok Uyarısı',
      body: '$productName ürününde sadece $stock adet kalmıştır.',
    );
  }

  static Future<void> showDebtNotification(String customerName, double debt) async {
    await showNotification(
      id: 2,
      title: 'Borç Hatırlatıcısı',
      body: '$customerName müşterisinin ₺${debt.toStringAsFixed(2)} borcu bulunmaktadır.',
    );
  }
}




