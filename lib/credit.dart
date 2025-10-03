import 'package:hive/hive.dart';

part 'credit.g.dart';

@HiveType(typeId: 3)
class CreditPart extends HiveObject {
  @HiveField(0)
  String type;

  @HiveField(1)
  String lecturer;

  @HiveField(2)
  bool isPassed;

  @HiveField(3)
  List<DateTime> deadlines;

  @HiveField(4)
  String notes; 

  CreditPart({
    required this.type,
    required this.lecturer,
    this.isPassed = false,
    List<DateTime>? deadlines,
    this.notes = '', 
  }) : deadlines = deadlines ?? [];
}

@HiveType(typeId: 2)
class Subject extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  HiveList<CreditPart> parts;

  Subject({
    required this.name,
    required this.parts,
  });
}