// ticket_preview.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// Define a consistent primary blue color for the app
const Color kPrimaryBlue = Color(0xFF0558D4);

class TicketPreviewPage extends StatefulWidget {
  final List<Map<String, dynamic>> tickets; // NEW: The full list of tickets
  final int initialIndex; // CHANGED: The index of the ticket to show first

  const TicketPreviewPage({
    super.key,
    required this.tickets,
    required this.initialIndex,
  });

  @override
  _TicketPreviewPageState createState() => _TicketPreviewPageState();
}

class _TicketPreviewPageState extends State<TicketPreviewPage> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Moved the date check logic to a reusable function
  bool _isEventSoon(Map<String, dynamic> ticketData) {
    try {
      final formatter = DateFormat("EEE, dd MMM yyyy, HH:mm");
      final eventDateTime = formatter.parse(ticketData['datetime']!);
      final now = DateTime.now();
      final eventDateStart = DateTime(eventDateTime.year, eventDateTime.month, eventDateTime.day);
      final todayStart = DateTime(now.year, now.month, now.day);
      final difference = eventDateStart.difference(todayStart);
      return difference.inDays >= 0 && difference.inDays <= 3;
    } catch (e) {
      print("Error parsing date: $e");
      return false;
    }
  }

  Future<void> _deleteTicket() async {
    bool confirm = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Ticket'),
        content: const Text('Are you sure you want to delete this ticket?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    // Deletion is now handled in the list page, which is reloaded after this page is popped.
    if (confirm) Navigator.pop(context, true);
  }

  Future<void> _saveAsPDF() async {
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Storage permission is required to save PDF")),
      );
      return;
    }
    final pdf = pw.Document();
    final currentTicket = widget.tickets[_currentIndex];
    Uint8List imageBytes = Uint8List(0);
    if (currentTicket['imageUrl'] != null && currentTicket['imageUrl'].isNotEmpty) {
      imageBytes = await _loadNetworkImageBytes(currentTicket['imageUrl']);
    }
    final imageProvider = imageBytes.isNotEmpty ? pw.MemoryImage(imageBytes) : null;
    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (imageProvider != null)
                pw.Container(
                  width: double.infinity,
                  height: 200,
                  child: pw.Image(imageProvider, fit: pw.BoxFit.cover),
                ),
              pw.SizedBox(height: 20),
              pw.Text("Title: ${currentTicket['imageTitle']}"),
              pw.Text("Header: ${currentTicket['header']}"),
              pw.Text("Section: ${currentTicket['sec']} | Row: ${currentTicket['row']} | Seat: ${currentTicket['seat']}"),
              pw.Text("Date & Time: ${currentTicket['datetime']}"),
              pw.Text("Location: ${currentTicket['location']}"),
              if ((currentTicket['level']?.isNotEmpty ?? false) || (currentTicket['count']?.isNotEmpty ?? false))
                pw.Text("Level: ${currentTicket['level']} | Count: ${currentTicket['count']}"),
            ],
          );
        },
      ),
    );
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) throw Exception("Could not access storage directory");
      final file = File('${dir.path}/Ticket_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("PDF saved to ${file.path}")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving PDF: ${e.toString()}")),
      );
    }
  }

  Future<Uint8List> _loadNetworkImageBytes(String url) async {
    try {
      final uri = Uri.parse(url);
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(uri);
      final response = await request.close();
      final List<int> bytesList = [];
      await for (var byte in response) {
        bytesList.addAll(byte);
      }
      return Uint8List.fromList(bytesList);
    } catch (e) {
      return Uint8List(0);
    }
  }

  Widget _topText(String label, String? value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(
          value ?? '',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileTicketSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 16.0),
      child: Column(
        children: [
          const Text(
            'Mobile Ticket',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('View Mobile Ticket pressed')));
              },
              icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
              label: const Text('View Ticket', style: TextStyle(fontSize: 13, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket Details pressed')));
            },
            child: Text('Ticket Details', style: TextStyle(color: kPrimaryBlue, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultBarcodeSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      child: Column(
        children: [
          Icon(Icons.qr_code_2, size: 17, color: Colors.grey[700]),
          const SizedBox(height: 8),
          const Text(
            'Your barcode will be ready before the event',
            style: TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton('View Ticket', () { /* Handle View Ticket */ }),
              _buildActionButton('Ticket Details', () { /* Handle Ticket Details */ }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: kPrimaryBlue,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
      child: Text(text),
    );
  }

  Widget _buildBottomActionButton(String text, VoidCallback onPressed, {required bool isActive}) {
    if (!isActive) {
      return OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black54,
          side: const BorderSide(color: Colors.grey),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        child: Text(text),
      );
    } else {
      return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          elevation: 0,
        ),
        child: Text(text),
      );
    }
  }

  // NEW: Helper method to build the page indicator
  Widget _buildIndicator(int totalPages, int currentIndex) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalPages, (index) {
        return Container(
          width: 4.0,
          height: 8.0,
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: currentIndex == index ? kPrimaryBlue : Colors.grey.withOpacity(0.5),
          ),
        );
      }),
    );
  }



  @override
  Widget build(BuildContext context) {
    final ticket = widget.tickets[_currentIndex];
    final isEventSoon = _isEventSoon(ticket);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('My Tickets', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 17)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Help button pressed')));
            },
            child: const Text('Help', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
          const SizedBox(width: 8),
        ],
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.tickets.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final currentTicket = widget.tickets[index];
          final isEventSoonForCurrentTicket = _isEventSoon(currentTicket);

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 360,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white,
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(2, 4))],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 🔵 TOP BLUE BAR
                        Container(
                          decoration: const BoxDecoration(
                            color: kPrimaryBlue,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                          ),
                          padding: const EdgeInsets.only(top: 10, bottom: 40), // <--- Removed horizontal padding here
                          child: Stack(
                            children: [
                              // Header text (e.g., "Adult")
                              Align(
                                alignment: Alignment.topCenter,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 30.0), // <--- Added padding just for the header
                                  child: Text(
                                    currentTicket['header'] ?? 'Adult',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              // Info Icon (top right) - Now positioned
                              Positioned(
                                top: 0,
                                right: 4, // <--- Adjust this value to move the icon left or right
                                child: const Icon(
                                  Icons.info_outline,
                                  color: Colors.white,
                                  size: 25,
                                ),
                              ),


                              // SEC/ROW/SEAT Row
                             /*
                              Padding(
                                padding: const EdgeInsets.only(top: 60.0, left: 30, right: 30), // <--- Added independent padding for this Row
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _topText('SEC', currentTicket['sec']),
                                    _topText('ROW', currentTicket['row']),
                                    _topText('SEAT', currentTicket['seat']),
                                  ],
                                ),
                              ),

                              */

                              Padding(
                                padding: const EdgeInsets.only(top: 60.0, left: 30, right: 30),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(width: 00), // Initial space on the left side
                                    _topText('SEC', currentTicket['sec']),
                                    const SizedBox(width: 85), // Space between SEC and ROW
                                    _topText('ROW', currentTicket['row']),
                                    const Spacer(), // Pushes SEAT to the far right
                                    _topText('SEAT', currentTicket['seat']),
                                    const SizedBox(width: 00), // Space on the right side
                                  ],
                                ),
                              ),

                            ],
                          ),
                        ),



                        // 🖼 IMAGE AREA
                        Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Image.network(
                              currentTicket['imageUrl']!,
                              height: 250,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 250,
                                width: double.infinity,
                                color: Colors.grey[300],
                                child: Icon(Icons.broken_image, size: 60, color: Colors.grey[600]),
                              ),
                            ),
                            // Gradient overlay
                            Container(
                              height: 250,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)], // Stronger gradient for better contrast
                                ),
                              ),
                            ),
                            // Text over image
                            Positioned(
                              bottom: 16,
                              left: 16,
                              right: 16,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    currentTicket['imageTitle'] ?? '',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      height: 1.2,
                                      fontWeight: FontWeight.w700,
                                      shadows: [
                                        Shadow(
                                          offset: const Offset(1.0, 1.0), // Reduced offset
                                          blurRadius: 2.0, // Reduced blur
                                          color: Colors.black.withOpacity(0.5), // Reduced opacity
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 1),
                                  if ((currentTicket['level']?.isNotEmpty ?? false) || (currentTicket['count']?.isNotEmpty ?? false))
                                    Text(
                                          () {
                                        final String levelText = (currentTicket['level']?.isNotEmpty ?? false) ? '${currentTicket['level']}' : '';
                                        final String countText = (currentTicket['count']?.isNotEmpty ?? false) ? '${currentTicket['count']}' : '';
                                        if (levelText.isNotEmpty && countText.isNotEmpty) {
                                          return '$levelText • $countText';
                                        } else if (levelText.isNotEmpty) {
                                          return levelText;
                                        } else {
                                          return countText;
                                        }
                                      }(),
                                      style: TextStyle(
                                        color: Colors.white,
                                        height: 1.3,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        shadows: [
                                          Shadow(
                                            offset: const Offset(1.0, 1.0),
                                            blurRadius: 2.0,
                                            color: Colors.black.withOpacity(0.5),
                                          ),
                                        ],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${currentTicket['datetime']} • ${currentTicket['location']}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.2,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          offset: const Offset(1.0, 1.0),
                                          blurRadius: 2.0,
                                          color: Colors.black.withOpacity(0.4),
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),



                        // 🎟 CONDITIONAL BOTTOM SECTION
                        isEventSoonForCurrentTicket ? _buildMobileTicketSection() : _buildDefaultBarcodeSection(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildIndicator(widget.tickets.length, index),
                const SizedBox(height: 24),
                // Corrected Conditional Buttons: Always visible, but 'Transfer' is only active when event is not soon
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildBottomActionButton('Transfer', () {}, isActive: isEventSoonForCurrentTicket), // Corrected logic
                    _buildBottomActionButton('Sell', () {}, isActive: true),
                    _buildBottomActionButton('Orders', () {}, isActive: true),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }


}