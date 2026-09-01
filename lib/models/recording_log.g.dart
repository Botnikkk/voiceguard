// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recording_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecordingLogAdapter extends TypeAdapter<RecordingLog> {
  @override
  final int typeId = 1;

  @override
  RecordingLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecordingLog(
      id: fields[0] as String,
      recordingName: fields[1] as String,
      timestamp: fields[2] as DateTime,
      riskScore: fields[3] as double,
      verdict: fields[4] as RecordingVerdict,
      durationInSeconds: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, RecordingLog obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.recordingName)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.riskScore)
      ..writeByte(4)
      ..write(obj.verdict)
      ..writeByte(5)
      ..write(obj.durationInSeconds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecordingLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RecordingVerdictAdapter extends TypeAdapter<RecordingVerdict> {
  @override
  final int typeId = 0;

  @override
  RecordingVerdict read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return RecordingVerdict.safe;
      case 1:
        return RecordingVerdict.flagged;
      case 2:
        return RecordingVerdict.escalated;
      default:
        return RecordingVerdict.safe;
    }
  }

  @override
  void write(BinaryWriter writer, RecordingVerdict obj) {
    switch (obj) {
      case RecordingVerdict.safe:
        writer.writeByte(0);
        break;
      case RecordingVerdict.flagged:
        writer.writeByte(1);
        break;
      case RecordingVerdict.escalated:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecordingVerdictAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
