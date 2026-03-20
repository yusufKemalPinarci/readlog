import 'package:flutter/material.dart';

/// Kitap temalı loading widget'ı
class BookLoadingWidget extends StatefulWidget {
  const BookLoadingWidget({
    super.key,
    this.message,
    this.size = 120,
  });

  final String? message;
  final double size;

  @override
  State<BookLoadingWidget> createState() => _BookLoadingWidgetState();
}

class _BookLoadingWidgetState extends State<BookLoadingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();



    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.2), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 1.0), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primaryColor.withValues(alpha: 0.2),
                        primaryColor.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    size: widget.size * 0.5,
                    color: primaryColor,
                  ),
                ),
              );
            },
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 24),
            Text(
              widget.message!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
