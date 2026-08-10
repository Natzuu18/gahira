import 'package:flutter/material.dart';

import '../shared_widgets/appColor.dart';
import '../../main.dart'; // for LoginPage
import 'mining_background.dart';
import 'register_form_section.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  void _goToLogin(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  void _goToRegister(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: context.bgColor,
          appBar: AppBar(
            title: const Text('GAHIRA'),
            backgroundColor: context.bgColor,
            elevation: 0,
            iconTheme: IconThemeData(color: kGold),
          ),
          body: const SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 12),
                  RegisterFormSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GAHIRA'),
        actions: [
          TextButton(onPressed: () {}, child: const Text('Home')),
          TextButton(onPressed: () {}, child: const Text('Features')),
          TextButton(onPressed: () {}, child: const Text('About')),
          TextButton(
            onPressed: () => _goToLogin(context),
            child: const Text('LOGIN'),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Animated pickaxe / gold icon background, sits behind everything.
          const Positioned.fill(
            child: MiningBackground(),
          ),
          SingleChildScrollView(
            child: Column(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Text(
                        'GAHIRA BALL MILL MANAGEMENT SYSTEM',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Image.asset(
                        'assets/ball_mill.png',
                        errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 8),
                      const Text('Manage. Monitor. Optimize.'),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          ElevatedButton(
                            // Opens the sign-up form.
                            onPressed: () => _goToRegister(context),
                            child: const Text('GET STARTED'),
                          ),
                          ElevatedButton(
                              onPressed: () {},
                              child: const Text('LEARN MORE')),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(),
                const Text('ABOUT GAHIRA'),
                const Text('Short description of the system'),
                const Divider(),
                const Text('KEY FEATURES'),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    ElevatedButton(
                        onPressed: () {}, child: const Text('Production')),
                    ElevatedButton(
                        onPressed: () {}, child: const Text('Inventory')),
                    ElevatedButton(
                        onPressed: () {}, child: const Text('Analytics')),
                    ElevatedButton(
                        onPressed: () {}, child: const Text('Reports')),
                  ],
                ),
                const Divider(),
                const Text('HOW IT WORKS'),
                const Text('01 → 02 → 03'),
                const Divider(),
                const Text('DASHBOARD PREVIEW'),
                Image.asset(
                  'assets/dashboard_preview.png',
                  errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
                ),
                const Divider(),
                const Text('WHY GAHIRA?'),
                const Text('Faster • Organized • Accurate • Centralized'),
                const Divider(),
                const Text('READY TO GET STARTED?'),
                const SizedBox(height: 8),
                ElevatedButton(
                  // Also opens the sign-up form, consistent with the top CTA.
                  onPressed: () => _goToRegister(context),
                  child: const Text('SIGN UP'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _goToLogin(context),
                  child: const Text('Already have an account? Log in'),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('FOOTER'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}