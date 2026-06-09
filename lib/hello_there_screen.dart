import 'package:flutter/material.dart';

import 'telemetry.dart';

/// The notification screen — destination opened when a user taps a push.
class HelloThereScreen extends StatefulWidget {
  const HelloThereScreen({super.key});

  @override
  State<HelloThereScreen> createState() => _HelloThereScreenState();
}

class _HelloThereScreenState extends State<HelloThereScreen> {
  @override
  void initState() {
    super.initState();
    Telemetry.notificationScreen();
  }

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
