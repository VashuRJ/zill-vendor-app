import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/ui_utils.dart';
import '../viewmodel/profile_viewmodel.dart';
import 'edit_profile_screen.dart';
import 'location_picker_screen.dart';

/// Full profile detail screen — clean MNC-style sections.
class ViewProfileScreen extends StatelessWidget {
  const ViewProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Restaurant Profile'),
      ),
      body: Consumer<ProfileViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading && !vm.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          final d = vm.data;
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: vm.fetchProfile,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                // ── Contact Details ────────────────────────────────
                _SectionCard(
                  title: 'Contact Details',
                  icon: Icons.contact_phone_outlined,
                  children: [
                    _DetailRow(
                      icon: Icons.store_outlined,
                      iconColor: AppColors.orange,
                      label: 'Restaurant Name',
                      value: d.storeName,
                    ),
                    _DetailRow(
                      icon: Icons.person_outline,
                      iconColor: AppColors.purple,
                      label: 'Owner Name',
                      value: d.ownerName,
                    ),
                    _DetailRow(
                      icon: Icons.email_outlined,
                      iconColor: AppColors.info,
                      label: 'Email',
                      value: d.email,
                      copyable: true,
                    ),
                    _DetailRow(
                      icon: Icons.phone_outlined,
                      iconColor: AppColors.success,
                      label: 'Phone',
                      value: d.phone,
                      copyable: true,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Location ───────────────────────────────────────
                _LocationCard(
                  address: d.address,
                  latitude: d.latitude,
                  longitude: d.longitude,
                ),
                const SizedBox(height: 12),

                // ── Restaurant Details ─────────────────────────────
                _SectionCard(
                  title: 'Restaurant Details',
                  icon: Icons.restaurant_outlined,
                  children: [
                    if (d.restaurantType.isNotEmpty)
                      _DetailRow(
                        icon: Icons.category_outlined,
                        iconColor: AppColors.purple,
                        label: 'Restaurant Type',
                        value: _formatType(d.restaurantType),
                      ),
                    if (d.cuisineTypes.isNotEmpty)
                      _DetailRow(
                        icon: Icons.restaurant_menu_outlined,
                        iconColor: AppColors.orange,
                        label: 'Cuisine Types',
                        value: d.cuisineTypes,
                      ),
                    if (d.description.isNotEmpty)
                      _DetailRow(
                        icon: Icons.info_outline,
                        iconColor: AppColors.teal,
                        label: 'Description',
                        value: d.description,
                      ),
                    if (d.costForTwo > 0)
                      _DetailRow(
                        icon: Icons.currency_rupee_outlined,
                        iconColor: AppColors.success,
                        label: 'Cost for Two',
                        value: '\u20B9${d.costForTwo.toStringAsFixed(0)}',
                      ),
                    if (d.averagePrepTime > 0)
                      _DetailRow(
                        icon: Icons.timer_outlined,
                        iconColor: AppColors.warning,
                        label: 'Avg. Preparation Time',
                        value: '${d.averagePrepTime} min',
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Operating Hours ────────────────────────────────
                _SectionCard(
                  title: 'Operating Hours',
                  icon: Icons.schedule_outlined,
                  children: [
                    if (d.openingTime.isNotEmpty || d.closingTime.isNotEmpty)
                      _DetailRow(
                        icon: Icons.access_time_outlined,
                        iconColor: AppColors.success,
                        label: 'Daily Hours',
                        value: _formatHours(d.openingTime, d.closingTime),
                      )
                    else
                      const _EmptyHint('Not set'),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Restaurant Tags ──────────────────────────────
                if (d.isPureVeg || d.costForTwo > 0)
                  _SectionCard(
                    title: 'Restaurant Tags',
                    icon: Icons.label_outline_rounded,
                    children: [
                      if (d.isPureVeg)
                        _ToggleRow(
                          icon: Icons.eco_outlined,
                          label: 'Pure Vegetarian',
                          value: d.isPureVeg,
                        ),
                      if (d.costForTwo > 0)
                        _DetailRow(
                          icon: Icons.currency_rupee_outlined,
                          iconColor: AppColors.success,
                          label: 'Cost for Two',
                          value: '\u20B9${d.costForTwo.toStringAsFixed(0)}',
                        ),
                    ],
                  ),
                if (d.isPureVeg || d.costForTwo > 0)
                  const SizedBox(height: 12),

                // ── Licences & Compliance ──────────────────────────
                _SectionCard(
                  title: 'Licences & Compliance',
                  icon: Icons.verified_user_outlined,
                  children: [
                    _DetailRow(
                      icon: Icons.verified_outlined,
                      iconColor: AppColors.success,
                      label: 'FSSAI License',
                      value: d.fssaiNumber,
                      placeholder: 'Not provided',
                      copyable: d.fssaiNumber.isNotEmpty,
                    ),
                    _DetailRow(
                      icon: Icons.receipt_long_outlined,
                      iconColor: AppColors.purple,
                      label: 'GST Number',
                      value: d.gstNumber,
                      placeholder: 'Not provided',
                      copyable: d.gstNumber.isNotEmpty,
                    ),
                    _DetailRow(
                      icon: Icons.badge_outlined,
                      iconColor: AppColors.info,
                      label: 'PAN Number',
                      value: d.panNumber,
                      placeholder: 'Not provided',
                      copyable: d.panNumber.isNotEmpty,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
      // ── Floating Edit Button ───────────────────────────────────────
      floatingActionButton: Consumer<ProfileViewModel>(
        builder: (context, vm, _) => vm.hasData
            ? FloatingActionButton.extended(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EditProfileScreen(),
                  ),
                ),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text(
                  'Edit Profile',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              )
            : const SizedBox.shrink(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  String _formatType(String type) {
    if (type.isEmpty) return '';
    return type
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  String _formatHours(String open, String close) {
    String fmt(String t) {
      if (t.isEmpty) return '--';
      try {
        final parts = t.split(':');
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final period = h >= 12 ? 'PM' : 'AM';
        final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
        return '$hour:${m.toString().padLeft(2, '0')} $period';
      } catch (_) {
        return t;
      }
    }
    return '${fmt(open)} – ${fmt(close)}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Section Card
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(icon, size: 15, color: AppColors.textHint),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ...children,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Detail Row — label + value
// ═══════════════════════════════════════════════════════════════════════════════

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String placeholder;
  final bool copyable;

  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.value = '',
    this.placeholder = '—',
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    final display = value.isNotEmpty ? value : placeholder;
    final isEmpty = value.isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  display,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isEmpty ? AppColors.textHint : AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (copyable && value.isNotEmpty)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                UIUtils.showSnackBar(
                  context,
                  message: '$label copied',
                  icon: Icons.check_circle,
                  duration: const Duration(seconds: 1),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Icon(
                  Icons.copy_rounded,
                  size: 14,
                  color: AppColors.textHint.withAlpha(150),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Toggle Row — shows Yes/No with colored dot (for boolean features)
// ═══════════════════════════════════════════════════════════════════════════════

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (value ? AppColors.success : AppColors.textHint)
                  .withAlpha(18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: value ? AppColors.success : AppColors.textHint,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  value ? 'Yes' : 'No',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: value ? AppColors.success : AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Empty hint
// ═══════════════════════════════════════════════════════════════════════════════

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          color: AppColors.textHint.withAlpha(180),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Location Card — address + coordinates + Set/Change on Map button
// ═══════════════════════════════════════════════════════════════════════════════

class _LocationCard extends StatelessWidget {
  final String address;
  final double? latitude;
  final double? longitude;

  const _LocationCard({
    required this.address,
    this.latitude,
    this.longitude,
  });

  @override
  Widget build(BuildContext context) {
    final hasCoords = latitude != null && longitude != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined, size: 15, color: AppColors.textHint),
                const SizedBox(width: 8),
                Text(
                  'LOCATION',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1, indent: 16, endIndent: 16),

          // Address
          _DetailRow(
            icon: Icons.location_on_outlined,
            iconColor: AppColors.error,
            label: 'Address',
            value: address,
          ),

          // Coordinates
          _DetailRow(
            icon: Icons.map_outlined,
            iconColor: AppColors.info,
            label: 'Coordinates',
            value: hasCoords
                ? '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}'
                : '',
            placeholder: 'Not set',
          ),

          // Set / Change on Map button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final initial = hasCoords
                      ? LatLng(latitude!, longitude!)
                      : null;

                  final result = await Navigator.push<LatLng>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          LocationPickerScreen(initialPosition: initial),
                    ),
                  );

                  if (result != null && context.mounted) {
                    final vm = context.read<ProfileViewModel>();
                    final d = vm.data;
                    final success = await vm.updateProfile(
                      name: d.storeName,
                      phone: d.phone,
                      email: d.email,
                      address: d.address,
                      latitude: result.latitude,
                      longitude: result.longitude,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? 'Location updated!'
                                : vm.errorMessage ?? 'Failed to update location.',
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor:
                              success ? AppColors.success : AppColors.error,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                    }
                  }
                },
                icon: Icon(
                  hasCoords
                      ? Icons.edit_location_alt_outlined
                      : Icons.add_location_alt_outlined,
                  size: 18,
                ),
                label: Text(hasCoords ? 'Change on Map' : 'Set on Map'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
