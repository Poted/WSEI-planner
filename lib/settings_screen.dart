// lib/settings_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:universal_html/html.dart' as html;
import 'package:provider/provider.dart'; // Import Provider
import 'theme_provider.dart'; // Import ThemeProvider

import 'credit.dart';
import 'deadline.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _exportData() async {
    final subjectsBox = Hive.box<Subject>('subjects');
    final deadlinesBox = Hive.box<Deadline>('deadlines');

    final List<Map<String, dynamic>> subjectsJson = subjectsBox.values.map((subject) {
      return {
        'name': subject.name,
        'parts': subject.parts.map((part) {
          return {
            'type': part.type,
            'lecturer': part.lecturer,
            'isPassed': part.isPassed,
            'deadlines': part.deadlines.map((d) => d.toIso8601String()).toList(),
            'notes': part.notes,
          };
        }).toList(),
      };
    }).toList();

    final List<Map<String, dynamic>> deadlinesJson = deadlinesBox.values.map((deadline) {
      return {
        'name': deadline.name,
        'date': deadline.date.toIso8601String(),
      };
    }).toList();

    final backupData = {
      'subjects': subjectsJson,
      'deadlines': deadlinesJson,
    };

    final jsonString = jsonEncode(backupData);

    if (kIsWeb) {
      final bytes = utf8.encode(jsonString);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute("download", "wsei_planner_backup.json")
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Eksport dostępny tylko w wersji webowej.')));
    }
  }

  Future<void> _importData() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: kIsWeb,
    );

    if (result != null) {
      try {
        String jsonString;
        if (kIsWeb) {
          final fileBytes = result.files.single.bytes!;
          jsonString = utf8.decode(fileBytes);
        } else {
          final path = result.files.single.path!;
          jsonString = await File(path).readAsString(encoding: utf8);
        }

        final backupData = jsonDecode(jsonString);

        final subjectsBox = Hive.box<Subject>('subjects');
        final partsBox = Hive.box<CreditPart>('credit_parts');
        final deadlinesBox = Hive.box<Deadline>('deadlines');

        await subjectsBox.clear();
        await partsBox.clear();
        await deadlinesBox.clear();

        final List subjectsJson = backupData['subjects'] ?? [];
        for (var subjectData in subjectsJson) {
          final List partsData = subjectData['parts'] ?? [];
          final List<CreditPart> creditParts = partsData.map((partData) {
            return CreditPart(
              type: partData['type'],
              lecturer: partData['lecturer'],
              isPassed: partData['isPassed'],
              notes: partData['notes'],
              deadlines: (partData['deadlines'] as List).map((d) => DateTime.parse(d)).toList(),
            );
          }).toList();
          
          await partsBox.addAll(creditParts);
          subjectsBox.add(Subject(name: subjectData['name'], parts: HiveList(partsBox, objects: creditParts)));
        }
        
        final List deadlinesJson = backupData['deadlines'] ?? [];
        for (var deadlineData in deadlinesJson) {
          deadlinesBox.add(Deadline(name: deadlineData['name'], date: DateTime.parse(deadlineData['date'])));
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dane zostały pomyślnie przywrócone!')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd importu: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.isPusheenMode
        ? Colors.transparent
        : null,

      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('Wygląd', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Dark Mode'),
                    value: themeProvider.isDarkMode,
                    onChanged: (value) {
                      themeProvider.setAppThemeMode(value ? AppThemeMode.dark : AppThemeMode.light);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Cat Mode'),
                    value: themeProvider.isPusheenMode,
                    onChanged: (value) {
                      themeProvider.setAppThemeMode(value ? AppThemeMode.pusheen : AppThemeMode.light);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('Kopia zapasowa notatek', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.file_download),
                    title: const Text('Eksportuj dane do pliku'),
                    onTap: () => _exportData(), // Usunięto 'context'
                  ),
                  ListTile(
                    leading: const Icon(Icons.file_upload),
                    title: const Text('Importuj dane z pliku'),
                    onTap: () => _importData(), // Usunięto 'context'
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}