import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/data_backup_service.dart';
import '../../../shared/providers/database_provider.dart';

class DataBackupScreen extends ConsumerStatefulWidget {
  const DataBackupScreen({super.key});

  @override
  ConsumerState<DataBackupScreen> createState() => _DataBackupScreenState();
}

class _DataBackupScreenState extends ConsumerState<DataBackupScreen> {
  bool busy = false;

  Future<void> _backup() async {
    setState(() => busy = true);
    try {
      final name =
          'noma-backup-${DateFormat('yyyyMMdd-HHmmss').format(DateTime.now())}.json';
      final file = File(p.join((await getTemporaryDirectory()).path, name));
      await DataBackupService(ref.read(databaseProvider)).exportToFile(file);
      await Share.shareXFiles([XFile(file.path)], text: 'Backup data Noma');
    } catch (_) {
      _message('Gagal membuat backup. Coba lagi.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _restore() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    setState(() => busy = true);
    try {
      final service = DataBackupService(ref.read(databaseProvider));
      final preview = await service.prepareRestore(File(path));
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Pulihkan Backup?'),
          content: Text(
            '${preview.newTransactions} transaksi baru, ${preview.skippedTransactions} sudah ada, '
            '${preview.newCategories} kategori baru.\n\n'
            'Data yang ada tetap tersimpan. Foto struk tidak ikut dalam backup.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Pulihkan'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final result = await service.restore(preview);
      _message(
        '${result.added} transaksi dipulihkan; ${result.skipped} dilewati.',
      );
    } on FormatException catch (e) {
      _message(e.message);
    } catch (_) {
      _message('Gagal memulihkan backup. Data sebelumnya tetap tersimpan.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Data & Backup')),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Simpan salinan transaksi dan item struk sebagai file JSON. Simpan file ini di tempat yang aman.',
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: busy ? null : _backup,
            icon: const Icon(Icons.file_upload_outlined),
            label: const Text('Buat Backup'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy ? null : _restore,
            icon: const Icon(Icons.file_download_outlined),
            label: const Text('Import Backup'),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    ),
  );
}
