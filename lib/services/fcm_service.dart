import 'dart:isolate';
import 'dart:ui';
import 'package:app_g/models/alerta_model.dart';
import 'package:app_g/models/evento_model.dart';
import 'package:app_g/services/hive_service.dart';
import 'package:app_g/utils/logger.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) await Firebase.initializeApp();

  logger.i('📩 Background FCM recibido: ${message.from} => ${message.data}');
  final SendPort? port = IsolateNameServer.lookupPortByName('main_port');

  if (port != null) {
    logger.i('🔁 Enviando data y topic al main isolate...');
    port.send({
      'from': message.from,
      'data': message.data,
    });
  } else {
    await HiveService.initHive();
    final from = message.from ?? '';
    final data = message.data;

    if (from.contains('alertas')) {
      final alerta = AlertaModel(
        idAlerta: data['_id_alerta'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        idCamara: data['_id_camara'] ?? '',
        timestamp: DateTime.tryParse(data['_timestamp'] ?? '') ?? DateTime.now(),
        img: data['img'] ?? '',
        score: double.tryParse(data['score'] ?? '0') ?? 0,
        longitud: double.tryParse(data['longitud'] ?? '0') ?? 0,
        latitud: double.tryParse(data['latitud'] ?? '0') ?? 0,
      );

      final evento = EventoModel(
        alerta: alerta,
        distancia: -1, // se calculará al iniciar app
        timestamp: DateTime.now(),
      );

      await HiveService.addEvento(evento, HiveService.eventosPendientesBox);
      logger.i('✅ Alerta guardada en Hive desde background.');
    } else if (from.contains('ack')) {
      final idAlerta = data['id_alerta_act'] ?? '';
      if (idAlerta.isNotEmpty) {
        await HiveService.deleteEvento(idAlerta, HiveService.eventosPendientesBox);
        await HiveService.deleteEvento(idAlerta, HiveService.eventoBox);
        logger.i('🗑️ Evento con idAlerta $idAlerta eliminado por ACK desde background.');
      }
    }
    
    logger.w('⚠️ main_port no encontrado, la app no está en memoria.');
  }
}

class FcmService {
  FcmService._();
  static final instance = FcmService._();

  Future<void> init() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await FirebaseMessaging.instance.subscribeToTopic('alertas');
    await FirebaseMessaging.instance.subscribeToTopic('ack');

    FirebaseMessaging.onMessage.listen((message) {
      logger.i('📲 Foreground FCM: ${message.from} => ${message.data}');
      _sendToMain(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      logger.i('🟢 FCM OpenedApp: ${message.from} => ${message.data}');
      _sendToMain(message);
    });
  }

  void _sendToMain(RemoteMessage message) {
    final SendPort? port = IsolateNameServer.lookupPortByName('main_port');
    if (port != null) {
      port.send({
        'from': message.from,
        'data': message.data,
      });
    } else {
      logger.w('⚠️ main_port no encontrado en foreground.');
    }
  }
}
