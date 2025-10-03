import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'credit.dart';

class AggregatedDeadline {
  final String subjectName;
  final String partType;
  final DateTime date;
  final bool isPassed;

  AggregatedDeadline({
    required this.subjectName,
    required this.partType,
    required this.date,
    required this.isPassed,
  });
}

class DeadlinesScreen extends StatelessWidget {
  const DeadlinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final subjectsBox = Hive.box<Subject>('subjects');
    final partsBox = Hive.box<CreditPart>('credit_parts');

    return AnimatedBuilder(
      animation: Listenable.merge([subjectsBox.listenable(), partsBox.listenable()]),
      builder: (context, _) {
        
        final allDeadlines = <AggregatedDeadline>[];
        
        for (final subject in subjectsBox.values) {
          for (final part in subject.parts) {
            for (final deadlineDate in part.deadlines) {
              allDeadlines.add(
                AggregatedDeadline(
                  subjectName: subject.name,
                  partType: part.type,
                  date: deadlineDate,
                  isPassed: part.isPassed,
                ),
              );
            }
          }
        }

        allDeadlines.sort((a, b) => a.date.compareTo(b.date));

        if (allDeadlines.isEmpty) {
          return const Center(child: Text('Brak dodanych terminów w sekcji "Zaliczenia".'));
        }

        return ListView.builder(
          itemCount: allDeadlines.length,
          itemBuilder: (context, index) {
            final deadline = allDeadlines[index];
            
            final Icon icon = deadline.isPassed
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.radio_button_unchecked);

            return ListTile(
              leading: icon,
              title: Text(deadline.subjectName),
              subtitle: Text(deadline.partType),
              trailing: Text(DateFormat('dd.MM.yyyy').format(deadline.date)),
            );
          },
        );
      },
    );
  }
}