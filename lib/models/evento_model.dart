import 'package:hive/hive.dart';
import 'alerta_model.dart';

part 'evento_model.g.dart';

@HiveType(typeId: 1) // OJO: typeId debe ser único, distinto de AlertaModel
class EventoModel {
  @HiveField(0)
  final AlertaModel alerta;

  @HiveField(1)
  final double distancia;

  @HiveField(2)
  final DateTime timestamp; // cuando se recibió la notificación

  @HiveField(3)
  DateTime? fin;

  EventoModel({
    required this.alerta,
    required this.distancia,
    required this.timestamp,
    this.fin,
  });
}
