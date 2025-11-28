import 'dart:isolate';
import 'dart:ui';
import 'package:app_g/models/alerta_model.dart';
import 'package:app_g/models/evento_model.dart';
import 'package:app_g/services/geo_service.dart';
import 'package:app_g/services/hive_service.dart';
import 'package:app_g/utils/logger.dart';

class BackgroundCommService {
  static final ReceivePort _receivePort = ReceivePort();

  static void init() {
    // Si ya estaba registrado, lo eliminamos para evitar conflictos
    final name = 'main_port';
    final existing = IsolateNameServer.lookupPortByName(name);
    if (existing != null) {
      IsolateNameServer.removePortNameMapping(name);
    }

    // Registrar el puerto principal
    IsolateNameServer.registerPortWithName(_receivePort.sendPort, name);

    _receivePort.listen((message) async {
      logger.i('✅ Main isolate recibió mensaje: $message');

      if (message is Map<String, dynamic>) {
        final from = message['from'] ?? '';
        final data = Map<String, dynamic>.from(message['data'] ?? {});

        if (from.contains('alertas')) {
          // 🟢 lógica para alertas
          final alerta = AlertaModel(
            idAlerta: data['_id_alerta'] ??
                DateTime.now().millisecondsSinceEpoch.toString(),
            idCamara: data['_id_camara'] ?? '',
            timestamp:
                DateTime.tryParse(data['_timestamp'] ?? '') ?? DateTime.now(),
            img: data['img'] ?? '',
            score: double.tryParse(data['score'] ?? '0') ?? 0,
            longitud: double.tryParse(data['longitud'] ?? '0') ?? 0,
            latitud: double.tryParse(data['latitud'] ?? '0') ?? 0,
          );

          double distancia = -1;

          try {
            final pos = await GeoService.getImmediateLocation();
            if (pos != null) {
              logger.i('Posicion: ${pos.latitude} - ${pos.longitude}');
              logger.i('Posicion Alerta: ${alerta.latitud} - ${alerta.longitud}');
              distancia = GeoService.calcularDistancia(
                pos.latitude,
                pos.longitude,
                alerta.latitud,
                alerta.longitud,
              );
              logger.i('Distancia: $distancia');
            }
          } catch (_) {}


          final evento = EventoModel(
            alerta: alerta,
            distancia: distancia,
            timestamp: DateTime.now(),
          );

          await HiveService.addEvento(evento, 'eventoBox');
        } else if (from.contains('ack')) {
          // 🔵 lógica para ACK
          final idAlerta = data['id_alerta_act'] ?? '';
          if (idAlerta.isNotEmpty) {
            await HiveService.deleteEvento(idAlerta, 'eventoBox');
            logger.i('🗑️ Evento con idAlerta $idAlerta eliminado por ACK.');
          }
        }
      }
    });
  }
}
