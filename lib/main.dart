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

  // Inicializaciones mínimas que deben ocurrir ANTES de mostrar la UI:
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 8), onTimeout: () {
      logger.w('Firebase.initializeApp timeout, continuando en modo degradado.');
      throw TimeoutException('Firebase.initializeApp timeout');
    });
  } catch (e) {
    logger.e('Error inicializando Firebase: $e');
  }

  try {
    await HiveService.initHive()
        .timeout(const Duration(seconds: 5), onTimeout: () {
      logger.w('Hive init timeout; se intentará acceso lazy más tarde.');
      return;
    });
    logger.i('Hive inicializado');
  } catch (e) {
    debugPrint('❌ Error inicializando Hive (continuamos offline): $e');
  }

  // Mostramos la app lo antes posible; inicializaciones secundarias después.
  runApp(const AppDetection());

  // Inicializaciones que pueden ocurrir tras mostrar la UI (no bloquean arranque).
  unawaited(_postBootInit());
}

Future<void> _postBootInit() async {
  try {
    BackgroundCommService.init();
  } catch (e) {
    logger.w('BackgroundCommService init falló: $e');
  }

  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    logger.w('No se pudo registrar background handler FCM: $e');
  }

  try {
    await FcmService.instance.init().timeout(const Duration(seconds: 6), onTimeout: () {
      logger.w('FcmService init timeout, se reintentará manualmente más tarde.');
      return;
    });
    logger.i('FcmService inicializado');
  } catch (e) {
    logger.w('FcmService init falló: $e');
  }
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
