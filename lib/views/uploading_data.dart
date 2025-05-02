import 'dart:async';
import 'package:flutter/material.dart';
import 'package:microtek_mobile_app/views/device_details.dart';
import 'package:microtek_mobile_app/views/generting_report.dart';

import 'dart:io';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';

class UploadingData extends StatefulWidget {
  final Map<String, dynamic> data;
  final BluetoothDevice? device;

  const UploadingData({super.key, required this.data, this.device});

  @override
  State<UploadingData> createState() => _UploadingDataState();
}

class _UploadingDataState extends State<UploadingData> {
  final storage = const FlutterSecureStorage();
  double progress = 0.0;
  int dotCount = 1; // For animated dots
  bool isFetching = true; // Track API fetching
  String fileUploadId = '';

  Timer? _progressTimer;
  Timer? _dotsTimer;

  @override
  void initState() {
    super.initState();
    uploadSystemDetails();
    simulateProgress();
    animateDots();
  }

  // Simulate progress bar filling up gradually

  void simulateProgress() {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (!isFetching) {
        if (mounted) {
          setState(() {
            progress = 1.0;
          });
        }
        timer.cancel();
      } else {
        if (mounted) {
          setState(() {
            progress += 0.1;
            if (progress >= 0.9) progress = 0.9; // Cap at 90% while waiting
          });
        }
      }
    });
  }

  void snackbarFunction(String message) {
    ScaffoldMessenger.of(this.context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: Color(0xFF203344),
        showCloseIcon: true,
        behavior: SnackBarBehavior.floating, // Make it float on top
      ),
    );
  }

  Future<void> moveFileToCache() async {
    final pageIndex = await storage.read(key: 'pageIndex');
    try {
      final path = await storage.read(key: 'csvFilePath');

      // Check if the file path is available
      if (path == null) {
        print("No file path found.");
      } else {
        final file = File(path);

        // Check if the file exists
        if (await file.exists()) {
          final fileName = path.split('/').last;
          final cacheDir = Directory(
              '/storage/emulated/0/Android/data/com.microtek.eyetracker/cache');

          // Ensure the cache directory exists
          if (!await cacheDir.exists()) {
            await cacheDir.create(recursive: true);
          }

          final cachePath = '${cacheDir.path}/$fileName';

          // Move the file
          await file.copy(cachePath);
          final cacheFile = File(cachePath);

          if (await cacheFile.exists()) {
            print("File successfully copied to cache.");
            await file.delete(); // Delete the original file
            print("Original file deleted.");
          } else {
            print("File not found in cache directory after copying.");
          }
        } else {
          print("File does not exist at path: $path");
        }
      }
    } catch (e) {
      print("Error moving file to cache: $e");
    } finally {
      print(
          '+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++');
      switch (pageIndex) {
        case '0':
          Navigator.pushReplacement(
            this.context,
            MaterialPageRoute(
              builder: (buildContext) =>
                  DeviceDetailsPage(device: widget.device),
            ),
          );
          break;
        case '1':
          Navigator.pushReplacementNamed(this.context, '/reports');
          break;
        case '2':
          Navigator.pushReplacementNamed(this.context, '/home');
          break;
        default:
          print('Invalid page index: $pageIndex');
      }

      print(
          '+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++');
    }
  }

  Future<void> uploadSystemDetails() async {
    try {
      isFetching = false;
      final response = await http.post(
          Uri.parse('https://met.microtek.in/app/add-user-info'),
          body: widget.data);
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print(responseData);
        if (responseData['errFlag'] == 0) {
          print(responseData['scannedUserId']);
          // await moveFileToCache();
          snackbarFunction('System details uploaded successfully!');
          await uploadCsvFile(responseData['scannedUserId']);
        } else {
          print(responseData['message']);
          await moveFileToCache();
          snackbarFunction(
              'Failed to upload system details: ${responseData['message']}');
        }
      } else {
        print('Failed to upload system details: ${response.statusCode}');
        await moveFileToCache();
        snackbarFunction(
            'Failed to upload system details: ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading system details: $e');
      await moveFileToCache();
      snackbarFunction('Error uploading system details: $e');
    } finally {
      isFetching = true;
    }
  }

  Future<void> uploadCsvFile(scannedUserInfoId) async {
    final csvFilePath = await storage.read(key: 'csvFilePath');
    final savedDeviceId = await storage.read(
        key: 'deviceId'); // Get the device ID saved in FlutterSecureStorage
    try {
      final csvFile = File(csvFilePath!);
      final csvBytes = await csvFile.readAsBytes();

      // Get the token from FlutterSecureStorage
      final token = await storage.read(key: 'userToken');

      // Create a multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://met.microtek.in/app/scan-file-upload-records'),
      );

      // Add fields
      request.fields['deviceId'] =
          widget.device?.platformName ?? savedDeviceId!;
      request.fields['scannedUserInfoId'] = scannedUserInfoId.toString();
      request.fields['token'] = token ?? '';

      // Attach the file
      request.files.add(http.MultipartFile.fromBytes(
        'scannedFile',
        csvBytes,
        filename: basename(csvFilePath), // Extract file name
      ));
      print(basename(csvFilePath));
      // Send the request
      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      print(responseBody);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(responseBody);
        if (responseData['errFlag'] == 0) {
          print(responseData['fileUploadId']);
          setState(() {
            fileUploadId = responseData['fileUploadId'].toString();
          });
          snackbarFunction('CSV file uploaded successfully!');
          // await storage.delete(key: 'csvFilePath');
          navigateToNextScreen(); // Navigate to the next screen
        } else {
          print("Failed to upload CSV: ${responseData['message']}");
          await moveFileToCache();
          snackbarFunction('Failed to upload CSV: ${responseData['message']}');
        }
      } else {
        print("Failed to upload CSV: ${response.statusCode}");
        await moveFileToCache();
        snackbarFunction('Failed to upload CSV: ${response.statusCode}');
      }
    } catch (e) {
      await moveFileToCache();
      if (e is http.ClientException) {
        print("ClientException occurred.");
        snackbarFunction('Connection error occurred. Please try again.');
      } else {
        print("Unexpected error: $e");
        snackbarFunction('Something went wrong. Please try again.');
      }
    }
  }

  void navigateToNextScreen() {
    print("navigation");
    Navigator.pushReplacement(
      this.context,
      MaterialPageRoute(
        builder: (buildContext) =>
            GenertingReport(fileUploadId: fileUploadId, device: widget.device),
      ),
    );
  }

  // Animate the `...` effect (dots repeating)
  void animateDots() {
    _dotsTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {
          dotCount = (dotCount % 3) + 1; // Cycle between 1, 2, 3 dots
        });
      }
    });
  }

  String generateDisplayText() {
    String dots = '.' * dotCount;
    return "Uploading data to cloud$dots";
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _dotsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: AppBar(
          automaticallyImplyLeading: false,
          title: const Text("Mesha BT device"),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(20),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(4, (index) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: index == 0 ? 1.0 : (index == 1 ? progress : 0),
                          minHeight: 6,
                          backgroundColor: Colors.grey[300],
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  generateDisplayText(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                const Text(
                    'Please do not press back, minimize or close this window.')
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              color: const Color(0xFF203344),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_upload_outlined,
                        color: Colors.white, size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Uploading your data to the cloud...\nPlease make sure to stay connected to the internet.",
                        style:
                            const TextStyle(color: Colors.white, fontSize: 18),
                        softWrap: true,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
