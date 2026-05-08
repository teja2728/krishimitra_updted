import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import 'url_service.dart';

/// Service to download PDF files from scheme URLs.
/// - Saves to the public Downloads folder (accessible from file manager)
/// - Requests runtime storage permissions on Android ≤12
/// - Verifies the file exists before showing success
/// - Offers Open / Share actions after download
class PdfDownloadService {
  PdfDownloadService._();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Download a PDF from [rawUrl] and save it to the device Downloads folder.
  /// Returns the saved [File] on success, null on failure.
  static Future<File?> downloadPdf({
    required String rawUrl,
    required String fileName,
    required ScaffoldMessengerState scaffoldMessenger,
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      // ── 1. Validate URL ───────────────────────────────────────────────────
      final url = UrlService.normalizeUrl(rawUrl);
      if (!UrlService.isValidUrl(url)) {
        _showError(scaffoldMessenger, 'Invalid download link.');
        return null;
      }

      // ── 2. Request storage permissions ───────────────────────────────────
      final permGranted = await _requestStoragePermission();
      if (!permGranted) {
        _showError(scaffoldMessenger,
            'Storage permission required to save PDF. Please grant it in app settings.');
        return null;
      }

      // ── 3. Show progress ─────────────────────────────────────────────────
      _showProgress(scaffoldMessenger, fileName);

      // ── 4. Fetch bytes ───────────────────────────────────────────────────
      dev.log('[PdfDownload] Starting download: $url');
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        scaffoldMessenger.hideCurrentSnackBar();
        _showError(scaffoldMessenger,
            'Download failed (HTTP ${response.statusCode})');
        return null;
      }

      if (response.bodyBytes.isEmpty) {
        scaffoldMessenger.hideCurrentSnackBar();
        _showError(scaffoldMessenger, 'Server returned an empty file.');
        return null;
      }

      // ── 5. Resolve Downloads directory ───────────────────────────────────
      final dir = await _getDownloadsDirectory();
      if (dir == null) {
        scaffoldMessenger.hideCurrentSnackBar();
        _showError(scaffoldMessenger, 'Could not access Downloads folder.');
        return null;
      }

      // ── 6. Write file ────────────────────────────────────────────────────
      final safeName = _sanitize(fileName);
      final file = File('${dir.path}/$safeName');
      await file.writeAsBytes(response.bodyBytes, flush: true);

      // ── 7. Verify file exists and is non-empty ───────────────────────────
      if (!await file.exists() || await file.length() == 0) {
        scaffoldMessenger.hideCurrentSnackBar();
        _showError(scaffoldMessenger, 'Failed to save PDF to device storage.');
        return null;
      }

      dev.log('[PdfDownload] Saved to: ${file.path}');

      // ── 8. Success snackbar with Open / Share ─────────────────────────────
      scaffoldMessenger.hideCurrentSnackBar();
      _showSuccess(scaffoldMessenger, safeName, file.path);

      return file;
    } catch (e) {
      dev.log('[PdfDownload] Error: $e');
      scaffoldMessenger.hideCurrentSnackBar();
      _showError(scaffoldMessenger,
          'Download failed: ${e.toString().replaceFirst('Exception: ', '')}');
      return null;
    }
  }

  // ── Open / Share helpers ───────────────────────────────────────────────────

  /// Open a PDF file using the device's default PDF viewer.
  static Future<void> openFile(String filePath) async {
    final result = await OpenFilex.open(filePath, type: 'application/pdf');
    dev.log('[PdfDownload] OpenFilex result: ${result.type} — ${result.message}');
  }

  /// Share a PDF file via the system share sheet.
  static Future<void> shareFile(String filePath, {String? subject}) async {
    await Share.shareXFiles(
      [XFile(filePath, mimeType: 'application/pdf')],
      subject: subject ?? 'KrishiMitra PDF Report',
    );
  }

  // ── Internal helpers ───────────────────────────────────────────────────────

  /// Request WRITE / READ external storage permission (Android ≤12).
  /// On Android 13+ scoped storage is used — no runtime permission needed.
  static Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    // Android 13+ (API 33+): no permission needed to write to Downloads via
    // MediaStore / Environment, but permission_handler still reports granted.
    final sdk = await _androidSdkVersion();
    if (sdk >= 33) return true;

    final status = await Permission.storage.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    return false;
  }

  /// Read android.os.Build.VERSION.SDK_INT without native channel calls.
  static Future<int> _androidSdkVersion() async {
    try {
      // Attempt to parse /proc/version or fall back conservatively.
      final result = await Process.run('getprop', ['ro.build.version.sdk']);
      return int.tryParse(result.stdout.toString().trim()) ?? 29;
    } catch (_) {
      return 29; // safe default — will request permission
    }
  }

  /// Get the public Downloads directory. Works on Android 5–14.
  static Future<Directory?> _getDownloadsDirectory() async {
    try {
      if (Platform.isAndroid) {
        // Primary: /storage/emulated/0/Download
        const downloadsPath = '/storage/emulated/0/Download';
        final dir = Directory(downloadsPath);
        if (await dir.exists()) return dir;

        // Fallback: derive from external storage path
        final extDirs = await getExternalStorageDirectories();
        if (extDirs != null && extDirs.isNotEmpty) {
          final root = extDirs.first.path.split('/Android').first;
          final fallback = Directory('$root/Download');
          if (await fallback.exists()) return fallback;
          return extDirs.first; // app-specific external dir
        }
      }
      // iOS / Desktop: use the documents directory
      return await getApplicationDocumentsDirectory();
    } catch (e) {
      dev.log('[PdfDownload] Directory error: $e');
      return await getApplicationDocumentsDirectory();
    }
  }

  /// Sanitize a filename — keep alphanumerics, hyphens, underscores, dots.
  static String _sanitize(String name) =>
      name.replaceAll(RegExp(r'[^\w\s\-.]'), '_');

  // ── Snackbar builders ──────────────────────────────────────────────────────

  static void _showProgress(
      ScaffoldMessengerState sm, String fileName) {
    sm.showSnackBar(SnackBar(
      content: Row(children: [
        const SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text('Downloading ${_sanitize(fileName)}…')),
      ]),
      duration: const Duration(seconds: 30),
    ));
  }

  static void _showSuccess(
      ScaffoldMessengerState sm, String fileName, String filePath) {
    sm.showSnackBar(SnackBar(
      backgroundColor: const Color(0xFF00C896),
      duration: const Duration(seconds: 6),
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text('Saved to Downloads: $fileName',
              style: const TextStyle(color: Colors.white)),
        ),
      ]),
      action: SnackBarAction(
        label: 'OPEN',
        textColor: Colors.white,
        onPressed: () => openFile(filePath),
      ),
    ));
  }

  static void _showError(ScaffoldMessengerState sm, String message) {
    sm.showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: Colors.redAccent,
      duration: const Duration(seconds: 5),
    ));
  }
}
