import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:path/path.dart';

class RetrievingData extends StatefulWidget {
  final BluetoothDevice device;

  const RetrievingData({super.key, required this.device});

  @override
  State<RetrievingData> createState() => _RetrievingDataState();
}

class _RetrievingDataState extends State<RetrievingData> {
  final storage = const FlutterSecureStorage();
  String? token;
  double progress = 0.0;
  List<dynamic> fetchedData = [];
  bool isFetching = true; // Track API fetching
  int dotCount = 1; // For animated dots

  @override
  void initState() {
    super.initState();
    fetchData();
    simulateProgress();
    animateDots();
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

  Future<void> fetchData() async {
    final csvFilePath = await storage.read(key: 'csvFilePath');
    try {
      final csvFile = File(csvFilePath!);
      final csvBytes = await csvFile.readAsBytes();

      // Get the token from FlutterSecureStorage
      final token = await storage.read(key: 'userToken');

      // Create a multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(
            'https://bt.meshaenergy.com/apis/app/scan-file-upload-records'),
      );

      // Add fields
      request.fields['deviceId'] = widget.device.platformName;
      request.fields['scannedUserInfoId'] = '1';
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
        setState(() {
          isFetching = false;
        });
      } else {
        print("Failed to upload CSV: ${response.statusCode}");
        setState(() {
          isFetching = false;
        });
      }
    } catch (e) {
      print("Error uploading CSV: $e");
      setState(() {
        isFetching = false;
      });
    }
  }

  void navigateToNextScreen() {
    // Navigator.pushReplacement(
    //   this.context,
    //   MaterialPageRoute(
    //     builder: (buildContext) => SystemDetails(data: fetchedData),
    //   ),
    // );
  }

  // Animate the `...` effect (dots repeating)
  void animateDots() {
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        dotCount = (dotCount % 3) + 1; // Cycle between 1, 2, 3 dots
      });
    });
  }

  // Format progress text with animated dots
  String getProgressText() {
    int percentage = (progress * 100).toInt();
    String dots = '.' * dotCount; // Generate dot animation
    return "$percentage% data retrieval in progress stay close to the device$dots";
  }

  String generateDisplayText() {
    String dots = '.' * dotCount; // Generate dot animation
    return "Retrieving Data$dots";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: AppBar(
          title: const Text("M4 Device Name"),
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
                          value: index == 0 ? progress : 0,
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
            child: Center(
              child: Text(
                generateDisplayText(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              color: const Color(0xFF204433),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_download_outlined,
                        color: Colors.white, size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      // Ensures text does not overflow
                      child: Text(
                        getProgressText(),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 18),
                        softWrap: true, // Enables text wrapping
                        overflow: TextOverflow
                            .visible, // Ensures text is fully displayed
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
