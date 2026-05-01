class SetupOnboardingState {
  const SetupOnboardingState({
    required this.uploadedRequiredDocuments,
    required this.totalRequiredDocuments,
    required this.documentsComplete,
    required this.subscriptionComplete,
    this.hasSubscription = false,
    this.subscriptionStatus,
    this.profileVerificationStatus,
    this.isProfileVerified,
  });

  final int uploadedRequiredDocuments;
  final int totalRequiredDocuments;
  final bool documentsComplete;
  final bool subscriptionComplete;
  final bool hasSubscription;
  final String? subscriptionStatus;
  final String? profileVerificationStatus;
  final bool? isProfileVerified;

  /// Setup is "complete enough" to enter the dashboard once required
  /// KYC documents are uploaded. Subscription used to be part of this
  /// gate, but admin occasionally pulls all plans offline (price /
  /// GST changes, cleanup) — when that happened the vendor was
  /// dead-stuck on the subscription screen with no plans to pick.
  /// Subscription is now treated as a soft prompt the vendor can act
  /// on later from Profile, never a hard gate.
  bool get isSetupComplete => documentsComplete;

  bool get isSubscriptionLocked => !documentsComplete;

  String get documentsProgressLabel =>
      '$uploadedRequiredDocuments/$totalRequiredDocuments uploaded';
}
