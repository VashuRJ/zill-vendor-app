/// Document types matching Django VendorDocument.DOCUMENT_TYPES
enum KycDocumentType {
  fssai,
  gst,
  pan,
  bank,
  shopLicense,
  ownerId,
  other;

  String get apiValue {
    switch (this) {
      case KycDocumentType.fssai:
        return 'fssai';
      case KycDocumentType.gst:
        return 'gst';
      case KycDocumentType.pan:
        return 'pan';
      case KycDocumentType.bank:
        return 'bank';
      case KycDocumentType.shopLicense:
        return 'shop_license';
      case KycDocumentType.ownerId:
        return 'owner_id';
      case KycDocumentType.other:
        return 'other';
    }
  }

  String get displayName {
    switch (this) {
      case KycDocumentType.fssai:
        return 'FSSAI License';
      case KycDocumentType.gst:
        return 'GST Certificate';
      case KycDocumentType.pan:
        return 'PAN Card';
      case KycDocumentType.bank:
        return 'Bank Cancelled Cheque';
      case KycDocumentType.shopLicense:
        return 'Shop License';
      case KycDocumentType.ownerId:
        return 'Aadhaar / Owner ID';
      case KycDocumentType.other:
        return 'Other Document';
    }
  }

  String get description {
    switch (this) {
      case KycDocumentType.fssai:
        return 'Food Safety and Standards Authority of India license';
      case KycDocumentType.gst:
        return 'Goods and Services Tax registration certificate';
      case KycDocumentType.pan:
        return 'Permanent Account Number card of business owner';
      case KycDocumentType.bank:
        return 'Cancelled cheque or bank statement for payouts';
      case KycDocumentType.shopLicense:
        return 'Municipal / trade license for your establishment';
      case KycDocumentType.ownerId:
        return 'Aadhaar card or government-issued photo ID';
      case KycDocumentType.other:
        return 'Any additional supporting document';
    }
  }

  bool get isRequired =>
      this == fssai || this == pan || this == bank || this == gst;

  static KycDocumentType fromApi(String value) {
    switch (value) {
      case 'fssai':
        return KycDocumentType.fssai;
      case 'gst':
        return KycDocumentType.gst;
      case 'pan':
        return KycDocumentType.pan;
      case 'bank':
        return KycDocumentType.bank;
      case 'shop_license':
        return KycDocumentType.shopLicense;
      case 'owner_id':
        return KycDocumentType.ownerId;
      default:
        return KycDocumentType.other;
    }
  }
}

/// Document verification status matching Django DOCUMENT_STATUS
enum KycDocStatus {
  pending,
  verified,
  rejected;

  static KycDocStatus fromApi(String value) {
    switch (value) {
      case 'verified':
        return KycDocStatus.verified;
      case 'rejected':
        return KycDocStatus.rejected;
      default:
        return KycDocStatus.pending;
    }
  }
}

class KycDocument {
  final int id;
  final KycDocumentType documentType;
  final String documentTypeDisplay;
  final String documentNumber;
  final String? fileUrl;
  final KycDocStatus status;
  final String statusDisplay;
  final String rejectionReason;
  final DateTime? expiryDate;
  final bool isExpired;
  final DateTime createdAt;
  final DateTime updatedAt;

  KycDocument({
    required this.id,
    required this.documentType,
    required this.documentTypeDisplay,
    required this.documentNumber,
    this.fileUrl,
    required this.status,
    required this.statusDisplay,
    required this.rejectionReason,
    this.expiryDate,
    required this.isExpired,
    required this.createdAt,
    required this.updatedAt,
  });

  factory KycDocument.fromJson(Map<String, dynamic> json) {
    return KycDocument(
      id: (json['id'] as num?)?.toInt() ?? 0,
      documentType:
          KycDocumentType.fromApi(json['document_type'] as String? ?? ''),
      documentTypeDisplay:
          json['document_type_display'] as String? ?? '',
      documentNumber: json['document_number'] as String? ?? '',
      fileUrl: json['file_url'] as String?,
      status: KycDocStatus.fromApi(json['status'] as String? ?? 'pending'),
      statusDisplay: json['status_display'] as String? ?? 'Pending Review',
      rejectionReason: json['rejection_reason'] as String? ?? '',
      expiryDate: _parseDate(json['expiry_date']),
      isExpired: json['is_expired'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  bool get isRejected => status == KycDocStatus.rejected;
  bool get isVerified => status == KycDocStatus.verified;
  bool get isPending => status == KycDocStatus.pending;
}

class KycVerificationStatus {
  final int totalRequired;
  final int uploaded;
  final int verified;
  final bool isFullyVerified;

  KycVerificationStatus({
    required this.totalRequired,
    required this.uploaded,
    required this.verified,
    required this.isFullyVerified,
  });

  factory KycVerificationStatus.fromJson(Map<String, dynamic> json) {
    return KycVerificationStatus(
      totalRequired: (json['total_required'] as num?)?.toInt() ?? 4,
      uploaded: (json['uploaded'] as num?)?.toInt() ?? 0,
      verified: (json['verified'] as num?)?.toInt() ?? 0,
      isFullyVerified: json['is_fully_verified'] as bool? ?? false,
    );
  }
}
