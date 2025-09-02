import 'package:flutter/material.dart';
import '../models/invitation_model.dart';
import '../services/invitation_service.dart';

class PermissionService {
  final InvitationService _invitationService = InvitationService.instance;

  // Singleton pattern
  static PermissionService? _instance;
  static PermissionService get instance => _instance ??= PermissionService._();
  PermissionService._();

  /// Check if user has permission for specific action
  Future<bool> hasPermission({
    required String storeId,
    required String userId,
    required String permission,
  }) async {
    try {
      final membership = await _invitationService.getUserMembership(
        storeId: storeId,
        userId: userId,
      );

      if (membership == null) return false;

      return membership.hasPermission(permission);
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Check if user can read data
  Future<bool> canRead({
    required String storeId,
    required String userId,
  }) async {
    return await hasPermission(
      storeId: storeId,
      userId: userId,
      permission: 'read',
    );
  }

  /// Check if user can write/edit data
  Future<bool> canWrite({
    required String storeId,
    required String userId,
  }) async {
    return await hasPermission(
      storeId: storeId,
      userId: userId,
      permission: 'write',
    );
  }

  /// Check if user can delete data
  Future<bool> canDelete({
    required String storeId,
    required String userId,
  }) async {
    return await hasPermission(
      storeId: storeId,
      userId: userId,
      permission: 'delete',
    );
  }

  /// Check if user can invite other members
  Future<bool> canInvite({
    required String storeId,
    required String userId,
  }) async {
    return await hasPermission(
      storeId: storeId,
      userId: userId,
      permission: 'invite',
    );
  }

  /// Check if user can manage other users
  Future<bool> canManageUsers({
    required String storeId,
    required String userId,
  }) async {
    return await hasPermission(
      storeId: storeId,
      userId: userId,
      permission: 'manage_users',
    );
  }

  /// Check if user has admin permissions
  Future<bool> isAdmin({
    required String storeId,
    required String userId,
  }) async {
    return await hasPermission(
      storeId: storeId,
      userId: userId,
      permission: 'admin',
    );
  }

  /// Check if user is owner of the store
  Future<bool> isOwner({
    required String storeId,
    required String userId,
  }) async {
    try {
      final membership = await _invitationService.getUserMembership(
        storeId: storeId,
        userId: userId,
      );

      return membership?.role == UserRole.owner;
    } catch (e) {
      // Debug print removed
      return false;
    }
  }

  /// Get user's role in store
  Future<UserRole?> getUserRole({
    required String storeId,
    required String userId,
  }) async {
    try {
      final membership = await _invitationService.getUserMembership(
        storeId: storeId,
        userId: userId,
      );

      return membership?.role;
    } catch (e) {
      // Debug print removed
      return null;
    }
  }

  /// Get user's permissions in store
  Future<List<String>> getUserPermissions({
    required String storeId,
    required String userId,
  }) async {
    try {
      final membership = await _invitationService.getUserMembership(
        storeId: storeId,
        userId: userId,
      );

      return membership?.permissions ?? [];
    } catch (e) {
      // Debug print removed
      return [];
    }
  }

  /// Validate if user can perform action, show error if not
  Future<bool> validateAndShowError({
    required BuildContext context,
    required String storeId,
    required String userId,
    required String permission,
    String? customErrorMessage,
  }) async {
    final hasPermission = await this.hasPermission(
      storeId: storeId,
      userId: userId,
      permission: permission,
    );

    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            customErrorMessage ?? 'Bu işlem için yetkiniz bulunmuyor',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    return hasPermission;
  }

  /// Check multiple permissions at once
  Future<Map<String, bool>> checkMultiplePermissions({
    required String storeId,
    required String userId,
    required List<String> permissions,
  }) async {
    final results = <String, bool>{};

    for (final permission in permissions) {
      results[permission] = await hasPermission(
        storeId: storeId,
        userId: userId,
        permission: permission,
      );
    }

    return results;
  }

  /// Get permission description for UI
  String getPermissionDescription(String permission) {
    switch (permission) {
      case 'read':
        return 'Verileri görüntüleme';
      case 'write':
        return 'Veri ekleme ve düzenleme';
      case 'delete':
        return 'Veri silme';
      case 'invite':
        return 'Takım üyesi davet etme';
      case 'manage_users':
        return 'Kullanıcı yönetimi';
      case 'admin':
        return 'Yönetici yetkisi';
      case 'limited_delete':
        return 'Sınırlı silme yetkisi';
      default:
        return permission;
    }
  }

  /// Get role-based feature restrictions
  Future<Map<String, bool>> getFeatureAccess({
    required String storeId,
    required String userId,
  }) async {
    final role = await getUserRole(storeId: storeId, userId: userId);

    if (role == null) {
      return {
        'products': false,
        'sales': false,
        'reports': false,
        'suppliers': false,
        'team_management': false,
        'store_settings': false,
      };
    }

    switch (role) {
      case UserRole.owner:
        return {
          'products': true,
          'sales': true,
          'reports': true,
          'suppliers': true,
          'team_management': true,
          'store_settings': true,
        };

      case UserRole.manager:
        return {
          'products': true,
          'sales': true,
          'reports': true,
          'suppliers': true,
          'team_management': true,
          'store_settings': false,
        };

      case UserRole.staff:
        return {
          'products': true,
          'sales': true,
          'reports': false,
          'suppliers': false,
          'team_management': false,
          'store_settings': false,
        };

      case UserRole.partner:
        return {
          'products': true,
          'sales': true,
          'reports': true,
          'suppliers': false,
          'team_management': false,
          'store_settings': false,
        };
    }
  }

  /// Widget wrapper for permission-based UI
  Widget buildPermissionWrapper({
    required String storeId,
    required String userId,
    required String permission,
    required Widget child,
    Widget? fallbackWidget,
  }) {
    return FutureBuilder<bool>(
      future: hasPermission(
        storeId: storeId,
        userId: userId,
        permission: permission,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final hasPermission = snapshot.data ?? false;

        if (hasPermission) {
          return child;
        } else {
          return fallbackWidget ?? SizedBox.shrink();
        }
      },
    );
  }

  /// Permission-based navigation guard
  Future<bool> canNavigateTo({
    required String storeId,
    required String userId,
    required String routeName,
  }) async {
    final featureAccess = await getFeatureAccess(
      storeId: storeId,
      userId: userId,
    );

    switch (routeName) {
      case '/products':
        return featureAccess['products'] ?? false;
      case '/sales':
        return featureAccess['sales'] ?? false;
      case '/reports':
        return featureAccess['reports'] ?? false;
      case '/suppliers':
        return featureAccess['suppliers'] ?? false;
      case '/team':
        return featureAccess['team_management'] ?? false;
      case '/settings':
        return featureAccess['store_settings'] ?? false;
      default:
        return true;
    }
  }
}




