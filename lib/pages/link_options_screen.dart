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

  // Function to generate a random 6-digit code
  String generateSixDigitCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // Function to create 6-digit code and save it to Firestore
  Future<void> createCodeAndSave() async {
    final code = generateSixDigitCode();

    // Save the generated code to Firestore under 'pairing_codes'
    await FirebaseFirestore.instance.collection('pairing_codes').doc(code).set({
      'parentUID': widget.parentUID, // Store the parentUID
      'createdAt': FieldValue.serverTimestamp(),
      'used': false, // Mark the code as unused initially
    });

    setState(() {
      generatedCode = code; // Update the UI with the generated code
    });

    // Optionally, show a confirmation snackbar
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('6-Digit Code Generated: $code')));
  }

  @override
  Widget build(BuildContext context) {
    // QR code data to include parentUID
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
            // Display the QR code
            QrImageView(data: qrData, version: QrVersions.auto, size: 200.0),
            const SizedBox(height: 32),
            // Button to generate and show the 6-digit code
            ElevatedButton.icon(
              onPressed:
                  createCodeAndSave, // Call function to generate and save code
              icon: const Icon(Icons.numbers),
              label: const Text('Generate 6-digit Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            // Display the generated code, if any
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
