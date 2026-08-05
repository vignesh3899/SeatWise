import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Wraps [child] with a touch-driven 3D tilt: drag your finger across the
/// card and it rotates in perspective like it's a physical pane of glass,
/// with a moving light sheen and a soft shadow that reacts to the tilt.
/// Releasing springs it back flat.
///
/// Pure gesture-based (no sensors/plugins needed), so it works everywhere
/// this project runs without extra native setup.
class TiltCard extends StatefulWidget {
  const TiltCard({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.maxTiltRadians = 0.16,
    this.onTap,
  });

  final Widget child;
  final double borderRadius;
  final double maxTiltRadians;
  final VoidCallback? onTap;

  @override
  State<TiltCard> createState() => _TiltCardState();
}

class _TiltCardState extends State<TiltCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Offset _dragAtResetStart = Offset.zero;
  Offset _drag = Offset.zero; // -1..1 range on each axis
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..addListener(() {
        setState(() {
          _drag = Offset.lerp(
            _dragAtResetStart,
            Offset.zero,
            _controller.value,
          )!;
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _update(Offset local) {
    if (_size.isEmpty) return;
    if (_controller.isAnimating) _controller.stop();
    final dx = ((local.dx / _size.width) * 2 - 1).clamp(-1.0, 1.0);
    final dy = ((local.dy / _size.height) * 2 - 1).clamp(-1.0, 1.0);
    setState(() => _drag = Offset(dx, dy));
  }

  void _reset() {
    _dragAtResetStart = _drag;
    _controller
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        final rotY = _drag.dx * widget.maxTiltRadians;
        final rotX = -_drag.dy * widget.maxTiltRadians;
        final lift = 1 - (_drag.distance.clamp(0, 1.4) / 1.4);

        return GestureDetector(
          onTap: widget.onTap,
          onPanUpdate: (d) => _update(d.localPosition),
          onPanEnd: (_) => _reset(),
          onPanCancel: _reset,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012) // perspective
              ..rotateX(rotX)
              ..rotateY(rotY)
              ..scale(1.0 + (1 - lift) * 0.015),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.20 * lift + 0.06),
                    blurRadius: 26,
                    offset: Offset(rotY * -40, 14 - rotX * -40),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  widget.child,
                  // moving light sheen that tracks the tilt direction
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(widget.borderRadius),
                        child: Opacity(
                          opacity: 0.5 * (1 - lift) + 0.06,
                          child: Align(
                            alignment: Alignment(_drag.dx, _drag.dy),
                            child: Container(
                              width: _size.width * 1.2,
                              height: _size.height * 1.2,
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.55),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                  stops: const [0.0, 0.7],
                                ),
                              ),
                            ),
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
      },
    );
  }
}

/// Small helper: a gentle continuous float/bob animation for icons or emoji,
/// used to give otherwise-static glass panels a bit of life.
class FloatingWidget extends StatefulWidget {
  const FloatingWidget({
    super.key,
    required this.child,
    this.amplitude = 6,
    this.duration = const Duration(seconds: 3),
  });

  final Widget child;
  final double amplitude;
  final Duration duration;

  @override
  State<FloatingWidget> createState() => _FloatingWidgetState();
}

class _FloatingWidgetState extends State<FloatingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value * 2 * math.pi;
        return Transform.translate(
          offset: Offset(0, math.sin(t) * widget.amplitude),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
