import 'package:app_g/services/geo_service.dart';
import 'package:app_g/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:app_g/models/evento_model.dart';
import 'package:app_g/models/alerta_model.dart';

class HiveService {
  static const String eventoBox = 'eventoBox';
  static const String eventosPendientesBox = 'eventosPendientesBox';
  static const String historialBox = 'historialBox';
  static bool inicializado = false;

  /// Inicializa Hive y registra los adapters
  static Future<void> initHive() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(AlertaModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(EventoModelAdapter());
    }

    await Hive.openBox<EventoModel>(eventoBox);
    await Hive.openBox<EventoModel>(eventosPendientesBox);
    await Hive.openBox<AlertaModel>(historialBox);

    await syncBox();
    inicializado = true;
  }

  /// Retorna la caja de eventos
  static Box<EventoModel> getBox(String boxName) {
    return Hive.box<EventoModel>(boxName);
  }

  /// Retorna la caja de historial
  static Box<AlertaModel> getHistorialBox() {
    return Hive.box<AlertaModel>(historialBox);
  }

  /// Guarda o actualiza un evento usando idAlerta como clave
  static Future<void> saveEvento(EventoModel evento, String boxName) async {
    final box = getBox(boxName);
    await box.put(evento.alerta.idAlerta, evento);
  }

  /// Agrega un evento evitando duplicados por idAlerta
  static Future<void> addEvento(EventoModel evento, String boxName) async {
    final box = getBox(boxName);
    if (!box.containsKey(evento.alerta.idAlerta)) {
      await box.put(evento.alerta.idAlerta, evento);
    }
  }

  /// Elimina un evento por idAlerta
  static Future<void> deleteEvento(String idAlerta, String boxName) async {
    final box = getBox(boxName);

    try {
      // Si la clave es directamente el idAlerta
      if (box.containsKey(idAlerta)) {
        await box.delete(idAlerta);
        return;
      }

      // Buscar por valor si no coincide la clave
      final key = box.keys.firstWhere(
        (k) {
          final ev = box.get(k);
          return ev?.alerta.idAlerta == idAlerta;
        },
        orElse: () => null,
      );

      if (key != null) {
        await box.delete(key);
      }
    } catch (e, st) {
      debugPrint('❌ Error al eliminar evento ($idAlerta): $e');
      debugPrintStack(stackTrace: st);
    }
  }

  /// Escuchable para cambios en la caja (ValueListenable)
  static ValueListenable<Box<EventoModel>> getEventosListenable() {
    return getBox(eventoBox).listenable();
  }

  /// Obtiene todos los eventos en orden inverso, sin duplicados
  static List<EventoModel> getAllEventos(String boxName) {
    final box = getBox(boxName);
    final seenIds = <String>{};
    final uniqueEventos = <EventoModel>[];

    for (var e in box.values.toList().reversed) {
      if (seenIds.add(e.alerta.idAlerta)) {
        uniqueEventos.add(e);
      }
    }

    return uniqueEventos;
  }

  /// Sincroniza la caja (útil después de operaciones masivas o en arranque)
  static Future<void> syncBox() async {
    final pendientes = getBox(eventosPendientesBox).values.toList();

    if (pendientes.isEmpty) return;

    final eventoBoxLocal = getBox(eventoBox);

    for (var evento in pendientes) {
      double distancia = -1;
      try {
        final pos = await GeoService.getImmediateLocation();
        if (pos != null) {
          distancia = GeoService.calcularDistancia(
            pos.latitude,
            pos.longitude,
            evento.alerta.latitud,
            evento.alerta.longitud,
          );
        }
      } catch (_) {}

      final actualizado = EventoModel(
        alerta: evento.alerta,
        distancia: distancia,
        timestamp: DateTime.now(),
      );

      await eventoBoxLocal.put(actualizado.alerta.idAlerta, actualizado);
    }

    await getBox(eventosPendientesBox).clear();
  }

  /// Agrega una alerta al historial
  static Future<void> addHistorial(AlertaModel alerta) async {
    final box = getHistorialBox();
    await box.add(alerta);

    logger.i('Historial guardado con exito: ${box.values.toList().length}');
  }

  static Future<List<AlertaModel>> getHistorial() async {
    final box = getHistorialBox(); // obtenemos la caja de historial
    List<AlertaModel> historial = box.values.toList(); // convertimos los valores en lista
    return historial;
  }

  /// Elimina el primer evento guardado en el historial
  static Future<void> deleteFirstEvento() async {
    final box = getHistorialBox();

    // Solo eliminar si hay 5 o más elementos
    if (box.length >= 5) {
      final firstKey = box.keyAt(0);
      await box.delete(firstKey);
    }
  }

  /// Limpia la caja especificada
  static Future<void> clearBox(String boxName) async {
    await getBox(boxName).clear();
  }
}
