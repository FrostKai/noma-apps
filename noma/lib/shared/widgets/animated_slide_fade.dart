import 'package:flutter/material.dart';

/// Staggered Slide-Up & Fade-In entrance animation for list items and cards
class AnimatedSlideFade extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;
  final Duration duration;
  final Offset offset;

  const AnimatedSlideFade({
    super.key,
    required this.child,
    this.index = 0,
    this.delay = const Duration(milliseconds: 60),
    this.duration = const Duration(milliseconds: 500),
    this.offset = const Offset(0, 0.15),
  });

  @override
  State<AnimatedSlideFade> createState() => _AnimatedSlideFadeState();
}

class _AnimatedSlideFadeState extends State<AnimatedSlideFade> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    Future.delayed(widget.delay * widget.index, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}
