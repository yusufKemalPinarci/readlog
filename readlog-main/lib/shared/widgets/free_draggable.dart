import 'package:flutter/material.dart';

class FreeDraggable extends StatefulWidget {
  final Widget child;

  const FreeDraggable({super.key, required this.child});

  @override
  State<FreeDraggable> createState() => _FreeDraggableState();
}

class _FreeDraggableState extends State<FreeDraggable> {
  Offset offset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          offset += details.delta;
        });
      },
      child: Transform.translate(
        offset: offset,
        child: widget.child,
      ),
    );
  }
}
