import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../viewmodel/delivery_zone_viewmodel.dart';

class DeliveryZonesScreen extends StatefulWidget {
  const DeliveryZonesScreen({super.key});

  @override
  State<DeliveryZonesScreen> createState() => _DeliveryZonesScreenState();
}

class _DeliveryZonesScreenState extends State<DeliveryZonesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeliveryZoneViewModel>().fetchZones();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Delivery Zones',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showZoneEditor(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Add Zone',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      body: Consumer<DeliveryZoneViewModel>(
        builder: (context, vm, _) {
          if (vm.status == DeliveryZoneStatus.loading &&
              vm.zones.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (vm.status == DeliveryZoneStatus.error && vm.zones.isEmpty) {
            return _ErrorView(
              message: vm.error ?? 'Could not load delivery zones.',
              onRetry: vm.fetchZones,
            );
          }

          if (vm.zones.isEmpty) {
            return _EmptyView(onAdd: () => _showZoneEditor(context));
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: vm.fetchZones,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.md, AppSizes.sm, AppSizes.md, 80,
              ),
              children: [
                // Stats row
                _StatsRow(vm: vm),
                const SizedBox(height: 16),

                // Zone cards
                ...vm.zones.map((zone) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ZoneCard(
                    zone: zone,
                    isDeleting: vm.isDeleting(zone.id),
                    onEdit: () => _showZoneEditor(context, zone: zone),
                    onDelete: () => _confirmDelete(context, zone),
                    onToggle: (active) => vm.toggleZoneActive(
                      zone.id, isActive: active,
                    ),
                  ),
                )),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showZoneEditor(BuildContext context, {DeliveryZone? zone}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<DeliveryZoneViewModel>(),
        child: _ZoneEditorSheet(zone: zone),
      ),
    );
  }

  void _confirmDelete(BuildContext context, DeliveryZone zone) {
    final vm = context.read<DeliveryZoneViewModel>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Delete Zone',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text(
          'Delete "${zone.zoneName}"? This cannot be undone.',
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await vm.deleteZone(zone.id);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(vm.error ?? 'Failed to delete zone.'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Stats Row
// ═══════════════════════════════════════════════════════════════════════

class _StatsRow extends StatelessWidget {
  final DeliveryZoneViewModel vm;
  const _StatsRow({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatChip(
          icon: Icons.layers_rounded,
          color: AppColors.info,
          label: 'Total',
          value: '${vm.zones.length}',
        ),
        const SizedBox(width: 10),
        _StatChip(
          icon: Icons.check_circle_rounded,
          color: AppColors.success,
          label: 'Active',
          value: '${vm.activeCount}',
        ),
        const SizedBox(width: 10),
        _StatChip(
          icon: Icons.radar_rounded,
          color: AppColors.primary,
          label: 'Max Range',
          value: vm.zones.isNotEmpty
              ? '${vm.zones.last.maxDistanceKm.toStringAsFixed(1)} km'
              : '0 km',
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textHint,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Zone Card
// ═══════════════════════════════════════════════════════════════════════

class _ZoneCard extends StatelessWidget {
  final DeliveryZone zone;
  final bool isDeleting;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const _ZoneCard({
    required this.zone,
    required this.isDeleting,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isDeleting ? 0.5 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(
            color: zone.isActive
                ? AppColors.success.withAlpha(40)
                : AppColors.border,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.info.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          size: 20,
                          color: AppColors.info,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              zone.zoneName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${zone.minDistanceKm.toStringAsFixed(1)} – ${zone.maxDistanceKm.toStringAsFixed(1)} km',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Active toggle
                      Switch.adaptive(
                        value: zone.isActive,
                        onChanged: isDeleting ? null : onToggle,
                        activeTrackColor: AppColors.success.withAlpha(80),
                        activeThumbColor: AppColors.success,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Info chips row
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.currency_rupee_rounded,
                        label: '₹${zone.deliveryFee.toStringAsFixed(0)}',
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      _InfoChip(
                        icon: Icons.shopping_bag_outlined,
                        label: 'Min ₹${zone.minimumOrder.toStringAsFixed(0)}',
                        color: AppColors.purple,
                      ),
                      const SizedBox(width: 8),
                      _InfoChip(
                        icon: Icons.timer_outlined,
                        label: '${zone.estimatedDeliveryTime} min',
                        color: AppColors.warning,
                      ),
                      const Spacer(),
                      // Actions
                      _ActionButton(
                        icon: Icons.edit_outlined,
                        color: AppColors.info,
                        onTap: onEdit,
                      ),
                      const SizedBox(width: 6),
                      _ActionButton(
                        icon: Icons.delete_outline_rounded,
                        color: AppColors.error,
                        onTap: isDeleting ? null : onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withAlpha(12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Empty & Error Views
// ═══════════════════════════════════════════════════════════════════════

class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.info.withAlpha(15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delivery_dining_rounded,
                size: 48,
                color: AppColors.info,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Delivery Zones Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Set up distance-based delivery zones\nwith custom fees, minimum orders & ETAs.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Create First Zone',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Zone Editor Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════

class _ZoneEditorSheet extends StatefulWidget {
  final DeliveryZone? zone;
  const _ZoneEditorSheet({this.zone});

  @override
  State<_ZoneEditorSheet> createState() => _ZoneEditorSheetState();
}

class _ZoneEditorSheetState extends State<_ZoneEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _minDistCtrl;
  late final TextEditingController _maxDistCtrl;
  late final TextEditingController _feeCtrl;
  late final TextEditingController _minOrderCtrl;
  late final TextEditingController _etaCtrl;
  late bool _isActive;

  bool get _isEditing => widget.zone != null;

  @override
  void initState() {
    super.initState();
    final z = widget.zone;
    _nameCtrl = TextEditingController(text: z?.zoneName ?? '');
    _minDistCtrl = TextEditingController(
      text: z?.minDistanceKm.toStringAsFixed(1) ?? '',
    );
    _maxDistCtrl = TextEditingController(
      text: z?.maxDistanceKm.toStringAsFixed(1) ?? '',
    );
    _feeCtrl = TextEditingController(
      text: z?.deliveryFee.toStringAsFixed(0) ?? '',
    );
    _minOrderCtrl = TextEditingController(
      text: z?.minimumOrder.toStringAsFixed(0) ?? '',
    );
    _etaCtrl = TextEditingController(
      text: z?.estimatedDeliveryTime.toString() ?? '',
    );
    _isActive = z?.isActive ?? true;

    // Re-render the "Minimum allowed: ₹X" hint as the vendor types
    // either the max distance or the fee. Web does the same on every
    // input event so the constraint is visible while typing instead
    // of only on submit (frontend_pages/vendor/delivery-zones.html →
    // updateMinFeeHint).
    _maxDistCtrl.addListener(_onGuardrailInputChanged);
    _feeCtrl.addListener(_onGuardrailInputChanged);
  }

  void _onGuardrailInputChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _maxDistCtrl.removeListener(_onGuardrailInputChanged);
    _feeCtrl.removeListener(_onGuardrailInputChanged);
    _nameCtrl.dispose();
    _minDistCtrl.dispose();
    _maxDistCtrl.dispose();
    _feeCtrl.dispose();
    _minOrderCtrl.dispose();
    _etaCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final vm = context.read<DeliveryZoneViewModel>();

    // Pre-submit guardrail check — same formula as backend, runs
    // BEFORE we hit the API so the vendor gets an instant, clear
    // explanation instead of a snackbar that disappears in 3 sec.
    // Web does this in saveZone() before fetch (delivery-zones.html
    // ~line 1665).
    final maxDist = double.tryParse(_maxDistCtrl.text.trim());
    final fee = double.tryParse(_feeCtrl.text.trim());
    if (maxDist != null && fee != null) {
      final minRequired = vm.feeGuardrail.minRequiredFee(maxDist);
      if (fee < minRequired) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Minimum allowed fee for ${maxDist.toStringAsFixed(1)} km zone '
              'is ₹${minRequired.toStringAsFixed(2)} (covers delivery '
              'partner cost at max distance).',
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }
    }

    final zone = DeliveryZone(
      id: widget.zone?.id ?? 0,
      zoneName: _nameCtrl.text.trim(),
      minDistanceKm: double.parse(_minDistCtrl.text.trim()),
      maxDistanceKm: double.parse(_maxDistCtrl.text.trim()),
      deliveryFee: double.parse(_feeCtrl.text.trim()),
      minimumOrder: double.parse(_minOrderCtrl.text.trim()),
      estimatedDeliveryTime: int.parse(_etaCtrl.text.trim()),
      isActive: _isActive,
    );

    final ok = _isEditing
        ? await vm.updateZone(widget.zone!.id, zone)
        : await vm.createZone(zone);

    if (!mounted) return;

    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'Zone updated!' : 'Zone created!',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.error ?? 'Failed to save zone.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                _isEditing ? 'Edit Delivery Zone' : 'New Delivery Zone',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),

              // Zone Name
              _buildField(
                controller: _nameCtrl,
                label: 'Zone Name *',
                hint: 'e.g. Nearby (0-3 km)',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              // Distance range
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      controller: _minDistCtrl,
                      label: 'Min Distance (km) *',
                      hint: '0',
                      isNumber: true,
                      validator: _requiredPositiveOrZero,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildField(
                      controller: _maxDistCtrl,
                      label: 'Max Distance (km) *',
                      hint: '3',
                      isNumber: true,
                      validator: (v) {
                        final base = _requiredPositive(v);
                        if (base != null) return base;
                        final min = double.tryParse(
                          _minDistCtrl.text.trim(),
                        );
                        final max = double.tryParse(v!.trim());
                        if (min != null && max != null && max <= min) {
                          return 'Must be > min';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Fee & Min Order
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      controller: _feeCtrl,
                      label: 'Delivery Fee (₹) *',
                      hint: '30',
                      isNumber: true,
                      validator: _requiredPositiveOrZero,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildField(
                      controller: _minOrderCtrl,
                      label: 'Min Order (₹) *',
                      hint: '100',
                      isNumber: true,
                      validator: _requiredPositiveOrZero,
                    ),
                  ),
                ],
              ),
              // Live "Minimum allowed" hint — turns red when the
              // typed fee falls below the DP-cost floor. Same UX as
              // the web vendor portal so vendors aren't surprised by
              // a 400 from the backend.
              _MinFeeHint(
                maxDistanceText: _maxDistCtrl.text,
                feeText: _feeCtrl.text,
                guardrail: context.watch<DeliveryZoneViewModel>().feeGuardrail,
              ),
              const SizedBox(height: 14),

              // ETA & Active toggle
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildField(
                      controller: _etaCtrl,
                      label: 'ETA (minutes) *',
                      hint: '30',
                      isNumber: true,
                      allowDecimal: false,
                      validator: _requiredPositive,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => setState(() => _isActive = !_isActive),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: _isActive
                                  ? AppColors.success.withAlpha(15)
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _isActive
                                    ? AppColors.success
                                    : AppColors.borderLight,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _isActive
                                      ? Icons.check_circle_rounded
                                      : Icons.cancel_outlined,
                                  size: 18,
                                  color: _isActive
                                      ? AppColors.success
                                      : AppColors.textHint,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _isActive
                                        ? AppColors.success
                                        : AppColors.textHint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Save button
              Consumer<DeliveryZoneViewModel>(
                builder: (context, vm, _) => SizedBox(
                  width: double.infinity,
                  height: AppSizes.buttonHeight,
                  child: ElevatedButton(
                    onPressed: vm.isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primary.withAlpha(120),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.buttonRadius,
                        ),
                      ),
                    ),
                    child: vm.isSaving
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isEditing ? 'Save Changes' : 'Create Zone',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool isNumber = false,
    bool allowDecimal = true,
    FormFieldValidator<String>? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: isNumber
              ? TextInputType.numberWithOptions(decimal: allowDecimal)
              : TextInputType.text,
          textCapitalization: isNumber
              ? TextCapitalization.none
              : TextCapitalization.words,
          inputFormatters: isNumber
              ? [
                  FilteringTextInputFormatter.allow(
                    allowDecimal ? RegExp(r'[\d.]') : RegExp(r'\d'),
                  ),
                ]
              : null,
          textInputAction: TextInputAction.next,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.textHint.withAlpha(150),
              fontWeight: FontWeight.w400,
            ),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.primary, width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.error, width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 13,
            ),
            errorStyle: const TextStyle(fontSize: 11),
          ),
          validator: validator,
        ),
      ],
    );
  }

  String? _requiredPositiveOrZero(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    if (double.tryParse(v.trim()) == null) return 'Invalid';
    if (double.parse(v.trim()) < 0) return 'Must be 0 or more';
    return null;
  }

  String? _requiredPositive(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    if (double.tryParse(v.trim()) == null) return 'Invalid';
    if (double.parse(v.trim()) <= 0) return 'Must be > 0';
    return null;
  }
}

/// Live "Minimum allowed: ₹X" hint shown directly under the
/// Delivery Fee input. Mirrors the web vendor portal's
/// `updateMinFeeHint()` (frontend_pages/vendor/delivery-zones.html).
/// Hidden until a valid max-distance is typed; turns red when the
/// fee falls below the floor.
class _MinFeeHint extends StatelessWidget {
  final String maxDistanceText;
  final String feeText;
  final FeeGuardrail guardrail;

  const _MinFeeHint({
    required this.maxDistanceText,
    required this.feeText,
    required this.guardrail,
  });

  @override
  Widget build(BuildContext context) {
    final maxDist = double.tryParse(maxDistanceText.trim());
    if (maxDist == null || maxDist <= 0) {
      return const SizedBox.shrink();
    }
    final minRequired = guardrail.minRequiredFee(maxDist);
    final fee = double.tryParse(feeText.trim());
    final ok = fee != null && fee >= minRequired;
    final color = ok ? AppColors.success : AppColors.error;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Minimum allowed: ₹${minRequired.toStringAsFixed(2)} '
              '(covers DP cost at ${maxDist.toStringAsFixed(1)} km)',
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
