// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alerta_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AlertaModelAdapter extends TypeAdapter<AlertaModel> {
  @override
  final int typeId = 0;

  @override
  AlertaModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AlertaModel(
      idAlerta: fields[0] as String,
      idCamara: fields[1] as String,
      timestamp: fields[2] as DateTime,
      img: fields[3] as String,
      score: fields[4] as double,
      longitud: fields[5] as double,
      latitud: fields[6] as double,
    );
  }

  @override
  void write(BinaryWriter writer, AlertaModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.idAlerta)
      ..writeByte(1)
      ..write(obj.idCamara)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.img)
      ..writeByte(4)
      ..write(obj.score)
      ..writeByte(5)
      ..write(obj.longitud)
      ..writeByte(6)
      ..write(obj.latitud);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlertaModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
