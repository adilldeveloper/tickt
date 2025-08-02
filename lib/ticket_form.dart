import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // For date and time formatting and selection

class TicketFormPage extends StatefulWidget {
  final VoidCallback onTicketGenerated;

  const TicketFormPage({super.key, 
    required this.onTicketGenerated,
  });

  @override
  State<TicketFormPage> createState() => _TicketFormPageState();
}

class _TicketFormPageState extends State<TicketFormPage> {
  final _formKey = GlobalKey<FormState>(); // Key for form validation

  // Controllers for all input fields
  final TextEditingController headerController = TextEditingController();
  final TextEditingController secController = TextEditingController();
  final TextEditingController rowController = TextEditingController();
  final TextEditingController seatController = TextEditingController();
  final TextEditingController imageUrlController = TextEditingController();
  final TextEditingController imageTitleController = TextEditingController();
  final TextEditingController datetimeController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController levelController = TextEditingController();
  final TextEditingController countController = TextEditingController();

  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  @override
  void initState() {
    super.initState();
    _updateDateTimeController();
  }

  @override
  void dispose() {
    // Dispose all controllers to free up resources
    headerController.dispose();
    secController.dispose();
    rowController.dispose();
    seatController.dispose();
    imageUrlController.dispose();
    imageTitleController.dispose();
    datetimeController.dispose();
    locationController.dispose();
    levelController.dispose();
    countController.dispose();
    super.dispose();
  }

  // Helper to update datetime controller based on selectedDate and selectedTime
  void _updateDateTimeController() {
    if (selectedDate != null && selectedTime != null) {
      final DateTime fullDateTime = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        selectedTime!.hour,
        selectedTime!.minute,
      );
      datetimeController.text = DateFormat('EEE, dd MMM yyyy, HH:mm').format(fullDateTime);
    } else if (selectedDate != null) {
      // If only date is selected, show date
      datetimeController.text = DateFormat('EEE, dd MMM yyyy').format(selectedDate!);
    } else {
      datetimeController.text = ''; // Clear if nothing selected
    }
  }


  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        _updateDateTimeController();
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != selectedTime) {
      setState(() {
        selectedTime = picked;
        _updateDateTimeController();
      });
    }
  }

  Future<void> _generateTicket() async {
    // Check if the form is valid. This will now skip 'Level' and 'Count' validation
    // if they are marked as isRequired: false.
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all required fields.')),
      );
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> storedTickets = prefs.getStringList('tickets') ?? [];

    Map<String, dynamic> newTicketData = {
      'header': headerController.text,
      'sec': secController.text,
      'row': rowController.text,
      'seat': seatController.text,
      'imageUrl': imageUrlController.text,
      'imageTitle': imageTitleController.text,
      'datetime': datetimeController.text,
      'location': locationController.text,
      'level': levelController.text,
      'count': countController.text,
    };

    storedTickets.add(jsonEncode(newTicketData));
    await prefs.setStringList('tickets', storedTickets);

    // Clear form fields after generating
    headerController.clear();
    secController.clear();
    rowController.clear();
    seatController.clear();
    imageUrlController.clear();
    imageTitleController.clear();
    datetimeController.clear();
    locationController.clear();
    levelController.clear();
    countController.clear();
    setState(() {
      selectedDate = null;
      selectedTime = null;
    });


    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Ticket generated successfully!")),
    );

    widget.onTicketGenerated(); // Notify the list tab to refresh
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextField(headerController, 'Header (e.g., Adult - Reserved Seat)'),
            _buildTextField(secController, 'Section (e.g., BK 114)'),
            _buildTextField(rowController, 'Row (e.g., G)'),
            _buildTextField(seatController, 'Seat (e.g., 19)'),
            _buildTextField(imageUrlController, 'Image URL ',
                keyboardType: TextInputType.url),
            _buildTextField(imageTitleController, 'Image Title'),

            // Date & Time Picker
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    datetimeController,
                    'Date & Time',
                    readOnly: true,
                    onTap: () => _selectDate(context),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.access_time),
                  onPressed: () => _selectTime(context),
                ),
              ],
            ),

            _buildTextField(locationController, 'Location (e.g., Alexander Stadium)'),
            _buildTextField(levelController, 'Level (e.g., Main)', isRequired: false),
            _buildTextField(countController, 'Count (e.g., 1)', keyboardType: TextInputType.number, isRequired: false), // <--- 'Count' is now optional!

            SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _generateTicket,
            //icon: Icon(Icons.add),
              label: Text("Generate Ticket"),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12),
                textStyle: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String labelText,
      {TextInputType keyboardType = TextInputType.text,
        bool readOnly = false,
        VoidCallback? onTap,
        Widget? suffixIcon,
        bool isRequired = true // <-- Default is true, meaning required
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          border: OutlineInputBorder(),
          suffixIcon: suffixIcon,
        ),
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        validator: (value) {
          // Only validate if isRequired is true
          if (isRequired && (value == null || value.isEmpty)) {
            return 'Please enter $labelText';
          }
          return null;
        },
      ),
    );
  }
}