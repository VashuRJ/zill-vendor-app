import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

class AppTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final bool obscureText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool enabled;
  final int maxLines;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final VoidCallback? onEditingComplete;

  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.prefixIcon,
    this.suffix,
    this.enabled = true,
    this.maxLines = 1,
    this.focusNode,
    this.onChanged,
    this.textInputAction,
    this.onEditingComplete,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: AppSizes.sm),
        ],
        TextFormField(
          controller: widget.controller,
          validator: widget.validator,
          keyboardType: widget.keyboardType,
          obscureText: _obscure,
          enabled: widget.enabled,
          maxLines: widget.maxLines,
          focusNode: widget.focusNode,
          onChanged: widget.onChanged,
          textInputAction: widget.textInputAction,
          onEditingComplete: widget.onEditingComplete,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon, color: AppColors.textHint, size: 22)
                : null,
            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.textHint,
                      size: 22,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )
                : widget.suffix,
          ),
        ),
      ],
    );
  }
}
