import 'package:flutter/material.dart';

class BookScaffold extends StatelessWidget {
  final Widget body;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;

  const BookScaffold({
    super.key,
    required this.body,
    this.floatingActionButton,
    this.appBar,
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      extendBody: true,
    );
  }
}
