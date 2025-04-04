import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:microtek_mobile_app/views/uploading_data.dart';
import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class SystemDetails extends StatefulWidget {
  final BluetoothDevice? device;
  const SystemDetails({super.key, this.device});

  @override
  State<SystemDetails> createState() => _SystemDetailsState();
}

class _SystemDetailsState extends State<SystemDetails> {
  final _formKey = GlobalKey<FormState>();
  final storage = const FlutterSecureStorage();
  final TextEditingController serviceRequestNumber = TextEditingController();
  final TextEditingController batterySerialController = TextEditingController();
  String? batterySystem;
  bool _isScanning = false;

  Future<void> _scanQRCode() async {
    if (_isScanning) return;
    _isScanning = true;

    try {
      final scannedValue = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => const _QRScannerScreen(),
        ),
      );

      if (scannedValue != null && mounted) {
        setState(() {
          batterySerialController.text = scannedValue;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('QR Scan Error: ${e.toString()}')),
        );
      }
    } finally {
      _isScanning = false;
    }
  }

  void proceed() async {
    if (_formKey.currentState!.validate()) {
      try {
        final token = await storage.read(key: 'userToken');
        if (token == null) {
          throw Exception('User token not found');
        }

        Map<String, dynamic> data = {
          "token": token,
          "service_request_number": serviceRequestNumber.text,
          "battery_system": batterySystem,
          "battery_serial": batterySerialController.text,
        };

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  UploadingData(data: data, device: widget.device),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    serviceRequestNumber.dispose();
    batterySerialController.dispose();
    super.dispose();
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
                buildTextField(
                  "Service Request Number*",
                  serviceRequestNumber,
                  required: true,
                  validationType: "letters",
                ),
                const SizedBox(height: 16),
                _buildBatterySystemDropdown(),
                const SizedBox(height: 16),
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
      bottomNavigationBar: _buildProceedButton(),
    );
  }

  Widget _buildBatterySystemDropdown() {
    return DropdownButtonFormField<String>(
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
      onChanged: (value) => setState(() => batterySystem = value),
      validator: (value) =>
          value == null ? "Please select a battery system" : null,
    );
  }

  Widget _buildProceedButton() {
    return BottomAppBar(
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

class _QRScannerScreen extends StatefulWidget {
  const _QRScannerScreen();

  @override
  State<_QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<_QRScannerScreen> {
  late MobileScannerController _controller;
  bool _isProcessing = false;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      returnImage: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return !_isProcessing; // Block back navigation during processing
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Scan QR Code'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (!_isProcessing) {
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: Stack(
          children: [
            AiBarcodeScanner(
              controller: _controller,
              onDetect: _handleBarcode,
              validator: (capture) => capture.barcodes.isNotEmpty,
            ),
            if (_isProcessing)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  void _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing || _hasScanned) return;
    _isProcessing = true;

    try {
      final barcodes = capture.barcodes;
      if (barcodes.isNotEmpty && mounted) {
        final barcode = barcodes.first;
        if (barcode.rawValue != null) {
          _hasScanned = true;
          Navigator.pop(context, barcode.rawValue);
        }
      }
    } catch (e) {
      debugPrint('Barcode processing error: $e');
      if (mounted && !_hasScanned) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error processing QR code')),
        );
      }
    } finally {
      _isProcessing = false;
    }
  }
}
