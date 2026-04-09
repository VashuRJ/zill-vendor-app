// ─────────────────────────────────────────
// Zill Restaurant Partner — Vendor App
// Author: Vashu Mogha (@Its-vashu)
// ─────────────────────────────────────────
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_service.dart';

// ── Endpoints ────────────────────────────────────────────────────────
extension _BulkEndpoints on ApiEndpoints {
  static const String bulkUploadCsv = '/vendors/menu-items/bulk-upload-csv/';
  static const String bulkUploadTemplate =
      '/vendors/menu-items/bulk-upload-template/';
}

// ── ViewModel ────────────────────────────────────────────────────────
class BulkUploadViewModel extends ChangeNotifier {
  BulkUploadViewModel({required ApiService apiService})
    : _api = apiService;

  final ApiService _api;
  bool _isDisposed = false;

  // ── State ──────────────────────────────────────────────────────────
  bool _isLoading = false;
  double _uploadProgress = 0.0;
  PlatformFile? _selectedFile;
  String? _errorMessage;
  Map<String, dynamic>? _uploadResult;

  // ── Toggles ────────────────────────────────────────────────────────
  bool _clearExisting = false;
  bool _updateExisting = false;
  bool _autoFetchImages = false;

  // ── Getters ────────────────────────────────────────────────────────
  bool get isLoading => _isLoading;
  double get uploadProgress => _uploadProgress;
  PlatformFile? get selectedFile => _selectedFile;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get uploadResult => _uploadResult;

  bool get clearExisting => _clearExisting;
  bool get updateExisting => _updateExisting;
  bool get autoFetchImages => _autoFetchImages;

  bool get canUpload => !_isLoading && _selectedFile != null;

  // ── Notify guard ──────────────────────────────────────────────────
  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  // ── Toggle setters ────────────────────────────────────────────────
  void toggleClearExisting(bool v) {
    _clearExisting = v;
    _notify();
  }

  void toggleUpdateExisting(bool v) {
    _updateExisting = v;
    _notify();
  }

  void toggleAutoFetchImages(bool v) {
    _autoFetchImages = v;
    _notify();
  }

  // ── Clear file selection ──────────────────────────────────────────
  void clearFile() {
    _selectedFile = null;
    _uploadResult = null;
    _errorMessage = null;
    _uploadProgress = 0.0;
    _notify();
  }

  // ── Pick CSV file ─────────────────────────────────────────────────
  /// Max allowed file size: 5 MB.
  static const int _maxFileSizeBytes = 5 * 1024 * 1024;

  Future<void> pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
        withData: false, // stream from disk for large files
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;

      if (file.path == null) {
        _errorMessage = 'Could not access the selected file.';
        _notify();
        return;
      }

      // ── 5 MB size guard ──────────────────────────────────────────
      final size = file.size;
      if (size > _maxFileSizeBytes) {
        final sizeMb = (size / (1024 * 1024)).toStringAsFixed(1);
        _errorMessage =
            'File is too large ($sizeMb MB). Maximum allowed size is 5 MB.';
        _selectedFile = null;
        _notify();
        return;
      }

      _selectedFile = file;
      _uploadResult = null;
      _errorMessage = null;
      _notify();
    } catch (e) {
      _errorMessage = 'File picker error: $e';
      _notify();
    }
  }

  // ── Download template ─────────────────────────────────────────────
  Future<void> downloadTemplate() async {
    _isLoading = true;
    _errorMessage = null;
    _notify();

    try {
      final response = await _api.dio.get<List<int>>(
        _BulkEndpoints.bulkUploadTemplate,
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Empty response from server.');
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/menu_upload_template.csv');
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: 'Zill Menu Upload Template',
        ),
      );
    } on DioException catch (e) {
      _errorMessage = _parseDioError(e);
    } catch (e) {
      _errorMessage = 'Failed to download template: $e';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  // ── Upload CSV ────────────────────────────────────────────────────
  Future<void> uploadMenu() async {
    if (_selectedFile?.path == null) return;

    _isLoading = true;
    _uploadProgress = 0.0;
    _uploadResult = null;
    _errorMessage = null;
    _notify();

    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          _selectedFile!.path!,
          filename: _selectedFile!.name,
        ),
        'clear_existing': _clearExisting.toString(),
        'update_existing': _updateExisting.toString(),
        'auto_fetch_images': _autoFetchImages.toString(),
      });

      final response = await _api.dio.post(
        _BulkEndpoints.bulkUploadCsv,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
        onSendProgress: (sent, total) {
          if (total > 0 && !_isDisposed) {
            _uploadProgress = sent / total;
            _notify();
          }
        },
      );

      final body = response.data as Map<String, dynamic>?;
      if (body != null && body['success'] == true) {
        _uploadResult = body;
        _selectedFile = null; // reset after success
      } else {
        _errorMessage =
            body?['error']?.toString() ?? 'Upload failed. Please try again.';
      }
    } on DioException catch (e) {
      _errorMessage = _parseDioError(e);
    } catch (e) {
      _errorMessage = 'Unexpected error: $e';
    } finally {
      _isLoading = false;
      _uploadProgress = 0.0;
      _notify();
    }
  }

  // ── Error helpers ─────────────────────────────────────────────────
  String _parseDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please try again.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection.';
    }
    final data = e.response?.data;
    if (data is Map) {
      return data['error']?.toString() ??
          data['detail']?.toString() ??
          'Server error (${e.response?.statusCode}).';
    }
    return 'Server error (${e.response?.statusCode ?? 'unknown'}).';
  }

  void clearError() {
    _errorMessage = null;
    _notify();
  }
}
