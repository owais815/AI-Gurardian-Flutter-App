import 'dart:math';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class LinkOptionsScreen extends StatefulWidget {
  final String parentUID;

  const LinkOptionsScreen({super.key, required this.parentUID});

  @override
  State<LinkOptionsScreen> createState() => _LinkOptionsScreenState();
}

class _LinkOptionsScreenState extends State<LinkOptionsScreen> {
  String? generatedCode;

  String generateSixDigitCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  Future<void> createCodeAndSave() async {
    final code = generateSixDigitCode();

    await FirebaseFirestore.instance.collection('pairing_codes').doc(code).set({
      'parentUID': widget.parentUID,
      'createdAt': FieldValue.serverTimestamp(),
      'used': false,
    });

    setState(() {
      generatedCode = code;
    });
  }

  @override
  Widget build(BuildContext context) {
    final qrData = jsonEncode({
      "parentUID": widget.parentUID,
      "timestamp": DateTime.now().toIso8601String(),
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text("Link Child Device"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text(
              'Scan this QR code from the child device:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            QrImageView(data: qrData, version: QrVersions.auto, size: 200.0),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: createCodeAndSave,
              icon: const Icon(Icons.numbers),
              label: const Text('Generate 6-digit Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            if (generatedCode != null)
              Column(
                children: [
                  const Text('Share this code with child device:'),
                  Text(
                    generatedCode!,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
