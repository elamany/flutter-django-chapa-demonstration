import 'package:flutter/material.dart';

class WebviewLoaderAnimation extends StatefulWidget {
  const WebviewLoaderAnimation({super.key, this.height = 3});

  final double height;

  @override
  State<WebviewLoaderAnimation> createState() => _WebviewLoaderAnimationState();
}

class _WebviewLoaderAnimationState extends State<WebviewLoaderAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color blue = Colors.blue; // or Color(0xFF1E88E5), 

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final start = -0.4 + t * 1.4;

          return ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.4,
                child: Transform.translate(
                  offset: Offset(
                    MediaQuery.of(context).size.width * start,
                    0,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          blue.withValues(alpha: 0.0),
                          blue,
                          blue.withValues(alpha: 0.0),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(widget.height / 2),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}