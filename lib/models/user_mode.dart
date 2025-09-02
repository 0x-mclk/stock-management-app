enum UserMode {
  guest, // Hızlı başlangıç - sadece lokal
  basic, // Ücretsiz hesap - sınırlı cloud
  pro, // Ücretli - multi user
  proPlus // Premium - AI + unlimited
}

class UserSession {
  final String? userId;
  final String userName;
  final String? userEmail;
  final String storeName;
  final String? storeId; // Added store ID for Firebase operations
  final UserMode mode;
  final DateTime loginTime;
  final bool isOnline;
  final Map<String, dynamic> permissions;

  UserSession({
    this.userId,
    required this.userName,
    this.userEmail,
    required this.storeName,
    this.storeId,
    required this.mode,
    required this.loginTime,
    required this.isOnline,
    required this.permissions,
  });

  // Guest mode için
  factory UserSession.guest({
    required String userName,
    required String storeName,
    String? userEmail,
    String? storeId,
  }) {
    return UserSession(
      userId: null,
      userName: userName,
      userEmail: userEmail,
      storeName: storeName,
      storeId: storeId,
      mode: UserMode.guest,
      loginTime: DateTime.now(),
      isOnline: false,
      permissions: _getGuestPermissions(),
    );
  }

  // Registered user için
  factory UserSession.registered({
    required String userId,
    required String userName,
    required String userEmail,
    required String storeName,
    required UserMode mode,
    String? storeId,
  }) {
    return UserSession(
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      storeName: storeName,
      storeId: storeId,
      mode: mode,
      loginTime: DateTime.now(),
      isOnline: true,
      permissions: _getPermissionsForMode(mode),
    );
  }

  static Map<String, dynamic> _getGuestPermissions() {
    return {
      'canAddProducts': true,
      'canMakeSales': true,
      'canViewReports': true,
      'canManageSuppliers': false,
      'canAccessCloudSync': false,
      'canInviteUsers': false,
      'canExportData': false,
      'canUseAI': false,
      'maxProducts': 100,
      'maxSalesPerDay': 50,
    };
  }

  static Map<String, dynamic> _getPermissionsForMode(UserMode mode) {
    switch (mode) {
      case UserMode.basic:
        return {
          'canAddProducts': true,
          'canMakeSales': true,
          'canViewReports': true,
          'canManageSuppliers': true,
          'canAccessCloudSync': true,
          'canInviteUsers': false,
          'canExportData': true,
          'canUseAI': false,
          'maxProducts': 1000,
          'maxSalesPerDay': -1, // unlimited
        };
      case UserMode.pro:
        return {
          'canAddProducts': true,
          'canMakeSales': true,
          'canViewReports': true,
          'canManageSuppliers': true,
          'canAccessCloudSync': true,
          'canInviteUsers': true,
          'canExportData': true,
          'canUseAI': false,
          'maxProducts': -1, // unlimited
          'maxSalesPerDay': -1,
          'maxUsers': 3,
        };
      case UserMode.proPlus:
        return {
          'canAddProducts': true,
          'canMakeSales': true,
          'canViewReports': true,
          'canManageSuppliers': true,
          'canAccessCloudSync': true,
          'canInviteUsers': true,
          'canExportData': true,
          'canUseAI': true,
          'maxProducts': -1,
          'maxSalesPerDay': -1,
          'maxUsers': -1, // unlimited
        };
      default:
        return _getGuestPermissions();
    }
  }

  bool hasPermission(String permission) {
    return permissions[permission] == true;
  }

  int? getLimit(String limitKey) {
    final limit = permissions[limitKey];
    return limit == -1 ? null : limit;
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'storeName': storeName,
      'storeId': storeId,
      'mode': mode.name,
      'loginTime': loginTime.toIso8601String(),
      'isOnline': isOnline,
      'permissions': permissions,
    };
  }

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      userId: json['userId'],
      userName: json['userName'],
      userEmail: json['userEmail'],
      storeName: json['storeName'],
      storeId: json['storeId'],
      mode: UserMode.values.firstWhere((e) => e.name == json['mode']),
      loginTime: DateTime.parse(json['loginTime']),
      isOnline: json['isOnline'],
      permissions: Map<String, dynamic>.from(json['permissions']),
    );
  }
}




