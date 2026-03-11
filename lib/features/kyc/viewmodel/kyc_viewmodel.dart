import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/api_service.dart';
import '../models/kyc_document.dart';

enum KycStatus { initial, loading, loaded, error }

/// Tracks upload progress for a specific document type.
class UploadProgress {
  final KycDocumentType type;
  final double progress; // 0.0 to 1.0
  final bool isUploading;

  const UploadProgress({
    required this.type,
    this.progress = 0.0,
    this.isUploading = false,
  });

  UploadProgress copyWith({double? progress, bool? isUploading}) {
    return UploadProgress(
      type: type,
      progress: progress ?? this.progress,
      isUploading: isUploading ?? this.isUploading,
    );
  }
}

class KycViewModel extends ChangeNotifier {
  final ApiService _api;

  KycViewModel({required ApiService apiService}) : _api = apiService;

  KycStatus _status = KycStatus.initial;
  String? _error;
  List<KycDocument> _documents = [];
  KycVerificationStatus? _verificationStatus;

  /// Per-document-type upload progress tracking
  final Map<KycDocumentType, UploadProgress> _uploadProgress = {};

  // ── Getters ──────────────────────────────────────────────────────
  KycStatus get status => _status;
  String? get error => _error;
  List<KycDocument> get documents => _documents;
  KycVerificationStatus? get verificationStatus => _verificationStatus;

  /// All 7 document types the vendor must provide.
  static const List<KycDocumentType> allDocumentTypes = [
    KycDocumentType.fssai,
    KycDocumentType.pan,
    KycDocumentType.gst,
    KycDocumentType.bank,
    KycDocumentType.shopLicense,
    KycDocumentType.ownerId,
    KycDocumentType.other,
  ];

  /// Returns the uploaded document for a given type, or null if not uploaded.
  KycDocument? documentFor(KycDocumentType type) {
    try {
      return _documents.firstWhere((d) => d.documentType == type);
    } catch (_) {
      return null;
    }
  }

  /// Returns the upload progress for a document type.
  UploadProgress? uploadProgressFor(KycDocumentType type) =>
      _uploadProgress[type];

  bool isUploading(KycDocumentType type) =>
      _uploadProgress[type]?.isUploading ?? false;

  /// True if any document type is currently mid-upload.
  bool get isAnyUploading =>
      _uploadProgress.values.any((p) => p.isUploading);

  // ── Fetch Documents ──────────────────────────────────────────────
  Future<void> fetchDocuments() async {
    _status = KycStatus.loading;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.get(ApiEndpoints.documents);
      final data = response.data as Map<String, dynamic>;

      final rawDocs = data['documents'] as List<dynamic>? ?? [];
      _documents = rawDocs
          .whereType<Map<String, dynamic>>()
          .map(KycDocument.fromJson)
          .toList();

      final rawStatus =
          data['verification_status'] as Map<String, dynamic>?;
      _verificationStatus = rawStatus != null
          ? KycVerificationStatus.fromJson(rawStatus)
          : null;

      _status = KycStatus.loaded;
      debugPrint(
        '[KYC] ${_documents.length} documents loaded, '
        'verified: ${_verificationStatus?.verified ?? 0}/'
        '${_verificationStatus?.totalRequired ?? 4}',
      );
    } on DioException catch (e) {
      _error = _parseError(e);
      _status = KycStatus.error;
      debugPrint('[KYC] fetchDocuments failed: ${e.response?.statusCode}');
    } catch (e, st) {
      _error = 'Unexpected error. Please try again.';
      _status = KycStatus.error;
      debugPrint('[KYC] unexpected: $e\n$st');
    }

    notifyListeners();
  }

  // ── Upload Document ──────────────────────────────────────────────
  /// Uploads a document with real-time progress tracking via Dio
  /// onSendProgress callback.
  Future<bool> uploadDocument({
    required KycDocumentType type,
    required String documentNumber,
    required String filePath,
    String? expiryDate,
  }) async {
    _uploadProgress[type] = UploadProgress(
      type: type,
      progress: 0.0,
      isUploading: true,
    );
    _error = null;
    notifyListeners();

    try {
      final fileName = filePath.split(Platform.pathSeparator).last;
      final fields = <String, dynamic>{
        'document_type': type.apiValue,
        'document_number': documentNumber,
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      };
      if (expiryDate != null) fields['expiry_date'] = expiryDate;
      final formData = FormData.fromMap(fields);

      await _api.dio.post(
        ApiEndpoints.documents,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
        onSendProgress: (sent, total) {
          if (total > 0) {
            _uploadProgress[type] = UploadProgress(
              type: type,
              progress: sent / total,
              isUploading: true,
            );
            notifyListeners();
          }
        },
      );

      _uploadProgress[type] = UploadProgress(
        type: type,
        progress: 1.0,
        isUploading: false,
      );
      notifyListeners();

      // Refresh the documents list
      await fetchDocuments();
      debugPrint('[KYC] uploaded ${type.apiValue}');
      return true;
    } on DioException catch (e) {
      _error = _parseError(e);
      _uploadProgress.remove(type);
      notifyListeners();
      debugPrint('[KYC] upload failed: ${e.response?.statusCode}');
      return false;
    } catch (e) {
      _error = 'Upload failed. Please try again.';
      _uploadProgress.remove(type);
      notifyListeners();
      return false;
    }
  }

  // ── Delete Document ──────────────────────────────────────────────
  Future<bool> deleteDocument(int docId) async {
    try {
      await _api.delete('${ApiEndpoints.documents}$docId/');
      await fetchDocuments();
      debugPrint('[KYC] deleted document $docId');
      return true;
    } on DioException catch (e) {
      _error = _parseError(e);
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Could not delete document.';
      notifyListeners();
      return false;
    }
  }

  // ── File Pickers ─────────────────────────────────────────────────
  //
  // ImagePicker handles camera & gallery permissions internally on
  // both Android and iOS. Manual Permission.camera.request() before
  // ImagePicker conflicts on many devices — so we let the plugin
  // manage its own permission flow and only catch PlatformException
  // to detect permanently-denied states.

  /// Pick image from camera. Returns file path, or null if cancelled/denied.
  /// Throws [PickerPermissionDeniedException] if permanently denied.
  Future<String?> pickFromCamera() async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1600,
      );
      return photo?.path;
    } on PlatformException catch (e) {
      if (e.code == 'camera_access_denied' ||
          e.code == 'photo_access_denied') {
        throw PickerPermissionDeniedException(e.code);
      }
      debugPrint('[KYC] Camera pick platform error: $e');
      return null;
    } catch (e) {
      debugPrint('[KYC] Camera pick failed: $e');
      return null;
    }
  }

  /// Pick image from gallery. Returns file path, or null if cancelled/denied.
  /// Throws [PickerPermissionDeniedException] if permanently denied.
  Future<String?> pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1600,
      );
      return photo?.path;
    } on PlatformException catch (e) {
      if (e.code == 'photo_access_denied') {
        throw PickerPermissionDeniedException(e.code);
      }
      debugPrint('[KYC] Gallery pick platform error: $e');
      return null;
    } catch (e) {
      debugPrint('[KYC] Gallery pick failed: $e');
      return null;
    }
  }

  /// Pick a PDF file. Returns file path or null if cancelled.
  Future<String?> pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );
      return result?.files.single.path;
    } catch (e) {
      debugPrint('[KYC] PDF pick failed: $e');
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Error parser ─────────────────────────────────────────────────
  String _parseError(DioException e) {
    if (e.response == null) return 'Cannot reach server.';
    final data = e.response!.data;
    if (data is Map<String, dynamic>) {
      if (data['message'] is String) return data['message'] as String;
      if (data['detail'] is String) return data['detail'] as String;
      if (data['error'] is String) return data['error'] as String;
    }
    return 'Error (HTTP ${e.response!.statusCode})';
  }
}

/// Thrown when ImagePicker/FilePicker detects the permission is permanently
/// denied. The UI should catch this and offer to open app settings.
class PickerPermissionDeniedException implements Exception {
  final String code;
  const PickerPermissionDeniedException(this.code);
  @override
  String toString() => 'PickerPermissionDeniedException($code)';
}
