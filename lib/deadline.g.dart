// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deadline.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DeadlineAdapter extends TypeAdapter<Deadline> {
  @override
  final int typeId = 1;

  @override
  Deadline read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Deadline(
      name: fields[0] as String,
      date: fields[1] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Deadline obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.date);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeadlineAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
