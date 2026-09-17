import 'package:flutter/material.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('About, settings, etc. — coming later.'),
        ),
      ),
    );
  }
}