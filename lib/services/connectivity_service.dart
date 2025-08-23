import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  bool _isOnline = true;
  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;

  ConnectivityResult _connectionStatus = ConnectivityResult.none;
  ConnectivityResult get connectionStatus => _connectionStatus;

  final Connectivity _connectivity = Connectivity();

  void initialize() {
    _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    try {
      final ConnectivityResult result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      _setConnectionStatus(ConnectivityResult.none);
    }
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    _connectionStatus = result;
    _checkInternetConnection();
  }

  Future<void> _checkInternetConnection() async {
    bool isConnected = false;
    
    try {
      if (_connectionStatus != ConnectivityResult.none) {
        final result = await InternetAddress.lookup('google.com');
        isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      }
    } catch (e) {
      isConnected = false;
    }

    _setConnectionStatus(isConnected ? _connectionStatus : ConnectivityResult.none);
  }

  void _setConnectionStatus(ConnectivityResult status) {
    final wasOnline = _isOnline;
    _isOnline = status != ConnectivityResult.none;
    
    if (wasOnline != _isOnline) {
      notifyListeners();
    }
  }

  String getConnectionStatusText() {
    switch (_connectionStatus) {
      case ConnectivityResult.mobile:
        return 'Mobil Veri';
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.other:
        return 'Diğer';
      case ConnectivityResult.none:
        return 'Bağlantı Yok';
    }
  }

  IconData getConnectionIcon() {
    switch (_connectionStatus) {
      case ConnectivityResult.mobile:
        return Icons.signal_cellular_4_bar;
      case ConnectivityResult.wifi:
        return Icons.wifi;
      case ConnectivityResult.ethernet:
        return Icons.cable;
      case ConnectivityResult.bluetooth:
        return Icons.bluetooth;
      case ConnectivityResult.vpn:
        return Icons.vpn_key;
      case ConnectivityResult.other:
        return Icons.device_unknown;
      case ConnectivityResult.none:
        return Icons.wifi_off;
    }
  }

  Color getConnectionColor() {
    return _isOnline ? Colors.green : Colors.red;
  }
}
