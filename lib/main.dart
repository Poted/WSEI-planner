import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:icalendar_parser/icalendar_parser.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/date_symbol_data_local.dart';
import 'dart:convert';

import 'credit.dart';
import 'credits_screen.dart';
import 'deadline.dart';
import 'deadlines_screen.dart';

const MaterialColor wseiGreen = MaterialColor(
  _wseiGreenPrimaryValue,
  <int, Color>{
    50: Color(0xFFF2F8E8),
    100: Color(0xFFE0EDC9),
    200: Color(0xFFCCE1A7),
    300: Color(0xFFB8D585),
    400: Color(0xFFA8CC6B),
    500: Color(_wseiGreenPrimaryValue),
    600: Color(0xFF86BF3A),
    700: Color(0xFF7CB833),
    800: Color(0xFF72B12D),
    900: Color(0xFF60A521),
  },
);
const int _wseiGreenPrimaryValue = 0xFF8DC63F;

class ScheduleEntry {
  final String subjectName;
  final DateTime startTime;
  final DateTime endTime;
  final String lecturer;
  final String classType;
  final String room;

  ScheduleEntry({
    required this.subjectName,
    required this.startTime,
    required this.endTime,
    required this.lecturer,
    required this.classType,
    required this.room,
  });
}

Map<String, String> _parseDescription(String description) {
  final map = <String, String>{};
  final lines = description.split('\\n');
  for (var line in lines) {
    final parts = line.split(':');
    if (parts.length >= 2) {
      final key = parts[0].trim();
      final value = parts.sublist(1).join(':').trim();
      map[key] = value;
    }
  }
  return map;
}

Future<List<ScheduleEntry>> parseSchedule() async {
  final prefs = await SharedPreferences.getInstance();
  String? icsString;

  if (kIsWeb) {
    icsString = prefs.getString('custom_ics_content');
  } else {
    final String? customPath = prefs.getString('custom_ics_path');
    if (customPath != null && await File(customPath).exists()) {
      final file = File(customPath);
      icsString = await file.readAsString(encoding: utf8);
    }
  }

  if (icsString == null) {
    print('Brak planu. Oczekuję na import.');
    return [];
  }
  
  final iCalendar = ICalendar.fromString(icsString);
  final entries = <ScheduleEntry>[];

  for (final event in iCalendar.data) {
    if (event.containsKey('summary') &&
        event.containsKey('dtstart') &&
        event.containsKey('dtend')) {
      final descriptionMap =
          _parseDescription(event['description']?.toString() ?? '');
      try {
        final entry = ScheduleEntry(
          subjectName: event['summary'].toString(),
          startTime: (event['dtstart'] as IcsDateTime).toDateTime()!,
          endTime: (event['dtend'] as IcsDateTime).toDateTime()!,
          lecturer: descriptionMap['Prowadzący'] ?? 'Brak danych',
          classType: descriptionMap['Grupy'] ?? 'Brak danych',
          room: descriptionMap['Sala'] ?? 'Brak danych',
        );
        entries.add(entry);
      } catch (e) {
        print('Błąd przetwarzania wydarzenia: $e');
      }
    }
  }
  return entries;
}

Map<DateTime, List<ScheduleEntry>> groupScheduleByDate(
    List<ScheduleEntry> entries) {
  final Map<DateTime, List<ScheduleEntry>> grouped = {};
  for (final entry in entries) {
    final dateKey =
        DateTime(entry.startTime.year, entry.startTime.month, entry.startTime.day);
    if (!grouped.containsKey(dateKey)) {
      grouped[dateKey] = [];
    }
    grouped[dateKey]!.add(entry);
  }
  return grouped;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await initializeDateFormatting('pl_PL', null);

  await Hive.initFlutter();

  Hive.registerAdapter(DeadlineAdapter());
  Hive.registerAdapter(SubjectAdapter());
  Hive.registerAdapter(CreditPartAdapter());

  await Hive.openBox<Deadline>('deadlines');
  await Hive.openBox<Subject>('subjects');
  await Hive.openBox<CreditPart>('credit_parts');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WSEI Planner',
      theme: ThemeData(
        primarySwatch: wseiGreen,
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const ScheduleScreen(),
    );
  }
}

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  int _selectedIndex = 0;
  late Future<List<ScheduleEntry>> _scheduleFuture;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  void _loadSchedule() {
    setState(() {
      _scheduleFuture = parseSchedule().then((entries) {
        _populateCreditsBoxOnce(entries);
        return entries;
      });
    });
  }


  Future<void> _pickAndSaveIcsFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ics'],
      withData: kIsWeb,
    );

    if (result != null) {
      final prefs = await SharedPreferences.getInstance();

      if (kIsWeb) {
        final fileBytes = result.files.single.bytes!;
        final icsContent = utf8.decode(fileBytes); 
        await prefs.setString('custom_ics_content', icsContent);
      } else {
        final path = result.files.single.path!;
        await prefs.setString('custom_ics_path', path);
      }

      await Hive.box<Subject>('subjects').clear();
      await Hive.box<CreditPart>('credit_parts').clear();

      _loadSchedule();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nowy plan zajęć został zaimportowany!')),
        );
      }
    }
  }

  void _populateCreditsBoxOnce(List<ScheduleEntry> entries) {
    final subjectsBox = Hive.box<Subject>('subjects');
    if (subjectsBox.isNotEmpty) return;
    final partsBox = Hive.box<CreditPart>('credit_parts');
    final typesToInclude = ['Cw', 'Konw', 'Lab', 'Wyk'];
    final Map<String, Map<String, CreditPart>> subjectsMap = {};
    for (final entry in entries) {
      if (typesToInclude.any((type) => entry.classType.contains(type))) {
        subjectsMap.putIfAbsent(entry.subjectName, () => {});
        final partKey = '${entry.classType}-${entry.lecturer}';
        subjectsMap[entry.subjectName]!.putIfAbsent(
          partKey,
          () => CreditPart(type: entry.classType, lecturer: entry.lecturer),
        );
      }
    }
    for (final subjectEntry in subjectsMap.entries) {
      final subjectName = subjectEntry.key;
      final creditParts = subjectEntry.value.values.toList();
      if (creditParts.isNotEmpty) {
        partsBox.addAll(creditParts);
        final hiveList = HiveList(partsBox, objects: creditParts);
        subjectsBox.add(Subject(name: subjectName, parts: hiveList));
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildGroupedScheduleList(List<ScheduleEntry> allEntries) {
    final grouped = groupScheduleByDate(allEntries);
    final sortedKeys = grouped.keys.toList()..sort();
    final now = DateTime.now();

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final dateKey = sortedKeys[index];
        final entriesForDay = grouped[dateKey]!;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          clipBehavior: Clip.antiAlias,
          elevation: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                color: wseiGreen.shade600,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Text(
                  DateFormat('EEEE, dd MMMM yyyy', 'pl_PL').format(dateKey),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Color.fromARGB(255, 255, 255, 255),
                  ),
                ),
              ),
              ...entriesForDay.map((item) {
                final bool isCurrent =
                    now.isAfter(item.startTime) && now.isBefore(item.endTime);
                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                        left: BorderSide(
                            color: isCurrent
                                ? Colors.greenAccent.shade700
                                : Colors.transparent,
                            width: 5.0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(11, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.subjectName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.schedule_outlined,
                              size: 16, color: Colors.black54),
                          const SizedBox(width: 8),
                          Text(
                              '${DateFormat.Hm().format(item.startTime)} - ${DateFormat.Hm().format(item.endTime)}'),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.person_outline,
                              size: 16, color: Colors.black54),
                          const SizedBox(width: 8),
                          Expanded(child: Text(item.lecturer)),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.location_on_outlined,
                              size: 16, color: Colors.black54),
                          const SizedBox(width: 8),
                          Expanded(child: Text(item.room)),
                          Text(item.classType,
                              style: const TextStyle(
                                  color: Colors.black54,
                                  fontStyle: FontStyle.italic)),
                        ]),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUpcomingList(List<ScheduleEntry> allEntries) {
    final now = DateTime.now();

    DateTime findFriday(DateTime from) {
      int daysAgo = (from.weekday - 5 + 7) % 7;
      return DateTime(from.year, from.month, from.day)
          .subtract(Duration(days: daysAgo));
    }

    DateTime friday = findFriday(now);
    DateTime sunday = friday.add(const Duration(days: 2));

    List<ScheduleEntry> upcomingEntries = allEntries.where((entry) {
      return entry.startTime
              .isAfter(friday.subtract(const Duration(seconds: 1))) &&
          entry.startTime.isBefore(sunday.add(const Duration(days: 1)));
    }).toList();

    if (upcomingEntries.isEmpty) {
      friday = friday.add(const Duration(days: 7));
      sunday = friday.add(const Duration(days: 2));
      upcomingEntries = allEntries.where((entry) {
        return entry.startTime
                .isAfter(friday.subtract(const Duration(seconds: 1))) &&
            entry.startTime.isBefore(sunday.add(const Duration(days: 1)));
      }).toList();
    }

    upcomingEntries.sort((a, b) => a.startTime.compareTo(b.startTime));

    if (upcomingEntries.isEmpty) {
      return const Center(
          child: Text('Brak zajęć w najbliższych dwóch weekendach.'));
    }

    return _buildGroupedScheduleList(upcomingEntries);
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Najbliższe', 'Plan zajęć', 'Zaliczenia', 'Terminy'];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/calendar_logo.png',
              height: 35,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.calendar_month, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 12),
            Text(titles[_selectedIndex]),
          ],
        ),
        centerTitle: true,
        titleTextStyle: GoogleFonts.playwriteAt(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [wseiGreen.shade500, wseiGreen.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: const Border(
              bottom: BorderSide(
                color: Colors.black26,
                width: 1.5,
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined, color: Colors.white),
            tooltip: 'Importuj nowy plan (.ics)',
            onPressed: _pickAndSaveIcsFile,
          ),
        ],
      ),
      body: FutureBuilder<List<ScheduleEntry>>(
        future: _scheduleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Błąd wczytywania danych: ${snapshot.error}'));
          }
          if (snapshot.hasData) {
            final allEntries = snapshot.data!;

            if (allEntries.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'Zaimportuj swój plan zajęć w formacie .ics, używając ikony w prawym górnym rogu.\n Pobierzesz go z Wirtualnego Dziekanatu używając przycisku "Pobierz jako ical" w zakładce "Plany zajęć".\n\n!NOTE:\nPamiętaj, aby daty od-do były w zakresie obejmującym cały semestr. W przeciwnym wypadku Dziekanat wygeneruje niepełny plik.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.black54),
                  ),
                ),
              );
            }

            return IndexedStack(
              index: _selectedIndex,
              children: [
                _buildUpcomingList(allEntries),
                _buildGroupedScheduleList(allEntries),
                const CreditsScreen(),
                const DeadlinesScreen(),
              ],
            );
          }
          return const Center(child: Text('Brak danych'));
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
              icon: Icon(Icons.timelapse), label: 'Najbliższe'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month), label: 'Plan'),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Zaliczenia'),
          BottomNavigationBarItem(icon: Icon(Icons.task_alt), label: 'Terminy'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}