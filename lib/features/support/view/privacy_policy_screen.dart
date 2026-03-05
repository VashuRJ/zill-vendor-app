import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowLight,
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withAlpha(18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.privacy_tip_rounded,
                      size: 20,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Privacy Policy',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Last updated: March 2026',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const _Section(
                title: '1. Information We Collect',
                body: 'We collect the following information when you register and use the '
                    'Zill Vendor App:\n'
                    '- Personal information (name, email, phone number)\n'
                    '- Business information (restaurant name, address, FSSAI, GST, PAN)\n'
                    '- Bank account details for payouts\n'
                    '- Order and transaction history\n'
                    '- Device information and app usage data',
              ),
              const _Section(
                title: '2. How We Use Your Information',
                body: 'Your information is used to:\n'
                    '- Process and manage orders\n'
                    '- Process payments and payouts\n'
                    '- Verify your identity and business credentials\n'
                    '- Send order notifications and updates\n'
                    '- Improve our platform and services\n'
                    '- Comply with legal obligations',
              ),
              const _Section(
                title: '3. Data Sharing',
                body: 'We may share your information with:\n'
                    '- Customers (restaurant name, location, menu, ratings)\n'
                    '- Delivery partners (order details, pickup address)\n'
                    '- Payment processors (for transaction processing)\n'
                    '- Government authorities (when required by law)\n\n'
                    'We do not sell your personal data to third parties.',
              ),
              const _Section(
                title: '4. Data Security',
                body: 'We implement industry-standard security measures to protect your data, '
                    'including encryption, secure servers, and access controls. However, no '
                    'method of electronic transmission or storage is 100% secure.',
              ),
              const _Section(
                title: '5. Data Retention',
                body: 'We retain your data as long as your vendor account is active. After '
                    'account closure, we may retain certain data for up to 5 years for legal, '
                    'tax, and dispute resolution purposes.',
              ),
              const _Section(
                title: '6. Your Rights',
                body: 'You have the right to:\n'
                    '- Access your personal data\n'
                    '- Correct inaccurate information\n'
                    '- Request deletion of your account\n'
                    '- Opt out of marketing communications\n'
                    '- Download your data in a portable format',
              ),
              const _Section(
                title: '7. Cookies & Tracking',
                body: 'The app may use local storage and analytics tools to improve '
                    'performance and user experience. You can manage notification '
                    'preferences from the app settings.',
              ),
              const _Section(
                title: '8. Contact Us',
                body: 'For privacy-related questions or concerns, contact us at:\n'
                    'Email: support@zill.co.in\n'
                    'Website: zill.co.in',
                isLast: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  final bool isLast;

  const _Section({
    required this.title,
    required this.body,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
