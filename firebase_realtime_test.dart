import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase'i başlat
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('🔥 Firebase initialized successfully');

  // Test store ID
  String testStoreId = 'default_store';

  // Firestore referansı
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  print('🚀 Testing Firebase real-time updates...');

  // Real-time stream dinleyicisini başlat
  firestore
      .collection('stores')
      .doc(testStoreId)
      .collection('products')
      .where('isActive', isEqualTo: true)
      .orderBy('name')
      .snapshots()
      .listen((snapshot) {
    print('🔥 REAL-TIME UPDATE RECEIVED!');
    print('📊 Products count: ${snapshot.docs.length}');

    for (var doc in snapshot.docs) {
      var data = doc.data();
      print(
          '   - ${data['name']} | Stock: ${data['stock']} | Price: ${data['salePrice']}');
    }

    print('✅ Real-time update processed successfully');
  }).onError((error) {
    print('❌ Firebase stream error: $error');
  });

  print(
      '🎯 Stream listener started. Now try updating a product in Firebase console...');
  print(
      '🔗 Firebase Console: https://console.firebase.google.com/project/stockpro-multi-store/firestore');
  print('📍 Collection path: stores/$testStoreId/products');

  // Test için basit bir HTTP endpoint dinleyicisi (simüle edilmiş)
  print('\n⏳ Waiting for Firebase updates...');

  // Sonsuz döngü ile programı açık tut
  while (true) {
    await Future.delayed(Duration(seconds: 10));
    print('💓 Still listening for Firebase updates...');
  }
}
