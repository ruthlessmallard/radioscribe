import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/segment.dart';

class TranscriptLogService {
  File? _logFile;
  bool _active = false;

  Future<void> startSession() async {
    final dir = await getApplicationDocumentsDirectory();
    final logsDir = Directory('${dir.path}/radioscribe_logs');
    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }
    final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    _logFile = File('${logsDir.path}/session_$timestamp.txt');
    await _logFile!.writeAsString(
      '╔═══════════════════════════════════════════════════════════╗\n'
      '║                                                           ║\n'
      '║    ___    _   ___ ___ ___  ___  ___ ___ ___ ___ ___       ║\n'
      '║    | _ \\  /_\\ |   \\_ _/ _ \\  / __|/ __| _ \\_ _| _ ) __|   ║\n'
      '║    |   / / _ \\| |) | | (_) |  \\__ \\ (__|   /| || _ \\ _|   ║\n'
      '║    |_|_\\/_/ \\_\\___/___\\___/  |___/\\___|_|_\\___|___/___|   ║\n'
      '║                                                           ║\n'
      '║    MINE RADIO MONITOR  ·  SESSION LOG                     ║\n'
      '║                                                           ║\n'
      '╚═══════════════════════════════════════════════════════════╝\n'
      '\n'
      'Started : ${DateTime.now().toIso8601String()}\n'
      '\n',
    );
    _active = true;
  }

  Future<void> logSegment(TranscriptSegment segment) async {
    if (!_active || _logFile == null) return;
    final time = DateFormat('HH:mm:ss').format(segment.timestamp);
    final alertTag = segment.alert == SegmentAlert.safety
        ? '[SAFETY] '
        : segment.alert == SegmentAlert.warning
            ? '[WARNING] '
            : '';
    await _logFile!.writeAsString(
      '[$time] $alertTag${segment.text}\n',
      mode: FileMode.append,
    );
  }

  Future<void> endSession() async {
    if (!_active || _logFile == null) return;
    await _logFile!.writeAsString(
      '\nEnded   : ${DateTime.now().toIso8601String()}\n'
      '─────────────────────────────────────────────────────────────\n',
      mode: FileMode.append,
    );
    _active = false;
    _logFile = null;
  }

  Future<List<File>> getLogs() async {
    final dir = await getApplicationDocumentsDirectory();
    final logsDir = Directory('${dir.path}/radioscribe_logs');
    if (!await logsDir.exists()) return [];
    final files = await logsDir.list().where((e) => e is File).cast<File>().toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  /// Delete a single log file.
  Future<void> deleteLog(File file) async {
    if (await file.exists()) await file.delete();
  }

  /// Delete all log files older than [maxAgeDays] days.
  Future<int> cleanupOldLogs({int maxAgeDays = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: maxAgeDays));
    final logs = await getLogs();
    int removed = 0;
    for (final file in logs) {
      final stat = await file.stat();
      if (stat.modified.isBefore(cutoff)) {
        await file.delete();
        removed++;
      }
    }
    return removed;
  }
}
