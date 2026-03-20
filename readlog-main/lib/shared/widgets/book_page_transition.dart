import 'package:flutter/material.dart';

/// Smooth modern page transition
class BookPageTransition extends PageTransitionsBuilder {
  const BookPageTransition();

  @override
  Widget buildTransitions<T extends Object?>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: curvedAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.03, 0),
          end: Offset.zero,
        ).animate(curvedAnimation),
        child: child,
      ),
    );
  }
}

/// PageView için kitap yaprağı çevirme efekti
class BookPageView extends StatefulWidget {
  const BookPageView({
    super.key,
    required this.children,
    this.controller,
    this.onPageChanged,
    this.physics,
  });

  final List<Widget> children;
  final PageController? controller;
  final ValueChanged<int>? onPageChanged;
  final ScrollPhysics? physics;

  @override
  State<BookPageView> createState() => _BookPageViewState();
}

class _BookPageViewState extends State<BookPageView> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = widget.controller ?? PageController();
    _pageController.addListener(_onPageChanged);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _pageController.dispose();
    }
    super.dispose();
  }

  void _onPageChanged() {
    if (_pageController.page != null) {
      final newPage = _pageController.page!.round();
      if (newPage != _currentPage) {
        setState(() {
          _currentPage = newPage;
        });
        widget.onPageChanged?.call(newPage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      physics: widget.physics ?? const BouncingScrollPhysics(),
      onPageChanged: (index) {
        widget.onPageChanged?.call(index);
      },
      itemCount: widget.children.length,
      itemBuilder: (context, index) {
        return _BookPageWrapper(
          key: ValueKey(index),
          index: index,
          pageController: _pageController,
          child: widget.children[index],
        );
      },
    );
  }
}

class _BookPageWrapper extends StatelessWidget {
  const _BookPageWrapper({
    super.key,
    required this.index,
    required this.pageController,
    required this.child,
  });

  final int index;
  final PageController pageController;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pageController,
      builder: (context, _) {
        if (!pageController.position.hasContentDimensions) {
          return child;
        }

        final page = pageController.page ?? index.toDouble();
        final offset = page - index;
        final absOffset = offset.abs().clamp(0.0, 1.0);

        // Smooth parallax-style page transition
        final scale = 1.0 - (absOffset * 0.06);
        final opacity = (1.0 - absOffset * 0.4).clamp(0.0, 1.0);
        final translateX = offset * MediaQuery.of(context).size.width * 0.15;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translateByDouble(translateX, 0.0, 0.0, 1.0)
            ..scaleByDouble(scale, scale, 1.0, 1.0),
          child: Opacity(
            opacity: opacity,
            child: child,
          ),
        );
      },
    );
  }
}
