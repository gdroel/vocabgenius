import 'package:flutter/material.dart';

/// Placeholder destination opened when a user taps a push notification.
class HelloThereScreen extends StatelessWidget {
  const HelloThereScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const Center(
        child: Text('hello there', style: TextStyle(fontSize: 28)),
      ),
    );
  }
}
