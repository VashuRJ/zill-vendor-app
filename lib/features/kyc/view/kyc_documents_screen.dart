import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/routing/app_router.dart';
import '../../subscription/viewmodel/subscription_viewmodel.dart';
import '../models/kyc_document.dart';
import '../viewmodel/kyc_viewmodel.dart';

class KycDocumentsScreen extends StatefulWidget {
  const KycDocumentsScreen({super.key});

  @override
  State<KycDocumentsScreen> createState() => _KycDocumentsScreenState();
}

class _KycDocumentsScreenState extends State<KycDocumentsScreen> {
  // Required vs optional split mirrors the web vendor portal
  // (frontend_pages/vendor/documents.html → DOCUMENT_CONFIG). Only
  // four document types are exposed on web: fssai, gst, pan, bank.
  // Shop License / Aadhaar / Other have no upload path on web and
  // would write rows the verification flow can't process — so the
  // app must not surface them either.
  static const _requiredTypes = [
    KycDocumentType.fssai,
    KycDocumentType.pan,
    KycDocumentType.bank,
  ];

  static const _optionalTypes = [
    KycDocumentType.gst,
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
          // Persistent bottom CTA — gives vendors a clear "I'm done,
          // what's next?" signal after uploading required docs. Before
          // this, users hit Back and hoped the setup screen would know
          // they're done (Bug C from the in-the-wild feedback).
          bottomNavigationBar: Consumer<KycViewModel>(
            builder: (context, vm, _) => _ContinueToSubscriptionBar(vm: vm),
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
                      _VerificationSummaryCard(viewModel: vm),
                    const SizedBox(height: AppSizes.md),

                    // ── Info banner (mirrors the blue notice on the web) ──
                    const _KycInfoBanner(),
                    const SizedBox(height: AppSizes.md),

                    // ── Required Documents ──
                    const _SectionHeader(
                      title: 'Required Documents',
                      subtitle:
                          'These documents are mandatory for verification',
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

  void _confirmDelete(BuildContext context, KycViewModel vm, KycDocument doc) {
    final docName = doc.documentTypeDisplay.isNotEmpty
        ? doc.documentTypeDisplay
        : doc.documentType.displayName;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        title: const Text('Delete document?'),
        content: Text(
          'Delete the uploaded $docName file? You can upload a new one '
          'right after.',
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
                          ? 'Deleted. Tap Upload to add a new file.'
                          : vm.error ?? 'Delete failed',
                    ),
                    backgroundColor: success
                        ? AppColors.success
                        : AppColors.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    ),
                  ),
                );
                // Nudge the user straight into the upload sheet so the
                // next file is one tap away — they almost always want
                // to re-upload, so don't make them hunt for the button.
                if (success) {
                  _showUploadSheet(context, doc.documentType, null);
                }
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
    // Holder for the selected expiry date so it survives StatefulBuilder
    // rebuilds. Prefilled from the existing doc when re-uploading.
    DateTime? expiryDate = existing?.expiryDate;

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
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) => Padding(
            padding: EdgeInsets.only(
              left: AppSizes.lg,
              right: AppSizes.lg,
              top: AppSizes.lg,
              bottom:
                  MediaQuery.of(sheetContext).viewInsets.bottom + AppSizes.lg,
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
                  // Document number field — label & hint come from the
                  // type so each document asks for the right thing
                  // (e.g. "Account Number" for bank, not "Bank
                  // Cancelled Cheque Number"). Mirrors the web
                  // vendor portal's per-type config.
                  TextFormField(
                    controller: numberController,
                    decoration: InputDecoration(
                      labelText: type.numberFieldLabel,
                      hintText: type.numberFieldHint,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  // Expiry date — only for document types that carry one
                  // (FSSAI today). Mirrors the web vendor portal's
                  // `DOCUMENT_CONFIG[type].hasExpiry` field so uploads
                  // from app and web produce identical records.
                  if (type.hasExpiry) ...[
                    const SizedBox(height: AppSizes.md),
                    _ExpiryDateField(
                      value: expiryDate,
                      onPick: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: sheetContext,
                          initialDate: expiryDate ?? now,
                          firstDate: now.subtract(const Duration(days: 365)),
                          lastDate: DateTime(now.year + 20),
                          helpText: 'Select expiry date',
                        );
                        if (picked != null) {
                          setSheetState(() => expiryDate = picked);
                        }
                      },
                      onClear: expiryDate == null
                          ? null
                          : () => setSheetState(() => expiryDate = null),
                    ),
                  ],
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
                            expiryDate,
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
                            expiryDate,
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
                            expiryDate,
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
    DateTime? expiryDate,
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
      expiryDate: expiryDate != null ? _isoDate(expiryDate) : null,
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

  /// Backend `expiry_date` is a Django DateField — needs YYYY-MM-DD.
  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// Tap-to-pick expiry date row used in the upload bottom sheet. Looks
/// like a TextField but opens [showDatePicker] on tap. Optional Clear
/// button appears once a date is selected.
class _ExpiryDateField extends StatelessWidget {
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  const _ExpiryDateField({
    required this.value,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    final label = hasValue
        ? '${value!.day.toString().padLeft(2, '0')}/'
              '${value!.month.toString().padLeft(2, '0')}/'
              '${value!.year}'
        : 'Select expiry date';

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Expiry Date',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            borderSide: const BorderSide(
              color: AppColors.primary,
              width: 2,
            ),
          ),
          prefixIcon: const Icon(
            Icons.event_rounded,
            color: AppColors.textSecondary,
          ),
          suffixIcon: onClear != null
              ? IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                  tooltip: 'Clear date',
                  onPressed: onClear,
                )
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppSizes.fontMd,
            color: hasValue ? AppColors.textPrimary : AppColors.textHint,
            fontWeight: hasValue ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// White verification status card mirroring the web KYC page header.
/// Title on the left, status pill on the right, gradient progress bar
/// underneath, and a single-line subtitle explaining the count.
class _VerificationSummaryCard extends StatelessWidget {
  final KycViewModel viewModel;

  const _VerificationSummaryCard({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final status = viewModel.verificationStatus!;
    final progress = viewModel.requiredDocumentsUploadProgress;
    final uploaded = viewModel.uploadedRequiredDocumentCount;
    final total = viewModel.totalRequiredDocumentCount;

    final _SummaryTone tone = _toneFor(status, uploaded, total);

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Verification Status',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppSizes.fontLg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StatusPill(label: tone.label, color: tone.pillColor),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.borderLight,
              valueColor: AlwaysStoppedAnimation<Color>(tone.barColor),
            ),
          ),
          const SizedBox(height: AppSizes.xs + 2),
          Text(
            tone.subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppSizes.fontSm,
            ),
          ),
        ],
      ),
    );
  }

  _SummaryTone _toneFor(
    KycVerificationStatus status,
    int uploaded,
    int total,
  ) {
    if (status.isFullyVerified) {
      return const _SummaryTone(
        label: 'Verified',
        pillColor: AppColors.success,
        barColor: AppColors.success,
        subtitle: 'All documents verified',
      );
    }
    if (uploaded == 0) {
      return _SummaryTone(
        label: 'Pending',
        pillColor: AppColors.error,
        barColor: AppColors.error,
        subtitle: '$uploaded of $total required documents uploaded',
      );
    }
    if (uploaded < total) {
      return _SummaryTone(
        label: 'In Progress',
        pillColor: AppColors.warning,
        barColor: AppColors.warning,
        subtitle: '$uploaded of $total required documents uploaded',
      );
    }
    return _SummaryTone(
      label: 'Under Review',
      pillColor: AppColors.info,
      barColor: AppColors.info,
      subtitle: '$total documents under review',
    );
  }
}

class _SummaryTone {
  final String label;
  final Color pillColor;
  final Color barColor;
  final String subtitle;
  const _SummaryTone({
    required this.label,
    required this.pillColor,
    required this.barColor,
    required this.subtitle,
  });
}

/// Light info banner shown below the verification card on the KYC page.
/// Mirrors the blue info row on the web KYC layout.
class _KycInfoBanner extends StatelessWidget {
  const _KycInfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.info.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.info,
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              'Upload all required documents for verification. Your '
              'restaurant will be activated once all documents are '
              'verified by our team.',
              style: TextStyle(
                fontSize: AppSizes.fontSm,
                color: AppColors.info.withAlpha(220),
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Filled rounded pill — used for both the summary card and individual
/// document cards. Soft tinted background + bold colored label.
class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
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
    final isRejected = document?.isRejected == true;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        // Border stays neutral except for rejected documents — matches the
        // soft "all-cards-look-the-same" aesthetic of the web layout.
        border: Border.all(
          color: isRejected ? AppColors.error : AppColors.border,
          width: isRejected ? 1.5 : 1.0,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Document icon — neutral tinted square; no status colour.
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  ),
                  child: Icon(
                    _iconData,
                    color: AppColors.primary,
                    size: AppSizes.iconMd,
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                // Title + description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        documentType.displayName,
                        style: const TextStyle(
                          fontSize: AppSizes.fontMd,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        documentType.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppSizes.fontXs + 1,
                          color: AppColors.textHint,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.xs),
                // Top-right pill — status if uploaded, "Upload" CTA otherwise.
                if (isUploading)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                else if (isRejected)
                  _ReUploadPillButton(onTap: onUpload)
                else if (isUploaded)
                  _StatusPill(
                    label: _statusLabel(document!.status),
                    color: _statusColor(document!.status),
                  )
                else
                  _UploadPillButton(onTap: onUpload),
              ],
            ),
          ),

          // ── Uploaded file info row with View / Delete ──
          if (isUploaded && !isUploading)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.md,
                0,
                AppSizes.md,
                AppSizes.sm,
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
                      _isFilePdf
                          ? Icons.picture_as_pdf_rounded
                          : Icons.image_rounded,
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
                    // View / Delete — plain Material icon buttons.
                    // Vendors found the earlier styled chips confusing;
                    // a clean eye + trash pair is universally
                    // understood and keeps the row uncluttered.
                    if (onView != null)
                      IconButton(
                        onPressed: onView,
                        icon: const Icon(Icons.visibility_outlined),
                        color: AppColors.textSecondary,
                        iconSize: 20,
                        tooltip: 'View',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 36,
                          height: 36,
                        ),
                      ),
                    if (onDelete != null)
                      IconButton(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: AppColors.error,
                        iconSize: 20,
                        tooltip: 'Delete',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 36,
                          height: 36,
                        ),
                      ),
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

  String _statusLabel(KycDocStatus status) {
    switch (status) {
      case KycDocStatus.verified:
        return 'Verified';
      case KycDocStatus.rejected:
        return 'Rejected';
      case KycDocStatus.pending:
        return 'Under Review';
    }
  }

  Color _statusColor(KycDocStatus status) {
    switch (status) {
      case KycDocStatus.verified:
        return AppColors.success;
      case KycDocStatus.rejected:
        return AppColors.error;
      case KycDocStatus.pending:
        return AppColors.info;
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

/// Filled "Upload" pill — shown on a fresh, never-uploaded document card.
/// Compact rounded button so it sits next to the `_StatusPill` slot.
class _UploadPillButton extends StatelessWidget {
  final VoidCallback onTap;
  const _UploadPillButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.upload_rounded, size: 14, color: Colors.white),
            SizedBox(width: 4),
            Text(
              'Upload',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact "Re-Upload" pill — shown on a rejected document card so the
/// re-upload action stays discoverable without bringing back loud red
/// buttons or borders.
class _ReUploadPillButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ReUploadPillButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh_rounded, size: 14, color: Colors.white),
            SizedBox(width: 4),
            Text(
              'Re-Upload',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
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


/// Persistent bottom bar that makes the "next step" obvious after
/// uploading required KYC documents. Three states:
///  • No required doc uploaded yet → hide entirely (no nagging).
///  • Some required uploaded → show progress ("2 of 4 uploaded").
///  • All required uploaded → enable primary CTA "Continue to
///    Subscription" that navigates directly to the subscription plans
///    screen (no back-and-forth through the Setup Onboarding screen).
/// Smart "Continue" bar at the bottom of the KYC docs screen.
///
/// Why stateful: the destination of the Continue button is decided at
/// tap-time by asking the backend whether any active subscription
/// plans exist. When admin temporarily disables every plan (price /
/// GST resets, cleanup), we don't want the vendor to end up on a
/// blank Subscription Plans screen — and we don't want to ship an
/// app update every time the plan list is toggled. So:
///   • Plans available → push /subscription-plans (normal flow)
///   • No plans       → push /home (skip the dead gate)
/// The check uses the existing SubscriptionViewModel.fetchPlans() so
/// no extra wiring; we just key off the resulting `vm.plans` length.
class _ContinueToSubscriptionBar extends StatefulWidget {
  final KycViewModel vm;
  const _ContinueToSubscriptionBar({required this.vm});

  @override
  State<_ContinueToSubscriptionBar> createState() =>
      _ContinueToSubscriptionBarState();
}

class _ContinueToSubscriptionBarState
    extends State<_ContinueToSubscriptionBar> {
  bool _checking = false;

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final uploaded = vm.uploadedRequiredDocumentCount;
    final total = vm.totalRequiredDocumentCount;

    // Don't crowd a fresh screen — hide until at least one upload.
    if (uploaded == 0) return const SizedBox.shrink();

    // Already-approved vendors who reopen this screen from Profile
    // aren't in the onboarding flow — nudging them to Subscription
    // would be nonsense (they already have one). Let them browse docs
    // in peace.
    if (vm.verificationStatus?.isFullyVerified == true) {
      return const SizedBox.shrink();
    }

    final allUploaded = total > 0 && uploaded >= total;
    final canTap = allUploaded && !_checking;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.md,
          AppSizes.sm,
          AppSizes.md,
          AppSizes.sm,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.borderLight, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 12,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!allUploaded) ...[
              Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$uploaded of $total required documents uploaded — '
                      'upload the rest to continue.',
                      style: const TextStyle(
                        fontSize: AppSizes.fontSm,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canTap ? _continue : null,
                icon: _checking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Icon(
                        allUploaded
                            ? Icons.arrow_forward_rounded
                            : Icons.lock_outline_rounded,
                        size: 18,
                      ),
                label: Text(
                  _checking
                      ? 'Please wait…'
                      : allUploaded
                      ? 'Continue'
                      : 'Upload all required documents',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: allUploaded
                      ? AppColors.primary
                      : const Color(0xFFE2E5E8),
                  foregroundColor: allUploaded
                      ? Colors.white
                      : AppColors.textSecondary,
                  textStyle: const TextStyle(
                    fontSize: AppSizes.fontLg,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _continue() async {
    setState(() => _checking = true);

    // Ask the backend whether any plan rows are active right now. We
    // route the vendor based on the answer instead of hardcoding a
    // destination — that way admin can disable / re-enable plans
    // without an app release. If the call itself fails (offline,
    // 5xx), we fall through to the subscription screen, which has
    // its own empty-state escape hatch (and a Retry button).
    final subVm = context.read<SubscriptionViewModel>();
    bool plansAvailable = true;
    try {
      await subVm.fetchPlans();
      plansAvailable = subVm.plans.isNotEmpty;
    } catch (_) {
      plansAvailable = true; // be conservative — let the next screen handle it
    }

    if (!mounted) return;
    setState(() => _checking = false);

    if (plansAvailable) {
      // Replace KYC with subscription so swipe-back doesn't loop the
      // vendor backward through onboarding.
      await Navigator.of(
        context,
      ).pushReplacementNamed(AppRouter.subscriptionPlans);
    } else {
      // No plans → skip the gate and drop the vendor straight on the
      // dashboard, clearing the back stack so they can't swipe-back
      // into a half-finished onboarding flow.
      await Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/home', (route) => false);
    }
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
