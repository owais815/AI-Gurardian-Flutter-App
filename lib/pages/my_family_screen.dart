import 'package:flutter/material.dart';

class MyFamilyScreen extends StatelessWidget {
  const MyFamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        // optional sidebar
        child: ListView(
          children: const [
            DrawerHeader(
              child: Text("Menu"),
            ),
            ListTile(title: Text("Settings")),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text(
          "My family",
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          // Trial Banner
          Container(
            width: double.infinity,
            color: Colors.pink.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: RichText(
              text: TextSpan(
                text: "🚀 Your trial ends in 4 days – ",
                style: const TextStyle(color: Colors.red, fontSize: 16),
                children: [
                  TextSpan(
                    text: "Upgrade now!",
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  )
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Illustration
          Center(
            child: Image.asset(
              'assets/images/family.png', // replace with actual image
              height: 180,
            ),
          ),

          const SizedBox(height: 30),

          // Text
          const Text(
            "Protect your first child’s device with AI Guardian!",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),

          const SizedBox(height: 30),

          // Start Now Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Next screen logic
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4C5DF4),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Start now",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
