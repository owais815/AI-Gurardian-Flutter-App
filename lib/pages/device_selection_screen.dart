import 'package:flutter/material.dart';
import 'package:ai_guardian_parent/pages/add_child.dart';

class DeviceSelectionScreen extends StatefulWidget {
  final String childName;

  const DeviceSelectionScreen({super.key, required this.childName});

  @override
  State<DeviceSelectionScreen> createState() => _DeviceSelectionScreenState();
}

class _DeviceSelectionScreenState extends State<DeviceSelectionScreen> {
  String? _selectedDevice;

  final List<String> _deviceOptions = [
    'Android Phone',
    'iPhone',
    'Tablet',
    'Windows PC',
    'Macbook',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          widget.childName,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AddChildScreen()),
              );
            },
            child: const Text(
              'Edit',
              style: TextStyle(color: Colors.deepPurple),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Illustration
            Image.asset('assets/images/aiGuardianLogo.png', height: 180),

            const SizedBox(height: 30),

            // Title
            const Text(
              'Protect a Device',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'What kind of device does your child use?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 30),

            // Dropdown
            DropdownButtonFormField<String>(
              value: _selectedDevice,
              hint: const Text("Select Device"),
              items:
                  _deviceOptions
                      .map(
                        (device) => DropdownMenuItem(
                          value: device,
                          child: Text(device),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDevice = value;
                });
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Steps after selection
            if (_selectedDevice != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Setup Instructions:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  buildStep(
                    1,
                    'Open Play Store / App Store on your child\'s device',
                  ),
                  buildStep(2, 'Download and Login "AI Guardian Child" App'),
                  buildStep(
                    3,
                    'Confirm that you want to protect the device and Follow the on-screen instructions to complete setup',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget buildStep(int step, String instruction) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.deepPurple,
            child: Text(
              '$step',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(instruction, style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
