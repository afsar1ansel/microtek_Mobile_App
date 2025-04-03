import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:microtek_mobile_app/views/uploading_data.dart';

class SystemDetails extends StatefulWidget {
  final BluetoothDevice? device;
  const SystemDetails({super.key, this.device});
  @override
  State<SystemDetails> createState() => _SystemDetailsState();
}

class _SystemDetailsState extends State<SystemDetails> {
  final _formKey = GlobalKey<FormState>();
  final storage = const FlutterSecureStorage();

  TextEditingController serviceRequestNumber = TextEditingController();
  TextEditingController batterySerialController = TextEditingController();
  String? batterySystem;

  Future<void> _scanQRCode() async {
    print("Scanning QR code...");
    // Implement your QR scanning logic here
  }

  void proceed() async {
    if (_formKey.currentState!.validate()) {
      final token = await storage.read(key: 'userToken');
      Map<String, dynamic> data = {
        "token": token,
        "service_request_number": serviceRequestNumber.text,
        "battery_system": batterySystem,
        "battery_serial": batterySerialController.text,
      };

      print(data);

      if (mounted) {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    UploadingData(data: data, device: widget.device)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("System Details"),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Service Request Number
                buildTextField("Service Request Number*", serviceRequestNumber,
                    required: true, validationType: "letters"),
                const SizedBox(height: 16),

                // Battery System Dropdown
                DropdownButtonFormField<String>(
                  value: batterySystem,
                  decoration: InputDecoration(
                    labelText: "Battery System*",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                  ),
                  items: ["12V", "24V"]
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      batterySystem = value;
                    });
                  },
                  validator: (value) =>
                      value == null ? "Please select a battery system" : null,
                ),
                const SizedBox(height: 16),

                // Battery Serial Number with QR Icon inside the TextField
                buildTextField(
                  "Battery Serial Number*",
                  batterySerialController,
                  required: true,
                  hasQrIcon: true,
                  onQrPressed: _scanQRCode,
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: proceed,
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF1D4694),
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
            child: const Text(
              "Proceed",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildTextField(
    String label,
    TextEditingController controller, {
    bool required = false,
    String validationType = "none",
    TextInputType keyboardType = TextInputType.text,
    bool hasQrIcon = false,
    VoidCallback? onQrPressed,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        suffixIcon: hasQrIcon
            ? IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: onQrPressed,
                tooltip: 'Scan QR Code',
              )
            : null,
      ),
      validator: (value) {
        if (required && (value == null || value.isEmpty)) {
          return "This field is required";
        }
        switch (validationType) {
          case "letters":
            if (!RegExp(r"^[a-zA-Z\s]+$").hasMatch(value!)) {
              return "Only letters and spaces allowed";
            }
            break;
          case "mobile":
            if (!RegExp(r"^\d{10}$").hasMatch(value!)) {
              return "Enter a valid 10-digit mobile number";
            }
            break;
          case "alphanumeric":
            if (!RegExp(r"^[a-zA-Z0-9]+$").hasMatch(value!)) {
              return "Only letters and numbers allowed";
            }
            break;
          case "numbers":
            if (!RegExp(r"^\d+$").hasMatch(value!)) {
              return "Only numbers allowed";
            }
            break;
        }
        return null;
      },
    );
  }
}
