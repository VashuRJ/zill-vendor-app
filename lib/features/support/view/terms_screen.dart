import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Terms & Conditions',
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
                      color: AppColors.purple.withAlpha(18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.description_rounded,
                      size: 20,
                      color: AppColors.purple,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Terms of Service',
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
                title: '1. Acceptance of Terms',
                body: 'By accessing and using the Zill Vendor Partner App, you agree to '
                    'be bound by these Terms and Conditions. If you do not agree to these '
                    'terms, please do not use the app.',
              ),
              const _Section(
                title: '2. Vendor Registration',
                body: 'To use the app, you must register as a vendor partner by providing '
                    'accurate business information, including your restaurant name, address, '
                    'contact details, and required documents (FSSAI License, GST, PAN). '
                    'You are responsible for keeping your account information up to date.',
              ),
              const _Section(
                title: '3. Order Management',
                body: 'You agree to accept and process orders in a timely manner. Orders must '
                    'be prepared within the estimated preparation time. Repeated order '
                    'rejections or cancellations may result in account penalties or suspension.',
              ),
              const _Section(
                title: '4. Pricing & Payments',
                body: 'You are responsible for setting accurate menu prices. Zill charges a '
                    'platform commission on each order. Earnings will be settled to your '
                    'registered bank account as per the payout schedule. All prices must be '
                    'inclusive of applicable taxes.',
              ),
              const _Section(
                title: '5. Food Safety & Quality',
                body: 'You must maintain all required food safety certifications and comply '
                    'with local health regulations. Food must be prepared in hygienic conditions '
                    'and packed properly for delivery. Zill reserves the right to suspend '
                    'vendors who fail to meet quality standards.',
              ),
              const _Section(
                title: '6. Intellectual Property',
                body: 'All content, logos, and trademarks displayed on the Zill platform are '
                    'the property of Zill or its licensors. You may not use, reproduce, or '
                    'distribute any Zill intellectual property without prior written consent.',
              ),
              const _Section(
                title: '7. Account Suspension',
                body: 'Zill reserves the right to suspend or terminate your vendor account '
                    'for violations of these terms, including but not limited to: providing '
                    'false information, consistently poor food quality, customer safety '
                    'concerns, or fraudulent activity.',
              ),
              const _Section(
                title: '8. Limitation of Liability',
                body: 'Zill shall not be liable for any indirect, incidental, or consequential '
                    'damages arising from the use of the app. Our total liability shall not '
                    'exceed the amount of commissions earned by you in the preceding month.',
              ),
              const _Section(
                title: '9. Changes to Terms',
                body: 'Zill reserves the right to modify these terms at any time. Continued '
                    'use of the app after changes constitutes acceptance of the new terms. '
                    'We will notify you of significant changes via the app or email.',
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
