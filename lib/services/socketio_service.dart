import 'dart:async';
import 'package:app_g/models/alerta_model.dart';
import 'package:app_g/utils/logger.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:connectivity_plus/connectivity_plus.dart';

class SocketioService {
  // static const String URL_API = 'http://10.0.2.2:3000';
  // static const String URL_API = 'http://192.168.1.119:3000';
  static const String URL_API = 'https://sulkies-aubrielle-imprisonable.ngrok-free.dev';

  // Cola sencilla para eventos que requieren garantía (ack/done). Cada entrada almacena
  // la función que ejecuta el envío y el número de intentos ya realizados.
  static final List<_QueuedRetry> _queue = [];
  static bool _retriesActive = false;
  static StreamSubscription? _connectivitySub;

  /// Inicializa el manejador de reintentos escuchando cambios de conectividad.
  static void initRetries({Connectivity? connectivity}) {
    if (_connectivitySub != null) return; // ya inicializado
    final conn = connectivity ?? Connectivity();
    _connectivitySub = conn.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        _drainQueue();
      }
    });
  }

  static void disposeRetries() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _queue.clear();
  }

  static void _enqueue(String label, Future<Map<String, dynamic>?> Function() op) {
    _queue.add(_QueuedRetry(label: label, operation: op));
  }

  static Future<void> _drainQueue() async {
    if (_retriesActive) return;
    _retriesActive = true;
    try {
      int i = 0;
      while (i < _queue.length) {
        final item = _queue[i];
        final res = await item.operation();
        if (res != null) {
          _queue.removeAt(i);
          continue; // no avanzar índice porque removimos
        } else {
          item.attempts += 1;
          if (item.attempts >= 5) {
            // descartar después de 5 intentos fallidos
            _queue.removeAt(i);
            continue;
          }
          // backoff incremental básico: esperar attempts * 1s
          await Future.delayed(Duration(seconds: item.attempts));
          // reintentar inmediatamente (sin avanzar i)
          continue;
        }
      }
    } finally {
      _retriesActive = false;
    }
  }

  /// Método privado genérico para emitir un evento con ACK y recibir la respuesta
  static Future<Map<String, dynamic>?> _emitWithAck({
    required String event,
    required Map<String, dynamic> data,
    Duration timeout = const Duration(seconds: 4),
    bool skipIfOffline = true,
    int retries = 0,
    Duration baseBackoff = const Duration(seconds: 1),
  }) async {
    // Si no hay conectividad, retornar inmediatamente para no bloquear el inicio de la app
    if (skipIfOffline) {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        logger.w('Sin conexión: se omite emisión de "$event"');
        return null;
      }
    }
    final opts = IO.OptionBuilder()
      .setTransports(['websocket', 'polling'])
      .disableAutoConnect()
      .setPath('/socket.io')
      .enableReconnection()
      .setReconnectionAttempts(3)
      .setReconnectionDelay(1000)
      .build();
    logger.i('Conectando a $URL_API con opts: transports=websocket,polling path=/socket.io');
    final socket = IO.io(URL_API, opts);

    final completer = Completer<Map<String, dynamic>?>();

    void safeComplete(Map<String, dynamic>? value) {
      if (!completer.isCompleted) {
        completer.complete(value);
        socket.disconnect();
      }
    }

    socket.onConnect((_) {
      logger.i('Socket conectado para evento: $event');

      socket.emitWithAck(event, data, ack: (res) {
        if (res == null) {
          logger.e('No se recibió respuesta del servidor para $event');
          safeComplete(null);
        } else if (res is Map) {
          safeComplete(Map<String, dynamic>.from(res));
        } else {
          logger.e('Respuesta no válida para $event: $res');
          safeComplete(null);
        }
      });
    });

    socket.onConnectError((err) {
      logger.e('Error de conexión al evento $event: $err');
      try { logger.e('Detalles connectError: ${err?.toString()}'); } catch (_) {}
      safeComplete(null);
    });

    socket.onError((err) {
      logger.e('Error socket al evento $event: $err');
      try { logger.e('Detalles error: ${err?.toString()}'); } catch (_) {}
      safeComplete(null);
    });

    socket.connect();

    // En emulador Android, algunas redes tardan en resolver; ampliar timeout por defecto
    final effectiveTimeout = timeout.inSeconds < 8 ? const Duration(seconds: 8) : timeout;
    Future<Map<String, dynamic>?> future = completer.future.timeout(effectiveTimeout, onTimeout: () {
      socket.disconnect();
      return null;
    });

    if (retries <= 0) return future;

    for (int attempt = 1; attempt <= retries; attempt++) {
      final result = await future;
      if (result != null) return result;

      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        // Se agregará a la cola para reintentar al volver la red
        _enqueue(event, () => _emitWithAck(
              event: event,
              data: data,
              timeout: timeout,
              skipIfOffline: true,
              retries: 0,
            ));
        initRetries();
        return null; // salimos; el resultado se gestionará luego
      }

      // Esperar con backoff exponencial simple
      final delay = baseBackoff * attempt;
      logger.w('Reintentando "$event" intento $attempt tras ${delay.inSeconds}s');
      await Future.delayed(delay);
      future = _emitWithAck(
        event: event,
        data: data,
        timeout: timeout,
        skipIfOffline: skipIfOffline,
        retries: 0,
      );
    }
    return await future; // último resultado (puede ser null)
  }

  /// Verifica una alerta conectándose al socket solo cuando se llama
  static Future<AlertaModel?> verifyAlertWithConnect(int id) async {
    final res = await _emitWithAck(event: 'verify', data: {'id_alerta': id}, retries: 2);
    if (res == null) return null;

    if (res['ok'] == true && res['data'] != null) {
      final data = Map<String, dynamic>.from(res['data']);

      // Caso 1: alerta con campos completos
      if (data.containsKey('_id_alerta')) {
        return AlertaModel(
          idAlerta: data['_id_alerta'].toString(),
          idCamara: data['_id_camara'].toString(),
          timestamp: DateTime.parse(data['_timestamp'].toString()),
          img: data['imagen']?.toString() ?? '',
          score: (data['score'] as num?)?.toDouble() ?? 0.0,
          longitud: (data['longitud'] as num?)?.toDouble() ?? 0.0,
          latitud: (data['latitud'] as num?)?.toDouble() ?? 0.0,
        );
      }
      // Caso 2: alerta ya atendida
      else if (data['status'] == 'alerta atendida') {
        logger.i('Alerta atendida previamente');
        return null;
      } else {
        logger.e('Respuesta inesperada: $data');
        return null;
      }
    } else {
      logger.e('Respuesta inválida del servidor: $res');
      return null;
    }
  }

  /// Envía un ACK al servidor con el estado de la alerta
  static Future<String?> sendAck({
    required String idAlerta,
    required String idAlertaAct,
    required String idCamara,
    required DateTime timestamp,
    required String estado,
  }) async {
    final ackData = {
      "id_alerta": idAlerta,
      "id_alerta_act": idAlertaAct,
      "id_camara": idCamara,
      "timestamp": timestamp.toIso8601String(),
      "estado": estado,
    };

    final res = await _emitWithAck(event: 'ack', data: ackData, retries: 3);
    if (res == null) return null;

    if (res['ok'] == true && res['data'] != null) {
      final data = Map<String, dynamic>.from(res['data']);
      final status = data['status']?.toString();
      logger.i('ACK confirmado por el servidor: $status');
      return status;
    } else {
      logger.e('Respuesta inválida al enviar ACK: $res');
      return null;
    }
  }

  /// Envía el evento DONE al servidor
  static Future<bool> sendDone({required String idAlerta}) async {
    final res = await _emitWithAck(event: 'done', data: {'id_alerta': int.tryParse(idAlerta) ?? 0}, retries: 3);
    if (res == null) return false;

    if (res['ok'] == true && res['data'] != null) {
      final data = Map<String, dynamic>.from(res['data']);
      final status = data['status']?.toString();

      if (status == 'alerta resuelta') {
        logger.i('Alerta finalizada correctamente: $status');
        return true;
      } else {
        logger.e('Alerta no finalizada, respuesta: $status');
        return false;
      }
    } else {
      logger.e('Respuesta inválida al enviar DONE: $res');
      return false;
    }
  }

  /// Ping sencillo para comprobar accesibilidad del backend vía socket.
  /// Considera OK cualquier respuesta (aunque sea negocio negativo).
  static Future<bool> ping() async {
    // Importante: el uso anterior hacía ping reutilizando el evento 'done' con id_alerta=0.
    // Si el backend no responde ACK para ese caso (p.ej. porque 0 es inválido) el resultado siempre era null
    // y provocaba reconexiones consecutivas, generando múltiples "Socket conectado..." y finalmente false.
    // Un ping de salud SOLO necesita comprobar que podemos establecer la conexión base.
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) return false;

      final opts = IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .setPath('/socket.io')
          .enableReconnection()
          .setReconnectionAttempts(0) // para ping evitamos reconexiones múltiples
          .build();

      final socket = IO.io(URL_API, opts);
      final completer = Completer<bool>();

      void finish(bool ok) {
        if (!completer.isCompleted) {
          completer.complete(ok);
          socket.disconnect();
        }
      }

      socket.onConnect((_) {
        logger.i('Ping: conexión establecida');
        finish(true);
      });

      socket.onConnectError((err) {
        logger.w('Ping: connectError $err');
        finish(false);
      });

      socket.onError((err) {
        logger.w('Ping: error $err');
        finish(false);
      });

      logger.i('Ping: intentando conectar a $URL_API');
      socket.connect();

      return await completer.future.timeout(const Duration(seconds: 6), onTimeout: () {
        logger.w('Ping: timeout de conexión');
        socket.disconnect();
        return false;
      });
    } catch (e) {
      logger.e('Ping: excepción $e');
      return false;
    }
  }
}

class _QueuedRetry {
  final String label;
  final Future<Map<String, dynamic>?> Function() operation;
  int attempts = 0;
  _QueuedRetry({required this.label, required this.operation});
}
