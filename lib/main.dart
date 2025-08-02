// lib/main.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart'; // For SystemNavigator.pop()

import 'ticket_form.dart'; // This is your input form
import 'ticket_preview_list.dart'; // This is your list view

// You will change this key to renew the license.
// A new key (e.g., 'v2_new_key') will reset the 30-day timer.
const String kLicenseKey = 'v1_initial_key'; // <--- CHANGE THIS TO RENEW THE APP

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ticket Generator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const HomeTabLayout(),
    );
  }
}

class HomeTabLayout extends StatefulWidget {
  const HomeTabLayout({super.key});

  @override
  State<HomeTabLayout> createState() => _HomeTabLayoutState();
}

class _HomeTabLayoutState extends State<HomeTabLayout> {
  bool _isLicensed = true;

  @override
  void initState() {
    super.initState();
    _checkLicense();
  }

  Future<void> _checkLicense() async {
    final prefs = await SharedPreferences.getInstance();
    final String storedKey = prefs.getString('current_license_key') ?? '';
    final String? expirationDateString = prefs.getString('license_expiration_date');

    // Logic to reset the timer if a new key is found
    if (storedKey != kLicenseKey) {
      final newExpirationDate = DateTime.now().add(const Duration(days: 28));
      await prefs.setString('current_license_key', kLicenseKey);
      await prefs.setString('license_expiration_date', newExpirationDate.toIso8601String());
      _isLicensed = true;
      if (mounted) {
        setState(() {});
      }
    } else if (expirationDateString != null) {
      final expirationDate = DateTime.parse(expirationDateString);
      // Check if the current time is after the expiration time
      _isLicensed = DateTime.now().isBefore(expirationDate);
      if (mounted) {
        // We MUST call setState here to rebuild the UI with the new state
        setState(() {});
      }
    } else {
      // As a fallback, grant a license
      _isLicensed = true;
      if (mounted) {
        setState(() {});
      }
    }

    if (!_isLicensed && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showExpiredDialog(context);
      });
    }
  }

  // Dialog that forces the app to close
  void _showExpiredDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevents closing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          //title: const Text(" "),
          content: const Text("Error code:256 \nvoid_form null"),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                SystemNavigator.pop(); // This forces the app to close
              },
              child: const Text('Close App'),
            ),
          ],
        );
      },
    );
  }

  // Callback for regeneration - ensures TicketPreviewList can be refreshed
  void _onTicketGenerated() {
    setState(() {}); // Refresh list tab (triggers rebuild of TabBarView children)
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLicensed) {
      // Show an empty screen while the dialog is visible
      return const Scaffold(body: Center(child: Text("License Expired. Exiting...")));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Ticket Generator"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Input Text"),
              Tab(text: "Generated Tickets"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            TicketFormPage(onTicketGenerated: _onTicketGenerated),
            const TicketPreviewList(),
          ],
        ),
      ),
    );
  }
}