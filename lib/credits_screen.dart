import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:wseiflow/main.dart';
import 'theme_provider.dart';
import 'package:provider/provider.dart';
import 'credit.dart';

class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  final _subjectsBox = Hive.box<Subject>('subjects');

  Future<void> _showEditPartDialog(CreditPart part) async {
    List<DateTime> deadlines = List.from(part.deadlines);
    bool isPassed = part.isPassed;
    final notesController = TextEditingController(text: part.notes);

    await showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setStateInDialog) {
            return AlertDialog(
              title: Text(part.type),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 150,
                      width: double.maxFinite,
                      child: ListView.builder(
                        itemCount: deadlines.length + 1,
                        itemBuilder: (context, index) {
                          if (index == deadlines.length) {
                            return TextButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text("Dodaj termin"),
                              onPressed: () async {
                                final pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (pickedDate != null) {
                                  setStateInDialog(() => deadlines.add(pickedDate));
                                }
                              },
                            );
                          }
                          final deadline = deadlines[index];
                          return ListTile(
                            title: Text(DateFormat('dd.MM.yyyy').format(deadline)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  setStateInDialog(() => deadlines.removeAt(index)),
                            ),
                          );
                        },
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Zaliczone'),
                      value: isPassed,
                      onChanged: (newValue) =>
                          setStateInDialog(() => isPassed = newValue),
                    ),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notatki do zaliczenia',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Anuluj')),
                TextButton(
                  onPressed: () {
                    part.deadlines = deadlines;
                    part.isPassed = isPassed;
                    part.notes = notesController.text;
                    part.save();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Zapisz'),
                ),
              ],
            );
          });
        });
  }

  @override
  Widget build(BuildContext context) {

    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.isPusheenMode
        ? Colors.transparent
        : null,

      body: ValueListenableBuilder(
        valueListenable: _subjectsBox.listenable(),
        builder: (context, Box<Subject> box, _) {
          if (box.values.isEmpty) {
            return const Center(child: Text('Lista zaliczeń jest pusta.'));
          }
          final subjects = box.values.toList();

          return ListView.builder(
            itemCount: subjects.length,
            itemBuilder: (context, index) {
              final subject = subjects[index];
              final relevantParts = subject.parts.where((part) {
                return part.type.contains('Wyk') ||
                    part.type.contains('Cw') ||
                    part.type.contains('Konw') ||
                    part.type.contains('Lab');
              }).toList();
              final bool isSubjectPassed =
                  relevantParts.isNotEmpty && relevantParts.every((part) => part.isPassed);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: isSubjectPassed ? wseiGreen.shade500 : null,
                child: ExpansionTile(
                  title: Text(subject.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      )),
                  children: relevantParts.map((part) {
                    final isPassed = part.isPassed;
                    final color = 
                      isSubjectPassed ? 
                        themeProvider.isDarkMode ?
                        const Color.fromARGB(255, 78, 110, 69) : wseiGreen.shade100 
                      : null;
                    String deadlinesText = 'Brak terminów';
                    if (part.deadlines.isNotEmpty) {
                      part.deadlines.sort();
                      deadlinesText = part.deadlines
                          .map((d) => DateFormat('dd.MM.yyyy').format(d))
                          .join(', ');
                    }

                    return Container(
                      color: color,
                      child: ListTile(
                        leading: isPassed
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : const Icon(Icons.radio_button_unchecked),
                        title: Text(part.type,
                            style: TextStyle(
                                decoration:
                                    isPassed ? TextDecoration.lineThrough : null)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(part.lecturer),
                            if (part.deadlines.isNotEmpty)
                              Text('Terminy: $deadlinesText',
                                  style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        trailing: part.notes.isNotEmpty
                            ? const Icon(Icons.note_alt, color: Colors.blueGrey)
                            : null,
                        onTap: () async {
                          await _showEditPartDialog(part);
                          setState(() {});
                        },
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}