import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:microtek_mobile_app/views/uploading_data.dart';
import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  bool _isValidating = false;
  bool _isValidJob = false;
  String? _validationMessage;
  String? _userId;
  bool _isLoadingUserId = true;
  Timer? _debounceTimer;
  final Duration _debounceDelay = const Duration(milliseconds: 2000);

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    serviceRequestNumber.dispose();
    batterySerialController.dispose();
    super.dispose();
  }

  Future<void> _loadUserId() async {
    _userId = await storage.read(key: 'user_id');
  }

//   Future<void> _loadUserId() async {
//   try {
//     setState(() {
//       _isLoadingUserId = true;
//       _userId = null; // Clear previous value while loading
//     });

//     final token = await storage.read(key: 'userToken');
//     if (token == null) {
//       throw Exception('User token not found');
//     }

//     final response = await http.get(
//       Uri.parse('https://met.microtek.in/app-users/profile/details/$token'),
//     ).timeout(const Duration(seconds: 10));

//     if (!mounted) return;

//     if (response.statusCode == 200) {
//       final data = json.decode(response.body);
//       final userIdStr = data['user_id']?.toString();

//       if (userIdStr == null || userIdStr.isEmpty) {
//         throw Exception('User ID not found in response');
//       }

//       setState(() {
//         _userId = int.tryParse(userIdStr);
//         _isLoadingUserId = false;
//       });

//       if (_userId == null) {
//         throw Exception('Invalid user ID format: $userIdStr');
//       }
//     } else {
//       throw Exception('API request failed with status ${response.statusCode}');
//     }
//   } catch (e) {
//     if (mounted) {
//       setState(() {
//         _isLoadingUserId = false;
//       });
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Failed to load user ID: ${e.toString()}'),
//           action: SnackBarAction(
//             label: 'Retry',
//             onPressed: _loadUserId,
//           ),
//         ),
//       );
//     }
//   }
// }

  bool _areAllFieldsFilled() {
    return serviceRequestNumber.text.isNotEmpty &&
        batterySerialController.text.isNotEmpty &&
        batterySystem != null;
  }

  void _onTextChanged() {
    if (!_areAllFieldsFilled()) {
      setState(() {
        _validationMessage = null;
        _isValidJob = false;
      });
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, () {
      if (_areAllFieldsFilled()) {
        _validateJobDetails();
      }
    });
  }

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
          if (_areAllFieldsFilled()) {
            _validateJobDetails();
          }
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

  Future<void> _validateJobDetails() async {
    if (!_areAllFieldsFilled()) {
      setState(() {
        _isValidJob = false;
      });
      return;
    }

    if (_formKey.currentState!.validate() && _userId != null) {
      setState(() {
        _isValidating = true;
        _isValidJob = false;
      });

      try {
        final url = Uri.parse(
          'https://microtek.cancrm.in/crm_api/getReplJobStatusDMS.php?'
          'job_no=${serviceRequestNumber.text}&'
          'old_serial=${batterySerialController.text}&'
          'crm_eng_id=$_userId',
        );

        final response = await http.get(url);
        if (response.statusCode == 200) {
          final List<dynamic> responseData = json.decode(response.body);
          if (responseData.isNotEmpty) {
            final result = responseData.first;
            if (result['res_code'] == 1) {
              setState(() {
                _isValidJob = true;
              });
              // ScaffoldMessenger.of(context).showSnackBar(
              //   SnackBar(
              //     content: Text('Validation successful'),
              //     backgroundColor: Colors.green,
              //     duration: Duration(seconds: 3),
              //   ),
              // );
            } else {
              String errorMessage = result['res_msg'] ?? 'Invalid details';

              // Customize error messages based on API response
              String userFriendlyMessage;
              if (errorMessage.toLowerCase().contains('job')) {
                userFriendlyMessage = 'Service Request Number is not valid';
              } else if (errorMessage.toLowerCase().contains('serial')) {
                userFriendlyMessage = 'Battery Serial Number is not valid';
              } else {
                userFriendlyMessage = errorMessage;
              }

              setState(() {
                _isValidJob = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(userFriendlyMessage),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        } else {
          setState(() {
            _isValidJob = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connection error. Please try again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isValidJob = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection error. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      } finally {
        setState(() {
          _isValidating = false;
        });
      }
    }
  }

  void proceed() async {
    if (_formKey.currentState!.validate() && _isValidJob) {
      try {
        final token = await storage.read(key: 'userToken');
        if (token == null) {
          throw Exception('User token not found');
        }

        Map<String, dynamic> data = {
          "token": token,
          "customer_name": serviceRequestNumber.text,
          "battery_system": batterySystem,
          "batter_serial_no_1": batterySerialController.text,
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
            SnackBar(
              content: Text('Error: ${e.toString()}'),
            ),
          );
        }
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
                buildTextField(
                  "Service Request Number*",
                  serviceRequestNumber,
                  required: true,
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
                const SizedBox(height: 16),
                if (_isValidating)
                  const Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Validating credentials...'),
                    ],
                  ),
                if (_areAllFieldsFilled() && !_isValidating && !_isValidJob)
                  ElevatedButton(
                    onPressed: _validateJobDetails,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue,
                    ),
                    child: const Text('Revalidate Credentials'),
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
      items: ["12V"]
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: (value) {
        setState(() => batterySystem = value);
        _onTextChanged();
      },
      validator: (value) =>
          value == null ? "Please select a battery system" : null,
    );
  }

  Widget _buildProceedButton() {
    return BottomAppBar(
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: _isValidJob ? proceed : null,
          style: TextButton.styleFrom(
            backgroundColor:
                _isValidJob ? const Color(0xFF1D4694) : Colors.grey.shade400,
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
    bool hasQrIcon = false,
    VoidCallback? onQrPressed,
  }) {
    return TextFormField(
      controller: controller,
      onChanged: (_) => _onTextChanged(),
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
        return !_isProcessing;
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
