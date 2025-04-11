import 'dart:async';
import 'package:flutter/material.dart';
import 'package:microtek_mobile_app/views/device_details.dart';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class DownloadingReport extends StatefulWidget {
  final String pdfFileName;
  final BluetoothDevice? device;

  const DownloadingReport({super.key, required this.pdfFileName, this.device});

  @override
  State<DownloadingReport> createState() => _DownloadingReportState();
}

class _DownloadingReportState extends State<DownloadingReport> {
  final storage = const FlutterSecureStorage();
  double progress = 0.0;
  int dotCount = 1; // For animated dots
  bool isFetching = true;

  @override
  void initState() {
    super.initState();
    print("pdfFileName: ${widget.pdfFileName}");
    downloadAndOpenPDF(widget.pdfFileName);
    simulateProgress();
    animateDots();
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

  // Simulate progress bar filling up gradually
  void simulateProgress() {
    Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (!isFetching) {
        setState(() {
          progress = 1.0;
        });
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 500), () {
          navigateToNextScreen();
        });
      } else {
        setState(() {
          progress += 0.1;
          if (progress >= 0.9) progress = 0.9; // Cap at 90% while waiting
        });
      }
    });
  }

  Future<void> downloadAndOpenPDF(String fileName) async {
    final String url = "https://met.microtek.in/pdf-report/$fileName";

    try {
      isFetching = false;
      // // Request storage permission (only for Android)
      // if (Platform.isAndroid) {
      //   var status = await Permission.storage.request();
      //   if (!status.isGranted) {
      //     print("Permission denied");
      //     return;
      //   }
      // }

      // Get downloads directory
      Directory? directory =
          await getDownloadsDirectory() ?? await getExternalStorageDirectory();

      String filePath = "${directory?.path}/$fileName";

      // Make GET request to download the PDF
      var response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        File file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        print("PDF saved at: $filePath");
        OpenFile.open(filePath);
        snackbarFunction("PDF downloaded successfully");
        // Open the PDF file
      } else {
        print("Failed to download PDF. Status Code: ${response.statusCode}");
        snackbarFunction("Failed to download PDF");
      }
    } catch (e) {
      print("Error downloading PDF: $e");
      snackbarFunction("Error downloading PDF");
    } finally {
      isFetching = true;
    }
  }

  void navigateToNextScreen() async {
    await storage.delete(key: 'csvFilePath');
    final pageIndex = await storage.read(key: 'pageIndex');
    print("navigation");
    switch (pageIndex) {
      case '0':
        Navigator.pushReplacement(
          this.context,
          MaterialPageRoute(
            builder: (buildContext) => DeviceDetailsPage(device: widget.device),
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
  }

  // Animate the `...` effect (dots repeating)
  void animateDots() {
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        dotCount = (dotCount % 3) + 1; // Cycle between 1, 2, 3 dots
      });
    });
  }

  String generateDisplayText() {
    String dots = '.' * dotCount;
    return "Downloading report$dots";
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
                          value: index == 0 || index == 1 || index == 2
                              ? 1.0
                              : (index == 3 ? progress : 0),
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
                        "Downloading report...",
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
