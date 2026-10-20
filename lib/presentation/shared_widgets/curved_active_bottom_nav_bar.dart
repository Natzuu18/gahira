import 'package:flutter/material.dart';
import 'appColor.dart';

class CurvedNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Color activeColor;
  final Color inactiveColor;
  final int? badgeCount;

  const CurvedNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.activeColor = kGold,
    Color? inactiveColor,
    this.badgeCount,
  }) : inactiveColor = inactiveColor ?? activeColor;
}

class CurvedActiveBottomNavBar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onTabSelected;
  final List<CurvedNavItem> items;

  const CurvedActiveBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.items,
  });

  @override
  State<CurvedActiveBottomNavBar> createState() => _CurvedActiveBottomNavBarState();
}

class _CurvedActiveBottomNavBarState extends State<CurvedActiveBottomNavBar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late double _currentPos;

  @override
  void initState() {
    super.initState();
    _currentPos = widget.selectedIndex.toDouble();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = Tween<double>(begin: _currentPos, end: _currentPos).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    )..addListener(() {
        setState(() {});
      });
  }

  @override
  void didUpdateWidget(covariant CurvedActiveBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _animateTo(widget.selectedIndex.toDouble());
    }
  }

  void _animateTo(double target) {
    _animation = Tween<double>(begin: _currentPos, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    )..addListener(() {
        setState(() {
          _currentPos = _animation.value;
        });
      });
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double barHeight = 68.0;
    const double circleRadius = 24.0; // 48px diameter circle

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final itemWidth = totalWidth / widget.items.length;
        final activeX = itemWidth * (_currentPos + 0.5) - circleRadius;
        final selectedItem = widget.items[widget.selectedIndex];
        final activeColor = selectedItem.activeColor;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Custom Curved Background Painter
            CustomPaint(
              size: Size(totalWidth, barHeight),
              painter: CurvedBarPainter(
                activePos: _currentPos,
                itemNum: widget.items.length,
                color: context.surfaceColor,
                borderColor: activeColor.withOpacity(0.35),
              ),
            ),

            // Active Floating Circular Color Badge
            Positioned(
              left: activeX,
              top: -12,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: activeColor,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: activeColor.withOpacity(0.45),
                      blurRadius: 10,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: Icon(
                        selectedItem.selectedIcon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    if (selectedItem.badgeCount != null &&
                        selectedItem.badgeCount! > 0)
                      _buildBadge(selectedItem.badgeCount!),
                  ],
                ),
              ),
            ),

            // Tappable Nav Items Row
            SizedBox(
              height: barHeight,
              child: Row(
                children: List.generate(widget.items.length, (index) {
                  final item = widget.items[index];
                  final isSelected = widget.selectedIndex == index;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => widget.onTabSelected(index),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!isSelected)
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: item.activeColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: item.activeColor.withValues(
                                      alpha: 0.2,
                                    ),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Center(
                                    child: Icon(
                                      item.icon,
                                      color: Colors.white,
                                      size: 19,
                                    ),
                                  ),
                                  if (item.badgeCount != null &&
                                      item.badgeCount! > 0)
                                    _buildBadge(item.badgeCount!),
                                ],
                              ),
                            )
                          else
                            const SizedBox(
                              height: 24,
                            ), // Space reserved for floating active circle
                          const SizedBox(height: 4),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected
                                  ? item.activeColor
                                  : context.mutedTextColor,
                              fontSize: isSelected ? 11 : 10,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBadge(int count) {
    return Positioned(
      top: -3,
      right: -5,
      child: Container(
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class CurvedBarPainter extends CustomPainter {
  final double activePos;
  final int itemNum;
  final Color color;
  final Color borderColor;

  CurvedBarPainter({
    required this.activePos,
    required this.itemNum,
    required this.color,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final itemWidth = size.width / itemNum;
    final cx = itemWidth * (activePos + 0.5);

    const double notchRadius = 30.0;
    const double notchDepth = 16.0;

    final path = Path();
    path.moveTo(0, 0);

    final leftNotch = (cx - notchRadius - 10).clamp(0.0, size.width);
    final rightNotch = (cx + notchRadius + 10).clamp(0.0, size.width);

    path.lineTo(leftNotch, 0);

    // Smooth concave curve into notch
    path.cubicTo(
      cx - notchRadius,
      0,
      cx - notchRadius + 4,
      notchDepth,
      cx,
      notchDepth,
    );

    // Smooth concave curve out of notch
    path.cubicTo(
      cx + notchRadius - 4,
      notchDepth,
      cx + notchRadius,
      0,
      rightNotch,
      0,
    );

    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    // Draw shadow
    canvas.drawShadow(path, Colors.black.withOpacity(0.25), 8.0, false);

    // Draw filled curved bar
    canvas.drawPath(path, paint);

    // Draw top border line along curve
    final borderPath = Path();
    borderPath.moveTo(0, 0);
    borderPath.lineTo(leftNotch, 0);
    borderPath.cubicTo(
      cx - notchRadius,
      0,
      cx - notchRadius + 4,
      notchDepth,
      cx,
      notchDepth,
    );
    borderPath.cubicTo(
      cx + notchRadius - 4,
      notchDepth,
      cx + notchRadius,
      0,
      rightNotch,
      0,
    );
    borderPath.lineTo(size.width, 0);

    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CurvedBarPainter oldDelegate) {
    return oldDelegate.activePos != activePos ||
        oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor;
  }
}
