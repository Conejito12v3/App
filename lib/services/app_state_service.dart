import 'dart:async';
import 'package:app_g/utils/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:location/location.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:app_g/services/socketio_service.dart';

enum AppStatus {
  loading,
  ok,
  noInternet,
  noLocation,
  apiDown,
  noTopic
}

class AppStateService {
  static final AppStateService instance = AppStateService._();
  AppStateService._();

  final _controller = StreamController<AppStatus>.broadcast();
  Stream<AppStatus> get stream => _controller.stream;
  bool _initializing = false;
  StreamSubscription? _autoRetryConnectivitySub;

  void dispose() {
    _autoRetryConnectivitySub?.cancel();
    _autoRetryConnectivitySub = null;
  }

  Future<void> initialize({bool force = false}) async {
    if (_initializing && !force) return; // evitar carreras salvo fuerza manual
    // Si es un reintento manual, cancelar cualquier suscripción auto y resetear estado
    if (force) {
      _autoRetryConnectivitySub?.cancel();
      _autoRetryConnectivitySub = null;
    }
    _initializing = true;
    _controller.add(AppStatus.loading);

    // Inicializar escucha de conectividad para reintentos de socket.
    SocketioService.initRetries();

    logger.i('Inicio initialize (force=$force)');
    // Chequeo rápido de internet para mostrar error inmediato si no hay red
    final quickStatus = await Connectivity().checkConnectivity();
    if (quickStatus == ConnectivityResult.none) {
      logger.w('Sin internet (chequeo rápido), mostrando estado noInternet');
      _controller.add(AppStatus.noInternet);
      // Suscribir reintento automático cuando vuelva internet
      _autoRetryConnectivitySub ??= Connectivity()
          .onConnectivityChanged
          .listen((r) async {
        if (r != ConnectivityResult.none) {
          _autoRetryConnectivitySub?.cancel();
          _autoRetryConnectivitySub = null;
          await initialize();
        }
      });
      _initializing = false;
      return;
    }

    final internetOk = await _retryConnectivity(attempts: 3);
    if (!internetOk) {
      logger.w('Sin internet tras reintentos, mostrando estado noInternet');
      _controller.add(AppStatus.noInternet);
      // suscribir para relanzar initialize automáticamente cuando vuelva internet
      _autoRetryConnectivitySub ??= Connectivity()
          .onConnectivityChanged
          .listen((r) async {
        if (r != ConnectivityResult.none) {
          _autoRetryConnectivitySub?.cancel();
          _autoRetryConnectivitySub = null;
          await initialize();
        }
      });
      _initializing = false;
      return;
    }

    logger.i('Chequeando GPS');
    final gpsOk = await _retryLocation(attempts: 2);
    if (!gpsOk) {
      logger.w('GPS no disponible, se continúa sin bloquear la app');
      // No bloqueamos ingreso; algunas funciones pueden requerir GPS más tarde.
    }

    logger.i('Ping al backend vía socket');
    // Guardia adicional: si en este punto se perdió la conectividad, no intentamos ping
    final netStatusBeforePing = await Connectivity().checkConnectivity();
    if (netStatusBeforePing == ConnectivityResult.none) {
      logger.w('Conectividad perdida antes del ping, mostrando noInternet');
      _controller.add(AppStatus.noInternet);
      _initializing = false;
      return;
    }

    final apiOk = await _checkApiConnection();
    if (!apiOk) {
      // Si el ping falló por error de DNS/timeout, priorizamos noInternet
      final status = await Connectivity().checkConnectivity();
      final pingErr = SocketioService.lastPingError?.toLowerCase() ?? '';
      final looksOffline = status == ConnectivityResult.none ||
          pingErr.contains('failed host lookup') ||
          pingErr.contains('no address associated with hostname') ||
          pingErr.contains('timeout');
      if (looksOffline) {
        logger.w('Ping fallido por falta de conectividad (err="$pingErr"), mostrando noInternet');
        _controller.add(AppStatus.noInternet);
      } else {
        logger.e('Backend no accesible');
        _controller.add(AppStatus.apiDown);
      }
      _initializing = false;
      return;
    }

    logger.i('Intentando suscripción a topics');
    final topicsOk = await _retryTopics(attempts: 3);
    if (!topicsOk) {
      // No bloqueamos el ingreso si falla la suscripción a topics;
      // lo intentamos en segundo plano para no impedir uso de la app.
      logger.w('Suscripción a topics fallida; continuando y reintentando en background');
      // Reintento diferido
      unawaited(_retryTopics(attempts: 3));
    }

    logger.i('Estado OK emitido');
    _controller.add(AppStatus.ok);
    _initializing = false;
  }

  Future<bool> _checkApiConnection() async {
    try {
      final ok = await SocketioService.ping();
      logger.i('Resultado ping backend: $ok');
      return ok;
    } catch (e) {
      logger.e('Excepción en ping backend: $e');
      return false;
    }
  }

  Future<bool> _checkTopics() async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic('alertas');
      await FirebaseMessaging.instance.subscribeToTopic('ack');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _retryConnectivity({int attempts = 3, Duration baseDelay = const Duration(seconds: 1)}) async {
    for (int a = 1; a <= attempts; a++) {
      final status = await Connectivity().checkConnectivity();
      if (status != ConnectivityResult.none) return true;
      if (a < attempts) {
        await Future.delayed(baseDelay * a);
      }
    }
    return false;
  }

  Future<bool> _retryLocation({int attempts = 2, Duration baseDelay = const Duration(seconds: 2)}) async {
    final location = Location();
    for (int a = 1; a <= attempts; a++) {
      bool gpsOn = await location.serviceEnabled();
      if (!gpsOn) {
        gpsOn = await location.requestService();
      }
      if (gpsOn) return true;
      if (a < attempts) {
        await Future.delayed(baseDelay * a);
      }
    }
    return false;
  }

  Future<bool> _retryTopics({int attempts = 3, Duration baseDelay = const Duration(seconds: 1)}) async {
    for (int a = 1; a <= attempts; a++) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token == null) throw Exception('Token null');
        final ok = await _checkTopics();
        if (ok) return true;
      } catch (_) {}
      if (a < attempts) {
        await Future.delayed(baseDelay * a);
      }
    }
    return false;
  }

  /// Verifica conectividad y emite `noInternet` si no hay red.
  Future<bool> checkInternetAndEmit() async {
    final status = await Connectivity().checkConnectivity();
    final ok = status != ConnectivityResult.none;
    if (!ok) {
      _controller.add(AppStatus.noInternet);
    }
    return ok;
  }
}