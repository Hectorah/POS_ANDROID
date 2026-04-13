import 'package:flutter/material.dart';
import '../../core/utils/responsive_helper.dart';

enum ButtonVariant { primary, secondary, danger }

class CustomButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String text;
  final IconData? icon;
  final bool isLoading;
  final ButtonVariant variant;
  final double? width;
  final double? height;

 const CustomButton({
    super.key, 
    required this.onPressed,
    required this.text,
    this.icon,
    this.isLoading = false,
    this.variant = ButtonVariant.primary,
    this.width,
    this.height,
  }); 

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getBackgroundColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (widget.variant) {
      case ButtonVariant.primary:
        return Theme.of(context).colorScheme.primary;
      case ButtonVariant.secondary:
        return isDark ? Colors.grey[800]! : Colors.grey[300]!;
      case ButtonVariant.danger:
        return Colors.red;
    }
  }

  Color _getTextColor(BuildContext context) {
    switch (widget.variant) {
      case ButtonVariant.primary:
        return Theme.of(context).brightness == Brightness.dark
            ? Colors.black
            : Colors.white;
      case ButtonVariant.secondary:
        return Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black;
      case ButtonVariant.danger:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SizedBox(
          width: widget.width ?? responsive.getWidth(100),
          height: widget.height ?? responsive.minTouchTarget,
          child: ElevatedButton(
            onPressed: widget.isLoading ? null : widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: _getBackgroundColor(context),
              foregroundColor: _getTextColor(context),
              minimumSize: Size(responsive.minTouchTarget, responsive.minTouchTarget),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: widget.isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getTextColor(context),
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: responsive.getFontSize(20)),
                        SizedBox(width: responsive.getPadding(8)),
                      ],
                      Text(
                        widget.text,
                        style: TextStyle(
                          fontSize: responsive.getFontSize(16),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
