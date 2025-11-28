// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'evento_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EventoModelAdapter extends TypeAdapter<EventoModel> {
  @override
  final int typeId = 1;

  @override
  EventoModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EventoModel(
      alerta: fields[0] as AlertaModel,
      distancia: fields[1] as double,
      timestamp: fields[2] as DateTime,
      fin: fields[3] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, EventoModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.alerta)
      ..writeByte(1)
      ..write(obj.distancia)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.fin);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventoModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
