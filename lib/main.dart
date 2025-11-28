import 'dart:async';
import 'package:app_g/screens/load_screen.dart';
import 'package:app_g/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:app_g/services/hive_service.dart';
import 'package:app_g/services/fcm_service.dart';
import 'package:app_g/services/background_comm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  await  HiveService.initHive().then((_) {
    logger.i('Hive inicializado');
  }).catchError((e, st) {
    debugPrint('❌ Error inicializando Hive: $e');
  });
  
  BackgroundCommService.init();

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await FcmService.instance.init();

  runApp(const AppDetection());
}

class AppDetection extends StatelessWidget {
  const AppDetection({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GuardIA',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const LoadingGate(),
    );
  }
}
