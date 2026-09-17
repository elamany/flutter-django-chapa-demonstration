import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campaigns')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Public campaign list coming next.'),
        ),
      ),
    );
  }
}