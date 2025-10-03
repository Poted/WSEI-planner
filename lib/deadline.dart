// lib/deadline.dart
import 'package:hive/hive.dart';

part 'deadline.g.dart'; // Ta linijka zostanie wygenerowana automatycznie

@HiveType(typeId: 1)
class Deadline {
  @HiveField(0)
  String name;

  @HiveField(1)
  DateTime date;

  Deadline({required this.name, required this.date});
}