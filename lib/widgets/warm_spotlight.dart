import 'package:flutter/material.dart';

/// 矩形暖色呼吸光晕
///
/// 用于排期板 today 行/卡片，提供柔和的舞台侧光/追光效果。
/// 支持可配置 borderRadius、外部控制动画暂停/继续。
class WarmSpotlight extends StatefulWidget {
  final Widget child;
  final Color color;
  final Duration duration;
  final double minAlpha;
  final double maxAlpha;
  final double minBlur;
  final double maxBlur;
  final double spreadRadius;
  final double borderRadius;
  final bool shouldAnimate;

  const WarmSpotlight({
    super.key,
    required this.child,
    this.color = const Color(0xFFD4A853),
    this.duration = const Duration(milliseconds: 2800),
    this.minAlpha = 0.08,
    this.maxAlpha = 0.16,
    this.minBlur = 8.0,
    this.maxBlur = 16.0,
    this.spreadRadius = 0.0,
    this.borderRadius = 10.0,
    this.shouldAnimate = true,
  });

  @override
  State<WarmSpotlight> createState() => _WarmSpotlightState();
}

class _WarmSpotlightState extends State<WarmSpotlight>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.shouldAnimate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(WarmSpotlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldAnimate != oldWidget.shouldAnimate) {
      if (widget.shouldAnimate) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final t = _animation.value;
        final alpha = widget.minAlpha + (widget.maxAlpha - widget.minAlpha) * t;
        final blurRadius = widget.minBlur + (widget.maxBlur - widget.minBlur) * t;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: alpha),
                blurRadius: blurRadius,
                spreadRadius: widget.spreadRadius,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
