import 'package:flutter/material.dart';

class AppProvider extends ChangeNotifier {
  int _currentPageIndex = 0;
  bool _isOffline = false;

  int get currentPageIndex => _currentPageIndex;
  bool get isOffline => _isOffline;

  void setCurrentPage(int index) {
    _currentPageIndex = index;
    notifyListeners();
  }

  void setOfflineStatus(bool status) {
    _isOffline = status;
    notifyListeners();
  }
}




