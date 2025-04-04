import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math';
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:microtek_mobile_app/views/system_details.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';

class DeviceDetailsPage extends StatefulWidget {
  final BluetoothDevice? device;

  const DeviceDetailsPage({super.key, this.device});

  @override
  State<DeviceDetailsPage> createState() => _DeviceDetailsPageState();
}

class _DeviceDetailsPageState extends State<DeviceDetailsPage> {
  final storage = FlutterSecureStorage();
  BluetoothCharacteristic? txCharacteristic;
  BluetoothCharacteristic? rxCharacteristic;
  List<String> messages = [];
  String? _retrievedData = "";
  final TextEditingController messageController = TextEditingController();
  bool isDeleteConfirmed = false;
  bool isDataRetrievalComplete = true;
  StreamSubscription<List<int>>? _rxSubscription;
  String fileName = '';
  List<FileSystemEntity> files = [];
  List<FileSystemEntity> catchFiles = [];
  String activeFilter = 'pdf'; // Default filter

  @override
  void initState() {
    super.initState();
    connectToDevice(widget.device!);
    fetchFiles();
    moveFileToCache().then((_) => fetchCatchFiles());
  }

  Future<void> fetchCatchFiles() async {
    final cacheDir = Directory(
        '/storage/emulated/0/Android/data/com.example.microtek_mobile_app/cache');
    List<FileSystemEntity> cache_files = [];
    final cacheFiles = cacheDir.listSync();

    // Filter files by device name
    cache_files = cacheFiles.where((file) {
      return file.path.contains(widget.device?.platformName ?? '');
    }).toList();
    print('cache files: $cache_files');
    setState(() {
      catchFiles = cache_files;
    });
  }

  Future<void> fetchFiles() async {
    final fetchedFiles =
        await getFilesFromDirectory(widget.device?.platformName ?? '');
    setState(() {
      files = fetchedFiles.where((file) {
        if (activeFilter == 'pdf') {
          return file.path.endsWith('.pdf'); // Show only PDF files
        } else if (activeFilter == 'csv') {
          return file.path.endsWith('.csv'); // Show only CSV files
        }
        return false; // No other filters
      }).toList();
    });
    print(files);
  }

  Future<List<FileSystemEntity>> getFilesFromDirectory(
      String deviceName) async {
    Directory? directory = await getExternalStorageDirectory();
    Directory? downloadsDirectory = await getDownloadsDirectory();

    List<FileSystemEntity> files = [];

    if (directory != null) {
      files.addAll(directory.listSync());
    }

    if (downloadsDirectory != null) {
      files.addAll(downloadsDirectory.listSync());
    }

    // Filter files by device name
    files = files.where((file) {
      return file.path.contains(deviceName);
    }).toList();

    return files;
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes bytes'; // Less than 1 KB
    } else if (bytes < 1024 * 1024) {
      double kb = bytes / 1024;
      return '${kb.toStringAsFixed(2)} KB'; // Between 1 KB and 1 MB
    } else {
      double mb = bytes / (1024 * 1024);
      return '${mb.toStringAsFixed(2)} MB'; // Greater than 1 MB
    }
  }

  String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}'; // Customize the date format as needed
  }

  Future<void> moveFileToCache() async {
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
    }
  }

  /// Connect to a Selected Device
  void connectToDevice(BluetoothDevice device) async {
    await device.connect();
    discoverServices();
  }

  /// Discover Bluetooth Services
  void discoverServices() async {
    List<BluetoothService>? services = await widget.device?.discoverServices();
    for (var service in services!) {
      if (service.uuid == Guid("0000FFF0-0000-1000-8000-00805F9B34FB")) {
        for (var char in service.characteristics) {
          if (char.uuid == Guid("0000FFF2-0000-1000-8000-00805F9B34FB") &&
              char.properties.write) {
            txCharacteristic = char;
          }
          if (char.uuid == Guid("0000FFF1-0000-1000-8000-00805F9B34FB") &&
              (char.properties.notify || char.properties.read)) {
            rxCharacteristic = char;
            rxCharacteristic!.setNotifyValue(true);
            _rxSubscription = rxCharacteristic!.lastValueStream.listen((value) {
              if (!mounted) return; // Check if the widget is still mounted
              String receivedData = String.fromCharCodes(value);
              setState(() {
                print("Received: $receivedData");
                messages.add("Received: $receivedData");
                _retrievedData = _retrievedData! + receivedData;
                // print(_retrievedData);

                // Check for "NO RECORDS" and trigger sendData() after 1 minute
                if (_retrievedData!.trim() == "NO RECORDS") {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'No Records Found. Please wait for 1 minute before Retirving Data...'),
                      backgroundColor: Color(0xFF203344),
                      showCloseIcon: true,
                      behavior:
                          SnackBarBehavior.floating, // Make it float on top
                    ),
                  );
                  isDataRetrievalComplete = true;
                  Navigator.of(context).pop(); // Close the dialog
                }
                // Check if the received data indicates the end of transmission
                if (_retrievedData!.contains("END")) {
                  isDataRetrievalComplete = true;
                  convertAndSaveCSV(); // Automatically convert and save CSV
                  Navigator.of(context).pop(); // Close the dialog
                }
              });
            });
          }
        }
      }
    }
  }

  void convertAndSaveCSV() async {
    try {
      final isPathEmpaty = await storage.read(key: 'csvFilePath');
      print('Test Path: $isPathEmpaty');
      if (isPathEmpaty != null) {
        print("CSV file already saved at: $isPathEmpaty");
        moveFileToCache();
      }
    } catch (e) {
      print("Error reading from secure storage: $e");
      // Handle the error, e.g., by showing a message to the user or taking other appropriate actions
    }
    if (!isDataRetrievalComplete) return; // Ensure data retrieval is complete

    List<String> rows = _retrievedData!.split('\n');
    if (rows.isEmpty) return; // Ensure there are rows to process

    List<String> headers = 'SN,Date,Time,B1,C'.split(',');

    List<Map<String, dynamic>> allData = [];

    for (int i = 0; i < rows.length - 2; i++) {
      if (rows[i].isEmpty) continue; // Skip empty rows
      if (rows[i].contains("SN")) continue;
      List<String> row = rows[i].split(',');
      if (row.length == 5) {
        headers = 'SN,Date,Time,B1,C'.split(',');
      } else if (row.length == 6) {
        headers = 'SN,Date,Time,B1,C,T'.split(',');
      } else if (row.length == 7) {
        headers = 'SN,Date,Time,B1,B2,C,T'.split(',');
      }
      if (row.length < headers.length) {
        continue;
      }
      // Skip rows with insufficient data

      Map<String, dynamic> data = {};

      for (int j = 0; j < headers.length; j++) {
        data[headers[j]] = row[j];
      }
      allData.add(data);
    }

    List<List<String>> csvData = [
      headers,
      ...allData.map(
        (map) =>
            headers.map((header) => (map[header] ?? "").toString()).toList(),
      )
    ];

    String csvString = const ListToCsvConverter().convert(csvData);

    final directory = await getExternalStorageDirectory();

    // Get current date and time
    String formattedDateTime =
        DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());

    // Generate filename with platform name and date-time
    fileName = "${widget.device?.platformName}_$formattedDateTime.csv";
    final path = "${directory?.path}/$fileName";

    final file = File(path);
    await file.writeAsString(csvString);
    await storage.write(key: 'csvFilePath', value: path);
    print("CSV file saved at: $path");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Data Retrieved Successfully.'),
        backgroundColor: Color(0xFF203344),
        showCloseIcon: true,
        behavior: SnackBarBehavior.floating, // Make it float on top
      ),
    );
    deleteData();
    if (mounted) {
      await storage.write(key: 'pageIndex', value: '0');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SystemDetails(device: widget.device),
        ),
      );
    }
  }

  /// Send Data to Bluetooth Device
  void sendData(String data) async {
    if (txCharacteristic != null) {
      await txCharacteristic!.write(data.codeUnits);
    }
  }

  /// Send *GET$ Command to Retrieve Data
  void retrieveData() async {
    _retrievedData = "";
    isDataRetrievalComplete = false; // Reset the flag
    sendData("*GET\$");
    _showRetrievingDataDialog(); // Show the dialog
  }

  void _showRetrievingDataDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Retrieving Data'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Center(
                  child: Text(
                    'Please wait while data is being retrieved...',
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 20),
                Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// Send *DELETE$ Command
  void deleteData() {
    _retrievedData = "";
    sendData("*DELETE\$"); // First delete command
    setState(() {
      isDeleteConfirmed = !isDeleteConfirmed; // Toggle the button text
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      sendData("*DELETE\$"); // Second delete command after a short delay
      setState(() {
        isDeleteConfirmed = !isDeleteConfirmed; // Toggle the button text
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Data Deleted Successfully. Please wait for 1 minute before Retirving Data...'),
          backgroundColor: Color(0xFF203344),
          showCloseIcon: true,
          behavior: SnackBarBehavior.floating, // Make it float on top
        ),
      );
    });
  }

  // Variables to store selected dates and times
  DateTime? fromDate;
  TimeOfDay? fromTime;
  DateTime? toDate;
  TimeOfDay? toTime;

  // Function to show the date-time picker bottom sheet
  void _showDateTimePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              padding: EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 8.0,
                bottom: 16.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  Container(
                    width: 80,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  SizedBox(
                    height: 12.0,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select date and time range',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const Text("Done"),
                    ],
                  ),
                  const Divider(
                    height: 16,
                  ),
                  // From Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const Text('Start time',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      // Select Date Button
                      TextButton(
                        onPressed: () async {
                          final selectedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (selectedDate != null) {
                            setState(() {
                              fromDate = selectedDate;
                            });
                          }
                        },
                        style: TextButton.styleFrom(
                          minimumSize: const Size(100, 40),
                          backgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                        child: Text(
                          fromDate != null
                              ? '${fromDate!.toLocal()}'.split(' ')[0]
                              : 'Select Date',
                        ),
                      ),
                      const SizedBox(
                        width: 10.0,
                      ),
                      // Select Time Button
                      TextButton(
                        onPressed: () async {
                          final selectedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (selectedTime != null) {
                            setState(() {
                              fromTime = selectedTime;
                            });
                          }
                        },
                        style: TextButton.styleFrom(
                          minimumSize: const Size(100, 40),
                          backgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                        child: Text(
                          fromTime != null
                              ? '${fromTime!.format(context)}'
                              : 'Select Time',
                        ),
                      ),
                    ],
                  ),
                  const Divider(
                    height: 16,
                  ),

                  // To Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const Text('End time',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      // Select Date Button
                      TextButton(
                        onPressed: () async {
                          final selectedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (selectedDate != null) {
                            setState(() {
                              toDate = selectedDate;
                            });
                          }
                        },
                        style: TextButton.styleFrom(
                          minimumSize: const Size(100, 40),
                          backgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                        child: Text(
                          toDate != null
                              ? '${toDate!.toLocal()}'.split(' ')[0]
                              : 'Select Date',
                        ),
                      ),
                      const SizedBox(
                        width: 10.0,
                      ),
                      // Select Time Button
                      TextButton(
                        onPressed: () async {
                          final selectedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (selectedTime != null) {
                            setState(() {
                              toTime = selectedTime;
                            });
                          }
                        },
                        style: TextButton.styleFrom(
                          minimumSize: const Size(100, 40),
                          backgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                        ),
                        child: Text(
                          toTime != null
                              ? '${toTime!.format(context)}'
                              : 'Select Time',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Download Report Button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        if (fromDate != null &&
                            fromTime != null &&
                            toDate != null &&
                            toTime != null) {
                          final fromDateTime = DateTime(
                            fromDate!.year,
                            fromDate!.month,
                            fromDate!.day,
                            fromTime!.hour,
                            fromTime!.minute,
                          );
                          final toDateTime = DateTime(
                            toDate!.year,
                            toDate!.month,
                            toDate!.day,
                            toTime!.hour,
                            toTime!.minute,
                          );
                          print('From Date and Time: $fromDateTime');
                          print('To Date and Time: $toDateTime');
                          Navigator.pop(context); // Close the bottom sheet
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Please select both From and To dates and times.'),
                            ),
                          );
                        }
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4694),
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                      child: const Text(
                        'Download Report',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _rxSubscription?.cancel(); // Cancel the subscription
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.device?.platformName ?? 'Mesha BT Device',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Device Paired',
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pending Reports Section
              const Text(
                'Pending Reports',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: catchFiles.length,
                itemBuilder: (context, index) {
                  final file = catchFiles[index];
                  return Column(
                    children: [
                      ListTile(
                        onTap: () => _openFile(file),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 0,
                        ),
                        leading: SvgPicture.asset(
                          file.path.endsWith('.csv')
                              ? 'assets/svg/csv.svg'
                              : 'assets/svg/pdf.svg',
                          width: 40,
                          height: 40,
                        ),
                        title: Text(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          file.path.split('/').last,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Text(
                              formatDate(file
                                  .statSync()
                                  .modified), // Display last modified date
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(
                                width:
                                    8), // Add some spacing between the date and file size
                            Text(
                              formatFileSize(file
                                  .statSync()
                                  .size), // Display formatted file size
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 40,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.arrow_circle_up_rounded,
                                  color: Colors.blue,
                                ),
                                onPressed: () {
                                  _uploadFileToCloud(file);
                                },
                              ),
                            ),
                            SizedBox(
                              width: 35,
                              child: IconButton(
                                icon: Icon(Icons.cloud_off_rounded,
                                    color: Colors.red),
                                onPressed: () {},
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),

              // Reports Generated Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Reports Generated',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // _showDateTimePicker(context);
                      print("Date-time picker clicked!");
                    },
                    icon: const Icon(
                      Icons.calendar_today_rounded,
                      size: 24,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Sorting Buttons
              Row(
                children: [
                  IntrinsicWidth(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          activeFilter = 'pdf'; // Set filter to PDF
                        });
                        fetchFiles(); // Refresh the list
                        print("Reports button clicked!");
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: activeFilter == 'pdf'
                              ? Colors.blue
                              : Colors.grey.shade400,
                        ),
                        backgroundColor: activeFilter == 'pdf'
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.transparent,
                      ),
                      child: Text(
                        'Reports',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: activeFilter == 'pdf'
                              ? Colors.blue
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IntrinsicWidth(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          activeFilter = 'csv'; // Set filter to CSV
                        });
                        fetchFiles(); // Refresh the list
                        print("CSV button clicked!");
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: activeFilter == 'csv'
                              ? Colors.blue
                              : Colors.grey.shade400,
                        ),
                        backgroundColor: activeFilter == 'csv'
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.transparent,
                      ),
                      child: Text(
                        'CSV',
                        style: TextStyle(
                          fontSize: 16,
                          color: activeFilter == 'csv'
                              ? Colors.blue
                              : Colors.black87,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: files.length,
                itemBuilder: (context, index) {
                  final file = files[index];
                  return Column(
                    children: [
                      ListTile(
                        onTap: () => _openFile(file),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 0,
                        ),
                        leading: SvgPicture.asset(
                          file.path.endsWith('.csv')
                              ? 'assets/svg/csv.svg'
                              : 'assets/svg/pdf.svg',
                          width: 40,
                          height: 40,
                        ),
                        title: Text(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          file.path.split('/').last,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Text(
                              formatDate(file
                                  .statSync()
                                  .modified), // Display last modified date
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(
                                width:
                                    8), // Add some spacing between the date and file size
                            Text(
                              formatFileSize(file
                                  .statSync()
                                  .size), // Display formatted file size
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 40,
                              child: IconButton(
                                icon: Transform.rotate(
                                  angle: pi / 2,
                                  child: const Icon(
                                    Icons.arrow_circle_right_sharp,
                                    color: Colors.blue,
                                  ),
                                ),
                                onPressed: () {
                                  _openFile(file);
                                },
                              ),
                            ),
                            SizedBox(
                              width: 30,
                              child: IconButton(
                                icon: Icon(Icons.cloud_done_rounded,
                                    color: Colors.blue),
                                onPressed: () {},
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'share') {
                                  _shareFile(file as File);
                                } else if (value == 'delete') {
                                  _deleteFile(file as File, index);
                                }
                              },
                              itemBuilder: (BuildContext context) => [
                                const PopupMenuItem(
                                  value: 'share',
                                  child: Row(
                                    children: [
                                      Icon(Icons.share, color: Colors.blue),
                                      SizedBox(width: 10),
                                      Text('Share'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete,
                                          color: Color(0xFFb91c1c)),
                                      SizedBox(width: 10),
                                      Text('Delete'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Colors.grey.shade300,
              width: 1.0,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${files.length} reports generated.',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Cloud data will be archived and deleted after 30 days.',
                style: TextStyle(
                  fontSize: 12,
                  color: const Color(0xFF848F8B),
                ),
              ),
              const SizedBox(height: 8.0),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: deleteData,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                      child: Text(
                        isDeleteConfirmed ? "Loading..." : "Start Test",
                        style: TextStyle(
                          fontSize: 20.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: TextButton(
                      onPressed: () => {
                        retrieveData(),
                        // Navigator.push(
                        //   context,
                        //   MaterialPageRoute(
                        //     builder: (context) => const RetrievingData(),
                        //   ),
                        // ),
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4694),
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                      child: Text(
                        // 'Retrieve Data',
                        isDataRetrievalComplete
                            ? "Retrieve Data"
                            : "Retrieving Data",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFile(FileSystemEntity file) async {
    if (file is File) {
      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file: ${file.path}'),
          ),
        );
      }
    }
  }

  void _uploadFileToCloud(FileSystemEntity file) async {
    try {
      final path = file.path;
      final fileName = path.split('/').last;
      Directory? directory = await getExternalStorageDirectory();
      final _file = File(path);
      final externalStoragePath = '${directory?.path}/$fileName';
      await _file.copy(externalStoragePath);
      print("File copied to internal storage. $fileName");
      final externalStorageFile = File(externalStoragePath);
      if (await externalStorageFile.exists()) {
        print("File exists in internal storage.");
        await _file.delete();
      } else {
        print("File does not exist in internal storage.");
      }

      await storage.write(key: 'csvFilePath', value: externalStoragePath);
      await storage.write(key: "deviceId", value: fileName.split('_').first);
      await storage.write(key: "pageIndex", value: "0");

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SystemDetails(device: widget.device),
          ),
        );
      }
    } catch (e) {
      print("Error uploading file to cloud: $e");
    }
  }

  // Function to share the file
  void _shareFile(File file) {
    Share.shareXFiles([XFile(file.path)],
        text: 'Check out this file: ${file.path.split('/').last}');
  }

// Function to delete the file
  void _deleteFile(File file, int index) async {
    bool confirmDelete = await _showDeleteConfirmationDialog();
    if (confirmDelete) {
      try {
        await file.delete();
        files.removeAt(index); // Remove from list
        // Trigger UI update
        (context as Element).markNeedsBuild();
      } catch (e) {
        print("Error deleting file: $e");
      }
    }
  }

// Function to show confirmation dialog before deleting
  Future<bool> _showDeleteConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete File'),
            content: const Text('Are you sure you want to delete this file?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child:
                    const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
  }
}
