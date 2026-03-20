import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A smooth, modern page transition with fade + gentle slide.
class PageTurnTransition extends CustomTransitionPage<void> {
  PageTurnTransition({
    required super.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
    super.maintainState,
  }) : super(
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            return FadeTransition(
              opacity: curvedAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.04, 0),
                  end: Offset.zero,
                ).animate(curvedAnimation),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 280),
        );
}
