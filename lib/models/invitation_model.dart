import 'package:cloud_firestore/cloud_firestore.dart';

enum InvitationStatus { invited, accepted, rejected, pending, owner, approved }

enum UserRole { owner, manager, staff, partner }

class InvitationModel {
  final String? id;
  final String userId;
  final String email;
  final String storeId;
  final String? storeName;
  final UserRole role;
  final List<String> permissions;
  final InvitationStatus status;
  final DateTime? joinedAt;
  final DateTime invitedAt;
  final String? invitedBy;
  final DateTime? respondedAt;
  final DateTime? lastActivity;
  final bool isActive;

  // Yeni alanlar - Admin onaylama sistemi için
  final bool emailSent;
  final bool adminApprovalRequired;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectedBy;
  final DateTime? rejectedAt;
  final String? rejectionReason;

  InvitationModel({
    this.id,
    required this.userId,
    required this.email,
    required this.storeId,
    this.storeName,
    required this.role,
    required this.permissions,
    required this.status,
    this.joinedAt,
    required this.invitedAt,
    this.invitedBy,
    this.respondedAt,
    this.lastActivity,
    this.isActive = true,
    this.emailSent = false,
    this.adminApprovalRequired = false,
    this.approvedBy,
    this.approvedAt,
    this.rejectedBy,
    this.rejectedAt,
    this.rejectionReason,
  });

  /// Convert from Firestore document
  factory InvitationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return InvitationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      email: data['email'] ?? '',
      storeId: data['storeId'] ?? '',
      storeName: data['storeName'],
      role: UserRole.values.firstWhere(
        (r) => r.toString().split('.').last == data['role'],
        orElse: () => UserRole.staff,
      ),
      permissions: List<String>.from(data['permissions'] ?? []),
      status: InvitationStatus.values.firstWhere(
        (s) => s.toString().split('.').last == data['status'],
        orElse: () => InvitationStatus.pending,
      ),
      joinedAt: data['joinedAt']?.toDate(),
      invitedAt: data['invitedAt']?.toDate() ?? DateTime.now(),
      invitedBy: data['invitedBy'],
      respondedAt: data['respondedAt']?.toDate(),
      lastActivity: data['lastActivity']?.toDate(),
      isActive: data['isActive'] ?? true,
      // Yeni alanlar
      emailSent: data['emailSent'] ?? false,
      adminApprovalRequired: data['adminApprovalRequired'] ?? false,
      approvedBy: data['approvedBy'],
      approvedAt: data['approvedAt']?.toDate(),
      rejectedBy: data['rejectedBy'],
      rejectedAt: data['rejectedAt']?.toDate(),
      rejectionReason: data['rejectionReason'],
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'email': email,
      'storeId': storeId,
      'storeName': storeName,
      'role': role.toString().split('.').last,
      'permissions': permissions,
      'status': status.toString().split('.').last,
      'joinedAt': joinedAt != null ? Timestamp.fromDate(joinedAt!) : null,
      'invitedAt': Timestamp.fromDate(invitedAt),
      'invitedBy': invitedBy,
      'respondedAt':
          respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'lastActivity':
          lastActivity != null ? Timestamp.fromDate(lastActivity!) : null,
      'isActive': isActive,
      // Yeni alanlar
      'emailSent': emailSent,
      'adminApprovalRequired': adminApprovalRequired,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'rejectedBy': rejectedBy,
      'rejectedAt': rejectedAt != null ? Timestamp.fromDate(rejectedAt!) : null,
      'rejectionReason': rejectionReason,
    };
  }

  /// Copy with new values
  InvitationModel copyWith({
    String? id,
    String? userId,
    String? email,
    String? storeId,
    String? storeName,
    UserRole? role,
    List<String>? permissions,
    InvitationStatus? status,
    DateTime? joinedAt,
    DateTime? invitedAt,
    String? invitedBy,
    DateTime? respondedAt,
    DateTime? lastActivity,
    bool? isActive,
    bool? emailSent,
    bool? adminApprovalRequired,
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectedBy,
    DateTime? rejectedAt,
    String? rejectionReason,
  }) {
    return InvitationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      status: status ?? this.status,
      joinedAt: joinedAt ?? this.joinedAt,
      invitedAt: invitedAt ?? this.invitedAt,
      invitedBy: invitedBy ?? this.invitedBy,
      respondedAt: respondedAt ?? this.respondedAt,
      lastActivity: lastActivity ?? this.lastActivity,
      isActive: isActive ?? this.isActive,
      emailSent: emailSent ?? this.emailSent,
      adminApprovalRequired:
          adminApprovalRequired ?? this.adminApprovalRequired,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  /// Get default permissions for role
  static List<String> getDefaultPermissions(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return ['read', 'write', 'delete', 'admin', 'invite', 'manage_users'];
      case UserRole.manager:
        return ['read', 'write', 'delete', 'invite'];
      case UserRole.staff:
        return ['read', 'write'];
      case UserRole.partner:
        return ['read', 'write', 'limited_delete'];
    }
  }

  /// Check if user has specific permission
  bool hasPermission(String permission) {
    return permissions.contains(permission) ||
        (role == UserRole.owner && permission != 'admin');
  }

  /// Get role display name
  String get roleDisplayName {
    switch (role) {
      case UserRole.owner:
        return 'Mağaza Sahibi';
      case UserRole.manager:
        return 'Müdür';
      case UserRole.staff:
        return 'Personel';
      case UserRole.partner:
        return 'Ortak';
    }
  }

  /// Get status display name
  String get statusDisplayName {
    switch (status) {
      case InvitationStatus.owner:
        return 'Sahip';
      case InvitationStatus.accepted:
        return 'Kabul Edildi';
      case InvitationStatus.invited:
        return 'Davet Edildi';
      case InvitationStatus.pending:
        return 'Bekliyor';
      case InvitationStatus.approved:
        return 'Onaylandı';
      case InvitationStatus.rejected:
        return 'Reddedildi';
    }
  }

  @override
  String toString() {
    return 'InvitationModel(id: $id, email: $email, role: $role, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InvitationModel &&
        other.id == id &&
        other.userId == userId &&
        other.email == email &&
        other.storeId == storeId;
  }

  @override
  int get hashCode {
    return id.hashCode ^ userId.hashCode ^ email.hashCode ^ storeId.hashCode;
  }
}
