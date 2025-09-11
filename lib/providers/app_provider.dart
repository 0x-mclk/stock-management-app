import 'package:flutter/material.dart';
import '../services/firebase_auth_service.dart';
import '../services/firebase_sync_service.dart';
import '../services/store_selection_service.dart';
import '../models/user_mode.dart';

class AppProvider extends ChangeNotifier {
  int _currentPageIndex = 0;
  bool _isOffline = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _syncError;

  final FirebaseAuthService _authService = FirebaseAuthService.instance;
  final FirebaseSyncService _syncService = FirebaseSyncService();

  int get currentPageIndex => _currentPageIndex;
  bool get isOffline => _isOffline;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get syncError => _syncError;
  bool get isLoggedIn => _authService.currentUser != null;

  void setCurrentPage(int index) {
    _currentPageIndex = index;
    notifyListeners();
  }

  void setOfflineStatus(bool status) {
    _isOffline = status;
    notifyListeners();
  }

  void clearSyncError() {
    _syncError = null;
    notifyListeners();
  }

  // Firebase Auth methods
  Future<bool> signInWithEmailPassword(String email, String password) async {
    try {
      _syncError = null;
      final result = await _authService.signInWithEmailPassword(
        email: email,
        password: password,
      );

      if (result.success) {
        // Initialize store selection after successful login
        await StoreSelectionService.instance.initializeAfterLogin();

        // Setup auto-sync after successful login
        _syncService.setupAutoSync();

        // Perform initial sync
        await performSync();

        notifyListeners();
        return true;
      } else {
        _syncError = result.message ?? 'Giriş yapılamadı';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _syncError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> registerWithEmailPassword({
    required String name,
    required String email,
    required String password,
    required String storeName,
  }) async {
    try {
      _syncError = null;
      final result = await _authService.registerWithEmailPassword(
        name: name,
        email: email,
        password: password,
        storeName: storeName,
        mode: UserMode.basic,
      );

      if (result.success) {
        // Initialize store selection after successful registration
        await StoreSelectionService.instance.initializeAfterLogin();

        // Setup auto-sync after successful registration
        _syncService.setupAutoSync();
        notifyListeners();
        return true;
      } else {
        _syncError = result.message ?? 'Kayıt oluşturulamadı';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _syncError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      // Clear store selection cache before signing out
      await StoreSelectionService.instance.clearCache();
      await _authService.signOut();
      _lastSyncTime = null;
      _syncError = null;
      notifyListeners();
    } catch (e) {
      _syncError = e.toString();
      notifyListeners();
    }
  }

  // Sync methods
  Future<void> performSync() async {
    if (_isSyncing || _isOffline) return;

    _isSyncing = true;
    _syncError = null;
    notifyListeners();

    try {
      await _syncService.performFullSync();
      _lastSyncTime = DateTime.now();
    } catch (e) {
      _syncError = e.toString();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> syncToCloud() async {
    if (_isSyncing || _isOffline) return;

    _isSyncing = true;
    _syncError = null;
    notifyListeners();

    try {
      await _syncService.syncToFirebase();
      _lastSyncTime = DateTime.now();
    } catch (e) {
      _syncError = e.toString();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> syncFromCloud() async {
    if (_isSyncing || _isOffline) return;

    _isSyncing = true;
    _syncError = null;
    notifyListeners();

    try {
      await _syncService.syncFromFirebase();
      _lastSyncTime = DateTime.now();
    } catch (e) {
      _syncError = e.toString();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // Get sync status for UI
  Map<String, dynamic> getSyncStatus() {
    return {
      'isSyncing': _isSyncing,
      'isOffline': _isOffline,
      'lastSyncTime': _lastSyncTime,
      'syncError': _syncError,
      'isLoggedIn': isLoggedIn,
    };
  }
}
