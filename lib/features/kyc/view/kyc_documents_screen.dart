import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../models/kyc_document.dart';
import '../viewmodel/kyc_viewmodel.dart';

class KycDocumentsScreen extends StatefulWidget {
  const KycDocumentsScreen({super.key});

  @override
  State<KycDocumentsScreen> createState() => _KycDocumentsScreenState();
}

class _KycDocumentsScreenState extends State<KycDocumentsScreen> {
  static const _requiredTypes = [
    KycDocumentType.fssai,
    KycDocumentType.pan,
    KycDocumentType.gst,
    KycDocumentType.bank,
  ];

  static const _optionalTypes = [
    KycDocumentType.shopLicense,
    KycDocumentType.ownerId,
    KycDocumentType.other,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KycViewModel>().fetchDocuments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Selector<KycViewModel, bool>(
      selector: (_, vm) => vm.isAnyUploading,
      builder: (context, uploading, child) => PopScope(
        canPop: !uploading,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Please wait for the document upload to finish.',
                ),
                backgroundColor: AppColors.warning,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
              ),
            );
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Documents / KYC'),
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            elevation: 0.5,
          ),
          body: Consumer<KycViewModel>(
        builder: (context, vm, _) {
          if (vm.status == KycStatus.loading && vm.documents.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (vm.status == KycStatus.error && vm.documents.isEmpty) {
            return _ErrorView(
              message: vm.error ?? 'Something went wrong',
              onRetry: vm.fetchDocuments,
            );
          }
          return RefreshIndicator(
            onRefresh: vm.fetchDocuments,
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                // Verification summary card
                if (vm.verificationStatus != null)
                  _VerificationSummaryCard(status: vm.verificationStatus!),
                const SizedBox(height: AppSizes.md),

                // ── Required Documents ──
                const _SectionHeader(
                  title: 'Required Documents',
                  subtitle: 'These documents are mandatory for verification',
                ),
                const SizedBox(height: AppSizes.sm),
                ..._requiredTypes.map((type) => _buildDocCard(vm, type)),

                const SizedBox(height: AppSizes.lg),

                // ── Optional Documents ──
                const _SectionHeader(
                  title: 'Optional Documents',
                  subtitle: 'Upload these for faster verification',
                ),
                const SizedBox(height: AppSizes.sm),
                ..._optionalTypes.map((type) => _buildDocCard(vm, type)),

                const SizedBox(height: AppSizes.xl),
              ],
            ),
          );
        },
      ),
        ),
      ),
    );
  }

  Widget _buildDocCard(KycViewModel vm, KycDocumentType type) {
    final doc = vm.documentFor(type);
    final uploadProgress = vm.uploadProgressFor(type);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: _DocumentCard(
        documentType: type,
        document: doc,
        uploadProgress: uploadProgress,
        onUpload: () => _showUploadSheet(context, type, doc),
        onView: doc?.fileUrl != null ? () => _viewDocument(doc!) : null,
        onDelete: doc != null ? () => _confirmDelete(context, vm, doc) : null,
      ),
    );
  }

  Future<void> _viewDocument(KycDocument doc) async {
    var url = doc.fileUrl;
    if (url == null || url.isEmpty) return;

    // If relative path, prepend the domain
    if (url.startsWith('/')) {
      url = 'https://zill.co.in$url';
    }

    final uri = Uri.tryParse(url);
    if (uri == null) return;

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not open document'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
          ),
        );
      }
    }
  }

  void _confirmDelete(
    BuildContext context,
    KycViewModel vm,
    KycDocument doc,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        title: const Text('Delete Document'),
        content: Text(
          'Are you sure you want to delete ${doc.documentTypeDisplay.isNotEmpty ? doc.documentTypeDisplay : doc.documentType.displayName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await vm.deleteDocument(doc.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Document deleted'
                          : vm.error ?? 'Delete failed',
                    ),
                    backgroundColor:
                        success ? AppColors.success : AppColors.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    ),
                  ),
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUploadSheet(
    BuildContext context,
    KycDocumentType type,
    KycDocument? existing,
  ) {
    final numberController = TextEditingController(
      text: existing?.documentNumber ?? '',
    );
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusLg),
        ),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSizes.lg,
            right: AppSizes.lg,
            top: AppSizes.lg,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSizes.lg,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                Text(
                  existing != null
                      ? 'Re-upload ${type.displayName}'
                      : 'Upload ${type.displayName}',
                  style: const TextStyle(
                    fontSize: AppSizes.fontXl,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  type.description,
                  style: const TextStyle(
                    fontSize: AppSizes.fontSm,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                // Document number field
                TextFormField(
                  controller: numberController,
                  decoration: InputDecoration(
                    labelText: '${type.displayName} Number',
                    hintText: 'Enter document number',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: AppSizes.lg),
                // Source buttons
                Row(
                  children: [
                    Expanded(
                      child: _SourceButton(
                        icon: Icons.camera_alt_rounded,
                        label: 'Camera',
                        onTap: () => _handleFilePick(
                          context,
                          sheetContext,
                          type,
                          numberController,
                          formKey,
                          'camera',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: _SourceButton(
                        icon: Icons.photo_library_rounded,
                        label: 'Gallery',
                        onTap: () => _handleFilePick(
                          context,
                          sheetContext,
                          type,
                          numberController,
                          formKey,
                          'gallery',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: _SourceButton(
                        icon: Icons.picture_as_pdf_rounded,
                        label: 'PDF',
                        onTap: () => _handleFilePick(
                          context,
                          sheetContext,
                          type,
                          numberController,
                          formKey,
                          'pdf',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.sm),
                Center(
                  child: Text(
                    'Max file size: 5 MB',
                    style: TextStyle(
                      fontSize: AppSizes.fontXs,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleFilePick(
    BuildContext parentContext,
    BuildContext sheetContext,
    KycDocumentType type,
    TextEditingController numberController,
    GlobalKey<FormState> formKey,
    String source,
  ) async {
    if (!formKey.currentState!.validate()) return;

    final vm = parentContext.read<KycViewModel>();
    String? filePath;

    try {
      if (source == 'camera') {
        filePath = await vm.pickFromCamera();
      } else if (source == 'gallery') {
        filePath = await vm.pickFromGallery();
      } else {
        filePath = await vm.pickPdf();
      }
    } on PickerPermissionDeniedException {
      // Permission permanently denied — guide user to app settings
      if (sheetContext.mounted) {
        final label = source == 'camera' ? 'Camera' : 'Photos';
        _showPermissionDeniedDialog(sheetContext, label);
      }
      return;
    }

    // User cancelled (pressed back without selecting)
    if (filePath == null) return;

    // Close the bottom sheet
    if (sheetContext.mounted) {
      Navigator.of(sheetContext).pop();
    }

    // Start upload with progress
    final success = await vm.uploadDocument(
      type: type,
      documentNumber: numberController.text.trim(),
      filePath: filePath,
    );

    if (parentContext.mounted) {
      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '${type.displayName} uploaded successfully'
                : vm.error ?? 'Upload failed',
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
        ),
      );
    }
  }

  void _showPermissionDeniedDialog(BuildContext context, String permission) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        title: Text('$permission Permission Required'),
        content: Text(
          '$permission access has been permanently denied. '
          'Please enable it from your device settings to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text(
              'Open Settings',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _VerificationSummaryCard extends StatelessWidget {
  final KycVerificationStatus status;

  const _VerificationSummaryCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final progress = status.totalRequired > 0
        ? status.verified / status.totalRequired
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: status.isFullyVerified
              ? [AppColors.success, AppColors.success.withAlpha(200)]
              : [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                status.isFullyVerified
                    ? Icons.verified_rounded
                    : Icons.shield_outlined,
                color: Colors.white,
                size: AppSizes.iconLg,
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.isFullyVerified
                          ? 'Fully Verified'
                          : 'Verification In Progress',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: AppSizes.fontLg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${status.verified} of ${status.totalRequired} required documents verified',
                      style: TextStyle(
                        color: Colors.white.withAlpha(200),
                        fontSize: AppSizes.fontSm,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withAlpha(60),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final KycDocumentType documentType;
  final KycDocument? document;
  final UploadProgress? uploadProgress;
  final VoidCallback onUpload;
  final VoidCallback? onView;
  final VoidCallback? onDelete;

  const _DocumentCard({
    required this.documentType,
    this.document,
    this.uploadProgress,
    required this.onUpload,
    this.onView,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isUploaded = document != null;
    final isUploading = uploadProgress?.isUploading ?? false;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(
          color: _borderColor,
          width: document?.isRejected == true ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Row(
              children: [
                // Document icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _iconBgColor,
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  ),
                  child: Icon(
                    _iconData,
                    color: _iconColor,
                    size: AppSizes.iconMd,
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                // Name + status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              documentType.displayName,
                              style: const TextStyle(
                                fontSize: AppSizes.fontMd,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (documentType.isRequired) ...[
                            const SizedBox(width: AppSizes.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error.withAlpha(25),
                                borderRadius:
                                    BorderRadius.circular(AppSizes.xs),
                              ),
                              child: const Text(
                                'Required',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      if (isUploaded) ...[
                        _StatusBadge(status: document!.status),
                      ] else ...[
                        Text(
                          'Not uploaded',
                          style: TextStyle(
                            fontSize: AppSizes.fontSm,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Action button
                _ActionButton(
                  document: document,
                  isUploading: isUploading,
                  onTap: onUpload,
                ),
              ],
            ),
          ),

          // ── Uploaded file info row with View / Delete ──
          if (isUploaded && !isUploading)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.md, 0, AppSizes.md, AppSizes.sm,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.sm,
                  vertical: AppSizes.xs + 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isFilePdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                      size: 20,
                      color: _isFilePdf ? AppColors.error : AppColors.primary,
                    ),
                    const SizedBox(width: AppSizes.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (document!.documentNumber.isNotEmpty)
                            Text(
                              'No: ${document!.documentNumber}',
                              style: const TextStyle(
                                fontSize: AppSizes.fontSm,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          if (document!.expiryDate != null)
                            Text(
                              'Expires: ${_formatDate(document!.expiryDate!)}',
                              style: TextStyle(
                                fontSize: AppSizes.fontXs,
                                color: document!.isExpired
                                    ? AppColors.error
                                    : AppColors.textSecondary,
                              ),
                            ),
                          if (document!.documentNumber.isEmpty &&
                              document!.expiryDate == null)
                            const Text(
                              'Uploaded',
                              style: TextStyle(
                                fontSize: AppSizes.fontSm,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // View button
                    if (onView != null)
                      _IconActionButton(
                        icon: Icons.visibility_rounded,
                        color: AppColors.primary,
                        tooltip: 'View',
                        onTap: onView!,
                      ),
                    // Delete button
                    if (onDelete != null) ...[
                      const SizedBox(width: 4),
                      _IconActionButton(
                        icon: Icons.delete_outline_rounded,
                        color: AppColors.error,
                        tooltip: 'Delete',
                        onTap: onDelete!,
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // Rejection reason
          if (document?.isRejected == true &&
              document!.rejectionReason.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSizes.md,
                0,
                AppSizes.md,
                AppSizes.sm,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSizes.sm),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: AppSizes.xs),
                    Expanded(
                      child: Text(
                        document!.rejectionReason,
                        style: const TextStyle(
                          fontSize: AppSizes.fontSm,
                          color: AppColors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Upload progress bar
          if (isUploading)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.md,
                0,
                AppSizes.md,
                AppSizes.sm,
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                    child: LinearProgressIndicator(
                      value: uploadProgress?.progress ?? 0.0,
                      minHeight: 6,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    '${((uploadProgress?.progress ?? 0) * 100).toInt()}% uploading...',
                    style: const TextStyle(
                      fontSize: AppSizes.fontXs,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool get _isFilePdf {
    final url = document?.fileUrl ?? '';
    return url.toLowerCase().endsWith('.pdf');
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Color get _borderColor {
    if (document == null) return AppColors.border;
    switch (document!.status) {
      case KycDocStatus.verified:
        return AppColors.success;
      case KycDocStatus.rejected:
        return AppColors.error;
      case KycDocStatus.pending:
        return AppColors.warning;
    }
  }

  Color get _iconBgColor {
    if (document == null) return AppColors.background;
    switch (document!.status) {
      case KycDocStatus.verified:
        return AppColors.successLight;
      case KycDocStatus.rejected:
        return AppColors.errorLight;
      case KycDocStatus.pending:
        return AppColors.warningLight;
    }
  }

  Color get _iconColor {
    if (document == null) return AppColors.textHint;
    switch (document!.status) {
      case KycDocStatus.verified:
        return AppColors.success;
      case KycDocStatus.rejected:
        return AppColors.error;
      case KycDocStatus.pending:
        return AppColors.warning;
    }
  }

  IconData get _iconData {
    switch (documentType) {
      case KycDocumentType.fssai:
        return Icons.restaurant_menu_rounded;
      case KycDocumentType.gst:
        return Icons.receipt_long_rounded;
      case KycDocumentType.pan:
        return Icons.credit_card_rounded;
      case KycDocumentType.bank:
        return Icons.account_balance_rounded;
      case KycDocumentType.shopLicense:
        return Icons.storefront_rounded;
      case KycDocumentType.ownerId:
        return Icons.badge_rounded;
      case KycDocumentType.other:
        return Icons.description_rounded;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final KycDocStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSizes.xs),
        Text(
          _label,
          style: TextStyle(
            fontSize: AppSizes.fontSm,
            fontWeight: FontWeight.w500,
            color: _dotColor,
          ),
        ),
      ],
    );
  }

  Color get _dotColor {
    switch (status) {
      case KycDocStatus.verified:
        return AppColors.success;
      case KycDocStatus.rejected:
        return AppColors.error;
      case KycDocStatus.pending:
        return AppColors.warning;
    }
  }

  String get _label {
    switch (status) {
      case KycDocStatus.verified:
        return 'Verified';
      case KycDocStatus.rejected:
        return 'Rejected';
      case KycDocStatus.pending:
        return 'Pending Review';
    }
  }
}

class _ActionButton extends StatelessWidget {
  final KycDocument? document;
  final bool isUploading;
  final VoidCallback onTap;

  const _ActionButton({
    this.document,
    required this.isUploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isUploading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }

    // Not uploaded yet
    if (document == null) {
      return ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.upload_rounded, size: 18),
        label: const Text('Upload'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
          textStyle: const TextStyle(
            fontSize: AppSizes.fontSm,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    // Rejected → Re-Upload button (highly visible)
    if (document!.isRejected) {
      return ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('Re-Upload'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
          textStyle: const TextStyle(
            fontSize: AppSizes.fontSm,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    // Verified → checkmark
    if (document!.isVerified) {
      return Container(
        padding: const EdgeInsets.all(AppSizes.sm),
        decoration: BoxDecoration(
          color: AppColors.successLight,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_rounded,
          color: AppColors.success,
          size: 20,
        ),
      );
    }

    // Pending → "Uploaded" label with option to re-upload
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.warning,
        side: const BorderSide(color: AppColors.warning),
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
        textStyle: const TextStyle(
          fontSize: AppSizes.fontSm,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: const Text('Uploaded'),
    );
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: AppSizes.iconLg),
            const SizedBox(height: AppSizes.xs),
            Text(
              label,
              style: const TextStyle(
                fontSize: AppSizes.fontSm,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: AppSizes.fontLg,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: AppSizes.fontSm,
            color: AppColors.textHint,
          ),
        ),
      ],
    );
  }
}

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _IconActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppSizes.fontLg,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
