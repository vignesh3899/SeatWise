import 'dart:ui';

import 'package:flutter/material.dart';

/// A frosted "liquid glass" surface: blurred backdrop, translucent gradient
/// fill and a soft light-catching border. Drop any content inside — it reads
/// as a pane of glass floating over whatever is behind it.
///
/// Kept as a single reusable widget so the glass look stays consistent
/// wherever it's used (plan card, recommendation summary, nav bar, etc).
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.blur = 18,
    this.padding,
    this.tint,
    this.opacity = 0.18,
    this.borderOpacity = 0.35,
  });

  final Widget child;
  final double borderRadius;
  final double blur;
  final EdgeInsetsGeometry? padding;

  /// Base tint colour. Defaults to the theme's primary colour.
  final Color? tint;

  /// How strongly [tint] shows through the glass (0..1).
  final double opacity;

  /// Strength of the glass edge highlight (0..1).
  final double borderOpacity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = tint ?? scheme.primary;
    final radius = BorderRadius.circular(borderRadius);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: opacity + 0.06),
                base.withValues(alpha: opacity),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: borderOpacity),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: base.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
