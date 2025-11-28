import 'package:hive/hive.dart';

part 'alerta_model.g.dart';

@HiveType(typeId: 0)
class AlertaModel {
  @HiveField(0)
  final String idAlerta;

  @HiveField(1)
  final String idCamara;

  @HiveField(2)
  final DateTime timestamp;

  @HiveField(3)
  final String img;

  @HiveField(4)
  final double score;

  @HiveField(5)
  final double longitud;

  @HiveField(6)
  final double latitud;

  AlertaModel({
    required this.idAlerta,
    required this.idCamara,
    required this.timestamp,
    required this.img,
    required this.score,
    required this.longitud,
    required this.latitud,
  });

   // 👇 Aquí agregas este método:
  factory AlertaModel.fromJson(Map<String, dynamic> json) {
    return AlertaModel(
      idAlerta: json['idAlerta']?.toString() ?? '',
      idCamara: json['idCamara']?.toString() ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      img: json['img']?.toString() ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      latitud: (json['latitud'] as num?)?.toDouble() ?? 0.0,
      longitud: (json['longitud'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
