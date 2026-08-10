import 'dart:math';
import 'package:flutter/material.dart';

import '../shared_widgets/appColor.dart';

/// A decorative animated background of drifting pickaxe / gold icons.
/// Intended to sit behind page content inside a Stack, e.g.:
///
/// Stack(
///   children: [
///     const Positioned.fill(child: MiningBackground()),
///     yourScrollableContent,
///   ],
/// )
class MiningBackground extends StatefulWidget {
  final int iconCount;
  final double opacity;

  const MiningBackground({
    super.key,
    this.iconCount = 19,
    this.opacity = 0.50,
  });

  @override
  State<MiningBackground> createState() => _MiningBackgroundState();
}

class _MiningBackgroundState extends State<MiningBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_FloatingIcon> _icons;

  // Mix of pickaxe / mining / gold glyphs.
  static const List<IconData> _iconSet = [
    Icons.construction, // pickaxe-style tool
    Icons.hardware,
    Icons.diamond,
    Icons.monetization_on,
    Icons.paid,
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();

    final random = Random(7); // fixed seed = stable layout on rebuild
    _icons = List.generate(widget.iconCount, (i) {
      return _FloatingIcon(
        icon: _iconSet[random.nextInt(_iconSet.length)],
        startX: random.nextDouble(),
        startY: random.nextDouble(),
        driftSpeed: 0.3 + random.nextDouble() * 0.7,
        bobSpeed: 0.6 + random.nextDouble() * 1.2,
        size: 22 + random.nextDouble() * 30,
        phase: random.nextDouble() * 2 * pi,
        rotationDirection: random.nextBool() ? 1 : -1,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      // Purely decorative — never intercepts taps meant for buttons/links.
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value; // 0..1 looping
                return Stack(
                  children: _icons.map((icon) {
                    // Slow horizontal drift, looping back around.
                    final dx =
                        (icon.startX + t * icon.driftSpeed) % 1.0;
                    // Gentle vertical bob via sine wave.
                    final dy = icon.startY +
                        sin(t * 2 * pi * icon.bobSpeed + icon.phase) *
                            0.02;
                    final rotation = t *
                        2 *
                        pi *
                        0.15 *
                        icon.rotationDirection;

                    return Positioned(
                      left: dx * constraints.maxWidth,
                      top: (dy.clamp(0.0, 1.0)) * constraints.maxHeight,
                      child: Transform.rotate(
                        angle: rotation,
                        child: Opacity(
                          opacity: widget.opacity,
                          child: Icon(
                            icon.icon,
                            size: icon.size,
                            color: kGold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _FloatingIcon {
  final IconData icon;
  final double startX;
  final double startY;
  final double driftSpeed;
  final double bobSpeed;
  final double size;
  final double phase;
  final int rotationDirection;

  _FloatingIcon({
    required this.icon,
    required this.startX,
    required this.startY,
    required this.driftSpeed,
    required this.bobSpeed,
    required this.size,
    required this.phase,
    required this.rotationDirection,
  });
}