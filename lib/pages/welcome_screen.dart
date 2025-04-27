import 'package:flutter/material.dart';
import 'package:ai_guardian_parent/pages/my_family_screen.dart';

class WelcomeScreen extends StatelessWidget {
  final String userName;

  const WelcomeScreen({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Illustration
                Image.asset(
                  'assets/images/aiGuardianLogo.png', // Add image to assets
                  height: 200,
                ),

                const SizedBox(height: 30),

                // Welcome message
                Text(
                  'Welcome, $userName',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),

                // Instruction text
                const Text(
                  "Please confirm this is your own device and you want to manage your child’s online activity from here.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),

                const SizedBox(height: 40),

                // Confirm Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyFamilyScreen(),
                        ),
                      );
                    },

                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Color(0xFF4C5DF4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Confirm",
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Alternative link
                Column(
                  children: [
                    const Text(
                      "Not what you were expecting?",
                      textAlign: TextAlign.center,
                    ),
                    GestureDetector(
                      onTap: () {
                        // Navigate to Kids App or show info
                      },
                      child: const Text(
                        "Try Kids App instead",
                        style: TextStyle(
                          color: Color(0xFF4C5DF4),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
