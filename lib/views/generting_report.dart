import 'dart:async';
import 'package:flutter/material.dart';
import 'package:microtek_mobile_app/views/device_details.dart';
import 'package:microtek_mobile_app/views/downloading_report.dart';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class GenertingReport extends StatefulWidget {
  final String fileUploadId;
  final BluetoothDevice? device;

  const GenertingReport({super.key, required this.fileUploadId, this.device});

  @override
  State<GenertingReport> createState() => _GenertingReportState();
}

class _GenertingReportState extends State<GenertingReport> {
  final storage = const FlutterSecureStorage();
  String fileUploadId = '';
  double progress = 0.0;
  int dotCount = 1; // For animated dots
  bool isFetching = true; // Track API fetching

  String pdfFileName = '';

  Timer? _progressTimer;
  Timer? _dotsTimer;

  @override
  void initState() {
    super.initState();
    fileUploadId = widget.fileUploadId;
    print(fileUploadId);
    generatePdfFileName();
    // Start simulating progress only after data is fetched
    simulateProgress();
    animateDots();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _dotsTimer?.cancel();
    super.dispose();
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
        Future.delayed(const Duration(milliseconds: 500), () {
          navigateToNextScreen();
        });
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
              '/storage/emulated/0/Android/data/com.example.microtek_mobile_app/cache');

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

  Future<void> generatePdfFileName() async {
    final token = await storage.read(key: 'userToken');
    try {
      isFetching = true; // Set fetching to true while fetching data
      final data = <String, dynamic>{
        'token': token,
        'scannedFileId': fileUploadId
      };
      print('data to generate pdf: $data');
      final response = await http.post(
          Uri.parse('https://bt.meshaenergy.com/apis/app/get-pdf-report'),
          body: data);
      print(response.body);
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print(responseData);
        if (responseData['errFlag'] == 0) {
          print(responseData['pdfFileName']);
          if (mounted) {
            setState(() {
              pdfFileName = responseData['pdfFileName'].toString();
            });
          }
          snackbarFunction('PDF report generated successfully.');
        } else {
          print(responseData['message']);
          await moveFileToCache();
          snackbarFunction('Failed to generate PDF report.');
        }
      } else {
        print('Failed to generate PDF: ${response.statusCode}');
        await moveFileToCache();
        snackbarFunction('Failed to generate PDF report.');
      }
    } catch (e) {
      print('Error generating PDF: $e');
      await moveFileToCache();
      snackbarFunction('Failed to generate PDF report.');
    } finally {
      if (mounted) {
        setState(() {
          isFetching = false; // Set fetching to false after data is fetched
        });
      }
    }
  }

  void navigateToNextScreen() {
    print("navigation");
    Navigator.pushReplacement(
      this.context,
      MaterialPageRoute(
        builder: (buildContext) =>
            DownloadingReport(pdfFileName: pdfFileName, device: widget.device),
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
    return "Generating report$dots";
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
                          value: index == 0 || index == 1
                              ? 1.0
                              : (index == 2 ? progress : 0),
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
                    const Icon(Icons.insert_drive_file_outlined,
                        color: Colors.white, size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Generating report...",
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
