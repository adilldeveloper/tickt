// ticket_preview_list.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'ticket_preview.dart'; // Corrected import to match your file structure

class TicketPreviewList extends StatefulWidget {
  const TicketPreviewList({super.key});

  @override
  State<TicketPreviewList> createState() => _TicketPreviewListState();
}

class _TicketPreviewListState extends State<TicketPreviewList> {
  List<Map<String, dynamic>> tickets = [];

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> storedTickets = prefs.getStringList('tickets') ?? [];
    setState(() {
      tickets = storedTickets.map((t) => jsonDecode(t)).toList().cast<Map<String, dynamic>>();
    });
  }

  Future<void> _deleteTicket(int index) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Ticket'),
          content: const Text('Are you sure you want to delete this ticket?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> storedTickets = prefs.getStringList('tickets') ?? [];
      storedTickets.removeAt(index);
      await prefs.setStringList('tickets', storedTickets);
      setState(() {
        tickets.removeAt(index);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ticket deleted successfully!")),
      );
    }
  }


  Future<void> _saveAsPdf(Map<String, dynamic> ticket) async {
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Storage permission is required to save PDF")),
      );
      return;
    }

    final pdf = pw.Document();
    final imageBytes = await _loadNetworkImageBytes(ticket['imageUrl']);
    final image = pw.MemoryImage(imageBytes);

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              height: 200,
              child: pw.Image(image, fit: pw.BoxFit.cover),
            ),
            pw.SizedBox(height: 20),
            pw.Text("Title: ${ticket['imageTitle']}"),
            pw.Text("Header: ${ticket['header']}"),
            pw.Text("Section: ${ticket['sec']} | Row: ${ticket['row']} | Seat: ${ticket['seat']}"),
            pw.Text("Date & Time: ${ticket['datetime']}"),
            pw.Text("Location: ${ticket['location']}"),
            pw.Text("Level: ${ticket['level']} | Count: ${ticket['count']}"),
          ],
        ),
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


  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return const Center(child: Text("No tickets generated yet."));
    }

    return ListView.builder(
      itemCount: tickets.length,
      itemBuilder: (context, index) {
        final t = tickets[index];
        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: GestureDetector(
            onTap: () async {
              final bool? deleted = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TicketPreviewPage(
                    tickets: tickets, // PASS THE FULL LIST
                    initialIndex: index, // PASS THE INDEX
                  ),
                ),
              );

              if (deleted == true) {
                _loadTickets();
              }
            },
            onLongPress: () => _deleteTicket(index),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
              ),
              child: Column(
                children: [
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      image: DecorationImage(
                        image: NetworkImage(t['imageUrl']),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.4),
                          BlendMode.darken,
                        ),
                      ),
                    ),
                    alignment: Alignment.bottomLeft,
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(t['imageTitle'], style: TextStyle(color: Colors.white, fontSize: 18)),
                        Text('SEC ${t['sec']} | ROW ${t['row']} | SEAT ${t['seat']}', style: TextStyle(color: Colors.white)),
                        Text('${t['datetime']} - ${t['location']}', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}