import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

const primaryColor = Color(0xFF0EA5E9);
const primaryDark = Color(0xFF0284C7);
const primaryLight = Color(0xFFE0F2FE);
const secondaryColor = Color(0xFFF97316);
const successColor = Color(0xFF10B981);
const warningColor = Color(0xFFF59E0B);
const dangerColor = Color(0xFFEF4444);
const bgColor = Color(0xFFF8FAFC);
const cardColor = Colors.white;
const textPrimary = Color(0xFF0F172A);
const textSecondary = Color(0xFF64748B);
const textLight = Color(0xFF94A3B8);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ReminderService.init();
  runApp(const StudyMateApp());
}

class ReminderService {
  static final plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('Notification tapped: ${response.payload}');
      },
    );

    try {
      final androidPlugin = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        // Sirf notification permission, exact alarm permission hata diya hai
        await androidPlugin.requestNotificationsPermission();
      }
    } catch (e) {
      print('Permission request error (non-critical): $e');
    }

    _initialized = true;
  }

  static int notificationId(String id) {
    return id.hashCode.abs() % 2147483647;
  }

  static Future<void> schedule(String id, String title, DateTime due) async {
    try {
      final now = DateTime.now();
      if (!due.isAfter(now)) {
        print('Due date is in the past, skipping notification');
        return;
      }

      var reminder = due.subtract(const Duration(minutes: 30));
      if (!reminder.isAfter(now)) {
        reminder = now.add(const Duration(seconds: 10));
      }

      final tzDateTime = tz.TZDateTime.from(reminder, tz.local);
      print('Scheduling notification for: $title at $tzDateTime');

      await plugin.zonedSchedule(
        notificationId(id),
        'StudyMate Reminder',
        '$title is due soon!',
        tzDateTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'studymate_reminders',
            'Study Reminders',
            channelDescription: 'Reminders for exams and assignments',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            enableVibration: true,
            playSound: true,
          ),
        ),
        // inexactAllowWhileIdle use kiya taaki alarm permission popup na aaye
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: id,
      );

      print('Notification scheduled successfully');
    } catch (e) {
      print('Error scheduling notification: $e');
    }
  }

  static Future<void> cancel(String id) async {
    try {
      final notifId = notificationId(id);
      await plugin.cancel(notifId);
      print('Notification cancelled successfully');
    } catch (e) {
      print('Error cancelling notification: $e');
    }
  }
}

class StudyMateApp extends StatelessWidget {
  const StudyMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'StudyMate',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: bgColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          primary: primaryColor,
          surface: cardColor,
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: bgColor,
          foregroundColor: textPrimary,
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
        ),
      ),
      home: const StudyHome(),
    );
  }
}

class StudyNote {
  StudyNote({
    required this.id,
    required this.title,
    this.body = '',
    this.subject,
    this.due,
    this.pdfId,
    this.type = 'note',
  });

  String id;
  String title;
  String body;
  String? subject;
  DateTime? due;
  String? pdfId;
  String type;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'subject': subject,
        'due': due?.toIso8601String(),
        'pdfId': pdfId,
        'type': type,
      };

  factory StudyNote.fromJson(Map<String, dynamic> j) => StudyNote(
        id: j['id'],
        title: j['title'],
        body: j['body'] ?? '',
        subject: j['subject'],
        due: j['due'] != null ? DateTime.parse(j['due']) : null,
        pdfId: j['pdfId'],
        type: j['type'] ?? 'note',
      );
}

class StudyPdf {
  StudyPdf({
    required this.id,
    required this.name,
    required this.path,
  });

  String id;
  String name;
  String path;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
      };

  factory StudyPdf.fromJson(Map<String, dynamic> j) => StudyPdf(
        id: j['id'],
        name: j['name'],
        path: j['path'],
      );
}

class StickyNote {
  StickyNote({
    required this.id,
    required this.title,
    required this.body,
    required this.colorIndex,
  });

  String id;
  String title;
  String body;
  int colorIndex;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'colorIndex': colorIndex,
      };

  factory StickyNote.fromJson(Map<String, dynamic> j) => StickyNote(
        id: j['id'],
        title: j['title'],
        body: j['body'],
        colorIndex: j['colorIndex'] ?? 0,
      );
}

class UserProfile {
  UserProfile({
    this.name = '',
    this.email = '',
    this.phone = '',
    this.institution = '',
  });

  String name;
  String email;
  String phone;
  String institution;

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'phone': phone,
        'institution': institution,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        name: j['name'] ?? '',
        email: j['email'] ?? '',
        phone: j['phone'] ?? '',
        institution: j['institution'] ?? '',
      );
}

class StudyHome extends StatefulWidget {
  const StudyHome({super.key});

  @override
  State<StudyHome> createState() => _StudyHomeState();
}

class _StudyHomeState extends State<StudyHome> {
  int tab = 0;
  bool loading = true;

  List<StudyNote> notes = [];
  List<StudyPdf> pdfs = [];
  List<StickyNote> stickyNotes = [];
  UserProfile profile = UserProfile();

  final stickyColors = [
    const Color(0xFFFEF3C7),
    const Color(0xFFDBEAFE),
    const Color(0xFFD1FAE5),
    const Color(0xFFFCE7F3),
    const Color(0xFFE0F2FE),
  ];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final p = await SharedPreferences.getInstance();

    try {
      notes = (jsonDecode(p.getString('notes') ?? '[]') as List)
          .map((e) => StudyNote.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      pdfs = (jsonDecode(p.getString('pdfs') ?? '[]') as List)
          .map((e) => StudyPdf.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      stickyNotes = (jsonDecode(p.getString('stickyNotes') ?? '[]') as List)
          .map((e) => StickyNote.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final profileJson = p.getString('profile');
      if (profileJson != null && profileJson.isNotEmpty) {
        profile = UserProfile.fromJson(
            jsonDecode(profileJson) as Map<String, dynamic>);
      }
    } catch (e) {
      print('Error loading data: $e');
      notes = [];
      pdfs = [];
      stickyNotes = [];
      profile = UserProfile();
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> saveData() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('notes', jsonEncode(notes.map((e) => e.toJson()).toList()));
    await p.setString('pdfs', jsonEncode(pdfs.map((e) => e.toJson()).toList()));
    await p.setString('stickyNotes', jsonEncode(stickyNotes.map((e) => e.toJson()).toList()));
    await p.setString('profile', jsonEncode(profile.toJson()));
  }

  String formatDate(DateTime d) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final period = d.hour >= 12 ? 'PM' : 'AM';
    return '${d.day} ${months[d.month - 1]} · $h:$minute $period';
  }

  Future<String?> pickAndImportPdf() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (picked == null || picked.files.isEmpty) return null;

    final file = picked.files.single;
    final appDir = await getApplicationDocumentsDirectory();
    final folder = Directory('${appDir.path}/study_pdfs');
    await folder.create(recursive: true);

    final safeName = '${DateTime.now().microsecondsSinceEpoch}_${file.name.replaceAll(RegExp(r"[^a-zA-Z0-9._-]"), "_")}';
    final destination = '${folder.path}/$safeName';

    if (file.bytes != null) {
      await File(destination).writeAsBytes(file.bytes!, flush: true);
    } else if (file.path != null) {
      await File(file.path!).copy(destination);
    } else {
      return null;
    }

    final pdf = StudyPdf(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: file.name,
      path: destination,
    );

    setState(() {
      pdfs.insert(0, pdf);
    });
    await saveData();

    return pdf.id;
  }

  Future<void> addItem({required String type}) async {
    final title = TextEditingController();
    final body = TextEditingController();
    final subject = TextEditingController();
    DateTime date = DateTime.now().add(const Duration(days: 1));
    TimeOfDay time = const TimeOfDay(hour: 9, minute: 0);
    String? selectedPdfId;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refreshDialog) => AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            type == 'exam' ? 'Add Exam' : type == 'assignment' ? 'Add Assignment' : 'Add Note',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: InputDecoration(labelText: type == 'note' ? 'Title' : 'Name', prefixIcon: const Icon(Icons.title_rounded)),
                ),
                const SizedBox(height: 12),
                if (type != 'note') ...[
                  TextField(
                    controller: subject,
                    decoration: const InputDecoration(labelText: 'Subject', prefixIcon: Icon(Icons.menu_book_rounded)),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_rounded, color: primaryColor),
                    title: const Text('Date'),
                    subtitle: Text('${date.day}/${date.month}/${date.year}'),
                    onTap: () async {
                      final picked = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime.now(), lastDate: DateTime(2100));
                      if (picked != null) refreshDialog(() => date = DateTime(picked.year, picked.month, picked.day));
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.access_time_rounded, color: primaryColor),
                    title: const Text('Time'),
                    subtitle: Text(time.format(ctx)),
                    onTap: () async {
                      final picked = await showTimePicker(context: ctx, initialTime: time);
                      if (picked != null) refreshDialog(() => time = picked);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildPdfAttachmentSection(
                    selectedPdfId: selectedPdfId,
                    onPickFromLibrary: () async {
                      if (pdfs.isEmpty) {
                        showDialog(
                          context: ctx,
                          builder: (dialogCtx) => AlertDialog(
                            backgroundColor: cardColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Text('No PDFs'),
                            content: const Text('First import some PDFs in the PDF Library tab.'),
                            actions: [TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('OK'))],
                          ),
                        );
                        return;
                      }

                      final picked = await showDialog<String>(
                        context: ctx,
                        builder: (dialogCtx) => AlertDialog(
                          backgroundColor: cardColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Text('Select PDF'),
                          content: SizedBox(
                            width: double.maxFinite,
                            child: ListView(
                              shrinkWrap: true,
                              children: [
                                ListTile(leading: const Icon(Icons.clear_rounded, color: textLight), title: const Text('None'), onTap: () => Navigator.pop(dialogCtx, '')),
                                const Divider(),
                                ...pdfs.map((pdf) => ListTile(
                                  leading: const Icon(Icons.picture_as_pdf_rounded, color: dangerColor),
                                  title: Text(pdf.name, overflow: TextOverflow.ellipsis),
                                  selected: selectedPdfId == pdf.id,
                                  onTap: () => Navigator.pop(dialogCtx, pdf.id),
                                )),
                              ],
                            ),
                          ),
                          actions: [TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel'))],
                        ),
                      );

                      if (picked != null) {
                        refreshDialog(() => selectedPdfId = picked.isEmpty ? null : picked);
                      }
                    },
                    onPickFromDevice: () async {
                      final pdfId = await pickAndImportPdf();
                      if (pdfId != null) refreshDialog(() => selectedPdfId = pdfId);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: body,
                  maxLines: type == 'note' ? 8 : 4,
                  minLines: type == 'note' ? 6 : 3,
                  decoration: const InputDecoration(labelText: 'Notes (optional)', alignLabelWithHint: true, prefixIcon: Icon(Icons.notes_rounded)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter a title')));
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: FilledButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != true || title.text.trim().isEmpty) return;

    final note = StudyNote(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title.text.trim(),
      body: body.text.trim(),
      subject: type != 'note' ? subject.text.trim() : null,
      due: type != 'note' ? DateTime(date.year, date.month, date.day, time.hour, time.minute) : null,
      pdfId: selectedPdfId,
      type: type,
    );

    setState(() { notes.insert(0, note); });
    await saveData();

    if (type != 'note' && note.due != null && note.due!.isAfter(DateTime.now())) {
      await ReminderService.schedule(note.id, note.title, note.due!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${type == 'exam' ? 'Exam' : 'Assignment'} saved with reminder'), backgroundColor: successColor));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${type == 'note' ? 'Note' : type == 'exam' ? 'Exam' : 'Assignment'} saved'), backgroundColor: primaryColor));
    }
  }

  Widget _buildPdfAttachmentSection({required String? selectedPdfId, required VoidCallback onPickFromLibrary, required VoidCallback onPickFromDevice}) {
    final hasSelectedPdf = selectedPdfId != null && pdfs.any((p) => p.id == selectedPdfId);
    final selectedPdf = hasSelectedPdf ? pdfs.firstWhere((p) => p.id == selectedPdfId) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Attach PDF', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textPrimary)),
        const SizedBox(height: 8),
        if (hasSelectedPdf && selectedPdf != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: primaryLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: primaryColor.withOpacity(0.3))),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf_rounded, color: dangerColor, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(selectedPdf.name, style: const TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 13), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: OutlinedButton.icon(onPressed: onPickFromLibrary, icon: const Icon(Icons.folder_rounded, size: 18), label: const Text('From Library', style: TextStyle(fontSize: 12)), style: OutlinedButton.styleFrom(foregroundColor: primaryColor, side: const BorderSide(color: primaryColor), padding: const EdgeInsets.symmetric(vertical: 10)))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: onPickFromDevice, icon: const Icon(Icons.upload_file_rounded, size: 18), label: const Text('From Device', style: TextStyle(fontSize: 12)), style: OutlinedButton.styleFrom(foregroundColor: secondaryColor, side: const BorderSide(color: secondaryColor), padding: const EdgeInsets.symmetric(vertical: 10)))),
          ],
        ),
      ],
    );
  }

  Future<void> deleteNote(StudyNote note) async {
    if (note.type != 'note' && note.due != null) await ReminderService.cancel(note.id);
    setState(() => notes.removeWhere((n) => n.id == note.id));
    await saveData();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted successfully'), backgroundColor: dangerColor));
  }

  Future<void> addStickyNote() async {
    final title = TextEditingController();
    final body = TextEditingController();
    int selectedColorIndex = 0;

    await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refreshDialog) => AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Sticky Note', style: TextStyle(fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Title', prefixIcon: Icon(Icons.label_rounded))),
                const SizedBox(height: 12),
                TextField(controller: body, maxLines: 3, decoration: const InputDecoration(labelText: 'Note', alignLabelWithHint: true, prefixIcon: Icon(Icons.edit_rounded))),
                const SizedBox(height: 16),
                const Text('Choose color:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(stickyColors.length, (index) {
                    return GestureDetector(
                      onTap: () => refreshDialog(() => selectedColorIndex = index),
                      child: Container(
                        width: 45, height: 45,
                        decoration: BoxDecoration(color: stickyColors[index], shape: BoxShape.circle, border: selectedColorIndex == index ? Border.all(color: primaryColor, width: 3) : null),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter a title')));
                  return;
                }
                setState(() {
                  stickyNotes.insert(0, StickyNote(id: DateTime.now().microsecondsSinceEpoch.toString(), title: title.text.trim(), body: body.text.trim(), colorIndex: selectedColorIndex));
                });
                saveData();
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> deleteStickyNote(StickyNote note) async {
    setState(() => stickyNotes.removeWhere((n) => n.id == note.id));
    await saveData();
  }

  Future<void> importPdf() async {
    final pdfId = await pickAndImportPdf();
    if (pdfId != null && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF imported'), backgroundColor: primaryColor));
  }

  Future<void> openPdf(StudyPdf pdf) async {
    if (!await File(pdf.path).exists()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF not found')));
      return;
    }
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => PdfScreen(title: pdf.name, path: pdf.path)));
  }

  Future<void> deletePdf(StudyPdf pdf) async {
    try { await File(pdf.path).delete(); } catch (_) {}
    setState(() => pdfs.removeWhere((e) => e.id == pdf.id));
    await saveData();
  }

  void viewNote(StudyNote note) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(gradient: LinearGradient(colors: [primaryColor, primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
                child: Row(
                  children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Icon(note.type == 'exam' ? Icons.school_rounded : note.type == 'assignment' ? Icons.assignment_rounded : Icons.sticky_note_2_rounded, color: Colors.white, size: 24)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(note.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                      if (note.subject != null && note.subject!.isNotEmpty) Text(note.subject!, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ])),
                    IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (note.due != null) ...[
                        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: note.due!.isBefore(DateTime.now()) ? dangerColor.withOpacity(0.1) : primaryLight, borderRadius: BorderRadius.circular(10)), child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.schedule_rounded, size: 16, color: note.due!.isBefore(DateTime.now()) ? dangerColor : primaryColor),
                          const SizedBox(width: 8),
                          Text(formatDate(note.due!), style: TextStyle(color: note.due!.isBefore(DateTime.now()) ? dangerColor : primaryColor, fontWeight: FontWeight.w600)),
                        ])),
                        const SizedBox(height: 16),
                      ],
                      if (note.body.isNotEmpty) ...[
                        const Text('Notes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textSecondary)),
                        const SizedBox(height: 8),
                        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)), child: Text(note.body, style: const TextStyle(fontSize: 15, color: textPrimary, height: 1.5))),
                        const SizedBox(height: 16),
                      ],
                      if (note.pdfId != null) ...[
                        const Text('Attached PDF', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textSecondary)),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () { Navigator.pop(ctx); final pdf = pdfs.firstWhere((p) => p.id == note.pdfId); openPdf(pdf); },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: primaryLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: primaryColor.withOpacity(0.3))), child: const Row(children: [Icon(Icons.picture_as_pdf_rounded, color: dangerColor, size: 20), SizedBox(width: 8), Text('View PDF', style: TextStyle(fontWeight: FontWeight.w600, color: primaryColor))])),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showNotifications() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(gradient: LinearGradient(colors: [secondaryColor, Color(0xFFFB923C)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 24)),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Notifications', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white))),
                  IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
                ]),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      if (notes.where((n) => n.due != null && n.due!.isAfter(DateTime.now())).isEmpty)
                        const Padding(padding: EdgeInsets.all(40), child: Column(children: [Icon(Icons.notifications_off_rounded, size: 60, color: textLight), SizedBox(height: 16), Text('No upcoming reminders', style: TextStyle(color: textSecondary))]))
                      else
                        ...notes.where((n) => n.due != null && n.due!.isAfter(DateTime.now())).take(5).map((note) => Container(
                          margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: primaryLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: primaryColor.withOpacity(0.2))),
                          child: Row(children: [
                            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.schedule_rounded, color: Colors.white, size: 18)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(note.title, style: const TextStyle(fontWeight: FontWeight.w700, color: textPrimary)), const SizedBox(height: 4), Text(formatDate(note.due!), style: const TextStyle(fontSize: 12, color: textSecondary))])),
                          ]),
                        )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showProfile() {
    final name = TextEditingController(text: profile.name);
    final email = TextEditingController(text: profile.email);
    final phone = TextEditingController(text: profile.phone);
    final institution = TextEditingController(text: profile.institution);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Dialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [successColor, Color(0xFF34D399)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
                  child: Row(children: [
                    CircleAvatar(radius: 30, backgroundColor: Colors.white.withOpacity(0.2), child: const Icon(Icons.person_rounded, color: Colors.white, size: 30)),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white))),
                    IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
                  ]),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      TextField(controller: name, decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person_rounded))),
                      const SizedBox(height: 12),
                      TextField(controller: email, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_rounded))),
                      const SizedBox(height: 12),
                      TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_rounded))),
                      const SizedBox(height: 12),
                      TextField(controller: institution, decoration: const InputDecoration(labelText: 'Institution', prefixIcon: Icon(Icons.school_rounded))),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            setState(() { profile.name = name.text.trim(); profile.email = email.text.trim(); profile.phone = phone.text.trim(); profile.institution = institution.text.trim(); });
                            saveData();
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved'), backgroundColor: successColor));
                          },
                          style: FilledButton.styleFrom(backgroundColor: successColor, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text('Save Profile'),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [homePage(), examsPage(), notesPage(), stickyNotesPage(), pdfPage()];

    return Scaffold(
      appBar: AppBar(
        title: const Text('StudyMate', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, color: textPrimary)),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_rounded, color: primaryColor), onPressed: showNotifications),
          IconButton(icon: const CircleAvatar(backgroundColor: primaryLight, child: Icon(Icons.person_rounded, color: primaryColor)), onPressed: showProfile),
          const SizedBox(width: 8),
        ],
      ),
      body: loading ? const Center(child: CircularProgressIndicator()) : SafeArea(child: pages[tab]),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (tab == 1) _showAddMenu(context);
          else if (tab == 2) addItem(type: 'note');
          else if (tab == 3) addStickyNote();
          else if (tab == 4) importPdf();
        },
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        backgroundColor: cardColor,
        indicatorColor: primaryLight,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.school_rounded), label: 'Exams'),
          NavigationDestination(icon: Icon(Icons.edit_note_rounded), label: 'Notes'),
          NavigationDestination(icon: Icon(Icons.sticky_note_2_rounded), label: 'Sticky'),
          NavigationDestination(icon: Icon(Icons.picture_as_pdf_rounded), label: 'PDFs'),
        ],
      ),
    );
  }

  void _showAddMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Add New', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: _buildMenuCard(icon: Icons.school_rounded, label: 'Exam', color: secondaryColor, onTap: () { Navigator.pop(ctx); addItem(type: 'exam'); })),
                const SizedBox(width: 12),
                Expanded(child: _buildMenuCard(icon: Icons.assignment_rounded, label: 'Assignment', color: warningColor, onTap: () { Navigator.pop(ctx); addItem(type: 'assignment'); })),
              ]),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
        child: Column(children: [Icon(icon, color: color, size: 40), const SizedBox(height: 8), Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color))]),
      ),
    );
  }

  Widget homePage() {
    final exams = notes.where((n) => n.type == 'exam').length;
    final assignments = notes.where((n) => n.type == 'assignment').length;
    final regularNotes = notes.where((n) => n.type == 'note').length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [primaryColor, primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Welcome back!', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            const Text('Ready to study?', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Row(children: [_buildStatChip('$exams', 'Exams'), const SizedBox(width: 8), _buildStatChip('$assignments', 'Tasks'), const SizedBox(width: 8), _buildStatChip('$regularNotes', 'Notes')]),
          ]),
        ),
        const SizedBox(height: 24),
        const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary)),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12,
          children: [
            _buildQuickAction(icon: Icons.school_rounded, label: 'Add Exam', color: secondaryColor, onTap: () => addItem(type: 'exam')),
            _buildQuickAction(icon: Icons.assignment_rounded, label: 'Add Task', color: warningColor, onTap: () => addItem(type: 'assignment')),
            _buildQuickAction(icon: Icons.edit_note_rounded, label: 'Add Note', color: successColor, onTap: () => addItem(type: 'note')),
            _buildQuickAction(icon: Icons.upload_file_rounded, label: 'Import PDF', color: primaryColor, onTap: importPdf),
          ],
        ),
      ],
    );
  }

  Widget _buildStatChip(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11))]),
    );
  }

  Widget _buildQuickAction({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
        ]),
      ),
    );
  }

  Widget examsPage() {
    final exams = notes.where((n) => n.type == 'exam' || n.type == 'assignment').toList()..sort((a, b) => (a.due ?? DateTime(2100)).compareTo(b.due ?? DateTime(2100)));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Exams & Assignments', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary)),
        const SizedBox(height: 16),
        if (exams.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(40), child: Column(children: [Icon(Icons.school_rounded, size: 60, color: textLight), SizedBox(height: 16), Text('No exams or assignments yet', style: TextStyle(color: textSecondary))])))
        else ...exams.map((note) => _buildExamCard(note)),
      ],
    );
  }

  Widget _buildExamCard(StudyNote note) {
    final isOverdue = note.due != null && note.due!.isBefore(DateTime.now());
    final hasPdf = note.pdfId != null && pdfs.any((p) => p.id == note.pdfId);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => viewNote(note),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: note.type == 'exam' ? secondaryColor.withOpacity(0.1) : warningColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(note.type == 'exam' ? Icons.school_rounded : Icons.assignment_rounded, color: note.type == 'exam' ? secondaryColor : warningColor)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(note.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: textPrimary)), if (note.subject != null && note.subject!.isNotEmpty) Text(note.subject!, style: const TextStyle(fontSize: 13, color: textSecondary))])),
              IconButton(icon: const Icon(Icons.delete_outline_rounded, color: textLight), onPressed: () => deleteNote(note)),
            ]),
            if (note.due != null) ...[
              const SizedBox(height: 12),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: isOverdue ? dangerColor.withOpacity(0.1) : primaryLight, borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.schedule_rounded, size: 14, color: isOverdue ? dangerColor : primaryColor), const SizedBox(width: 6), Text(formatDate(note.due!), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isOverdue ? dangerColor : primaryColor))])),
            ],
            if (hasPdf) ...[
              const SizedBox(height: 12),
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: primaryLight, borderRadius: BorderRadius.circular(10)), child: const Row(children: [Icon(Icons.picture_as_pdf_rounded, color: primaryColor, size: 18), SizedBox(width: 8), Text('PDF attached', style: TextStyle(fontWeight: FontWeight.w600, color: primaryColor, fontSize: 13))])),
            ],
          ]),
        ),
      ),
    );
  }

  Widget notesPage() {
    final regularNotes = notes.where((n) => n.type == 'note').toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Notes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary)),
        const SizedBox(height: 16),
        if (regularNotes.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(40), child: Column(children: [Icon(Icons.edit_note_rounded, size: 60, color: textLight), SizedBox(height: 16), Text('No notes yet', style: TextStyle(color: textSecondary))])))
        else ...regularNotes.map((note) => _buildNoteCard(note)),
      ],
    );
  }

  Widget _buildNoteCard(StudyNote note) {
    final hasPdf = note.pdfId != null && pdfs.any((p) => p.id == note.pdfId);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => viewNote(note),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: successColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.edit_note_rounded, color: successColor)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(note.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: textPrimary)),
              if (note.body.isNotEmpty) Text(note.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: textSecondary)),
              if (hasPdf) Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [const Icon(Icons.picture_as_pdf_rounded, color: dangerColor, size: 14), const SizedBox(width: 4), const Text('PDF attached', style: TextStyle(fontSize: 11, color: textSecondary))])),
            ])),
            IconButton(icon: const Icon(Icons.delete_outline_rounded, color: textLight), onPressed: () => deleteNote(note)),
          ]),
        ),
      ),
    );
  }

  Widget stickyNotesPage() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Sticky Notes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary)),
        const SizedBox(height: 16),
        if (stickyNotes.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(40), child: Column(children: [Icon(Icons.sticky_note_2_rounded, size: 60, color: textLight), SizedBox(height: 16), Text('No sticky notes yet', style: TextStyle(color: textSecondary))])))
        else ...stickyNotes.map((note) => _buildStickyNoteCard(note)),
      ],
    );
  }

  Widget _buildStickyNoteCard(StickyNote note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: stickyColors[note.colorIndex], borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(note.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: textPrimary))), IconButton(icon: const Icon(Icons.close_rounded, color: textSecondary), onPressed: () => deleteStickyNote(note))]),
        if (note.body.isNotEmpty) Text(note.body, style: const TextStyle(fontSize: 14, color: textPrimary, height: 1.4)),
      ]),
    );
  }

  Widget pdfPage() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('PDF Library', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary)),
        const SizedBox(height: 16),
        if (pdfs.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(40), child: Column(children: [Icon(Icons.picture_as_pdf_rounded, size: 60, color: textLight), SizedBox(height: 16), Text('No PDFs yet', style: TextStyle(color: textSecondary))])))
        else ...pdfs.map((pdf) => _buildPdfCard(pdf)),
      ],
    );
  }

  Widget _buildPdfCard(StudyPdf pdf) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: () => openPdf(pdf),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(12),
        leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: dangerColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.picture_as_pdf_rounded, color: dangerColor)),
        title: Text(pdf.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
        subtitle: const Text('Tap to open'),
        trailing: PopupMenuButton<String>(onSelected: (v) { if (v == 'delete') deletePdf(pdf); }, itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete'))]),
      ),
    );
  }
}

class PdfScreen extends StatelessWidget {
  const PdfScreen({super.key, required this.title, required this.path});
  final String title;
  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: PdfViewer.file(path),
    );
  }
}