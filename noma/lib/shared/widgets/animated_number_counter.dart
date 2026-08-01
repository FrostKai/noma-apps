import 'package:flutter/material.dart';
import '../../core/utils/currency_formatter.dart';

/// Animated Number Counter widget for smooth financial amount transitions
class AnimatedNumberCounter extends StatefulWidget {
  final double targetAmount;
  final TextStyle style;
  final Duration duration;
  final bool isCompact;

  const AnimatedNumberCounter({
    super.key,
    required this.targetAmount,
    required this.style,
    this.duration = const Duration(milliseconds: 1200),
    this.isCompact = false,
  });

  @override
  State<AnimatedNumberCounter> createState() => _AnimatedNumberCounterState();
}

class _AnimatedNumberCounterState extends State<AnimatedNumberCounter> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _animation = Tween<double>(
      begin: 0.0,
      end: widget.targetAmount,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutExpo,
      ),
    );

    _previousAmount = widget.targetAmount;
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedNumberCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetAmount != widget.targetAmount) {
      _animation = Tween<double>(
        begin: _previousAmount,
        end: widget.targetAmount,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOutExpo,
        ),
      );

      _previousAmount = widget.targetAmount;
      _controller.reset();
      _controller.forward();
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
        final val = _animation.value;
        final formattedText = widget.isCompact
            ? CurrencyFormatter.formatRupiahCompact(val)
            : CurrencyFormatter.formatRupiah(val);

        return Text(
          formattedText,
          style: widget.style,
        );
      },
    );
  }
}
