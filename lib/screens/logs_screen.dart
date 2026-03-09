import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/transcript_log_service.dart';
import '../theme/app_theme.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final TranscriptLogService _logService = TranscriptLogService();
  List<File> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    // Cleanup old logs on open (30-day expiry)
    await _logService.cleanupOldLogs(maxAgeDays: 30);
    final logs = await _logService.getLogs();
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _loading = false;
    });
  }

  Future<void> _deleteLog(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete log?',
            style: TextStyle(color: AppColors.textNormal)),
        content: Text(
          _formatFilename(file),
          style: const TextStyle(color: AppColors.greyLight, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL',
                style: TextStyle(color: AppColors.greyLight)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE',
                style: TextStyle(color: AppColors.snaponRed)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _logService.deleteLog(file);
      await _loadLogs();
    }
  }

  Future<void> _deleteAll() async {
    if (_logs.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete all logs?',
            style: TextStyle(color: AppColors.textNormal)),
        content: Text(
          '${_logs.length} session log${_logs.length == 1 ? '' : 's'} will be permanently deleted.',
          style: const TextStyle(color: AppColors.greyLight, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL',
                style: TextStyle(color: AppColors.greyLight)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE ALL',
                style: TextStyle(color: AppColors.snaponRed)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      for (final log in List.from(_logs)) {
        await _logService.deleteLog(log);
      }
      await _loadLogs();
    }
  }

  void _viewLog(File file) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _LogViewScreen(file: file)),
    );
  }

  /// Parse a display name from the filename. e.g. session_2026-03-09_14-30-00.txt
  String _formatFilename(File file) {
    final name = file.uri.pathSegments.last;
    final match = RegExp(r'session_(\d{4}-\d{2}-\d{2})_(\d{2}-\d{2}-\d{2})')
        .firstMatch(name);
    if (match == null) return name;
    final datePart = match.group(1)!;
    final timePart = match.group(2)!.replaceAll('-', ':');
    return '$datePart  $timePart';
  }

  Future<String> _fileSize(File file) async {
    final bytes = await file.length();
    if (bytes < 1024) return '${bytes}B';
    return '${(bytes / 1024).toStringAsFixed(1)}KB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('SESSION LOGS'),
        actions: [
          if (_logs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined,
                  color: AppColors.snaponRed),
              onPressed: _deleteAll,
              tooltip: 'Delete all logs',
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.catYellow))
          : _logs.isEmpty
              ? _EmptyState()
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        children: [
                          Text(
                            '${_logs.length} session${_logs.length == 1 ? '' : 's'}  ·  Logs expire after 30 days',
                            style: const TextStyle(
                              color: AppColors.greyLight,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        itemCount: _logs.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 6),
                        itemBuilder: (context, i) {
                          final file = _logs[i];
                          return _LogTile(
                            file: file,
                            label: _formatFilename(file),
                            onTap: () => _viewLog(file),
                            onDelete: () => _deleteLog(file),
                            fileSizeFuture: _fileSize(file),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final File file;
  final String label;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Future<String> fileSizeFuture;

  const _LogTile({
    required this.file,
    required this.label,
    required this.onTap,
    required this.onDelete,
    required this.fileSizeFuture,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.grey),
        ),
        child: Row(
          children: [
            const Icon(Icons.description_outlined,
                color: AppColors.catYellow, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textNormal,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FutureBuilder<String>(
                    future: fileSizeFuture,
                    builder: (_, snap) => Text(
                      snap.data ?? '—',
                      style: const TextStyle(
                        color: AppColors.greyLight,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.greyLight, size: 20),
              onPressed: onDelete,
              tooltip: 'Delete',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                color: AppColors.greyLight, size: 20),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open_outlined,
              color: AppColors.grey, size: 56),
          SizedBox(height: 16),
          Text(
            'NO SESSION LOGS',
            style: TextStyle(
              color: AppColors.greyLight,
              fontSize: 14,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Enable transcript logging in Settings\nto save session records.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Log viewer ─────────────────────────────────────────────────────────────

class _LogViewScreen extends StatefulWidget {
  final File file;
  const _LogViewScreen({required this.file});

  @override
  State<_LogViewScreen> createState() => _LogViewScreenState();
}

class _LogViewScreenState extends State<_LogViewScreen> {
  String? _content;

  @override
  void initState() {
    super.initState();
    widget.file.readAsString().then((s) {
      if (mounted) setState(() => _content = s);
    });
  }

  String get _title {
    final name = widget.file.uri.pathSegments.last;
    final match = RegExp(r'session_(\d{4}-\d{2}-\d{2})_(\d{2}-\d{2}-\d{2})')
        .firstMatch(name);
    if (match == null) return name;
    return '${match.group(1)}  ${match.group(2)!.replaceAll('-', ':')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_title)),
      body: _content == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.catYellow))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                _content!,
                style: const TextStyle(
                  color: AppColors.textNormal,
                  fontSize: 13,
                  fontFamily: 'monospace',
                  height: 1.6,
                ),
              ),
            ),
    );
  }
}
