import 'dart:math'; // Import the math library for pi
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:microtek_mobile_app/components/bottom_navbar.dart';
import 'package:microtek_mobile_app/views/device_details.dart';

import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:microtek_mobile_app/views/system_details.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';

class BluetoothDeviceManager extends StatefulWidget {
  const BluetoothDeviceManager({super.key});

  @override
  State<BluetoothDeviceManager> createState() => _BluetoothDeviceManagerState();
}

class _BluetoothDeviceManagerState extends State<BluetoothDeviceManager> {
  String _userName = 'User';
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  Future<void> _loadUserName() async {
    String? storedUserName = await _secureStorage.read(key: 'username');
    if (storedUserName != null) {
      setState(() {
        _userName = storedUserName;
      });
    }
  }

  List<BluetoothDevice> _pairedDevices = [];
  List<BluetoothDevice> _scannedDevices = [];

  List<FileSystemEntity> files = [];
  String activeFilter = 'pending'; // Default filter is 'all'
  final Map<String, int> durationOptions = {
    'Last 7 days': 7,
    'Last 14 days': 14,
    'Last 30 days': 30,
  };
  String?
      selectedDuration; // Stores the selected duration key (e.g., "Last 7 days")
  int?
      selectedDurationDays; // Stores the selected duration value in days (e.g., 7)
  List<FileSystemEntity> catchFiles = [];

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _checkBluetoothStatus();
    moveFileToCache().then((_) => fetchCatchFiles()).then((_) => {
          if (catchFiles.isNotEmpty)
            {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showAlertDialog();
              })
            }
        });
  }

  Future<void> fetchCatchFiles() async {
    final cacheDir = Directory(
        '/storage/emulated/0/Android/data/com.example.microtek_mobile_app/cache');
    final cacheFiles = cacheDir.listSync();

    setState(() {
      files = cacheFiles;
      catchFiles = cacheFiles;
    });
  }

  Future<void> moveFileToCache() async {
    try {
      final path = await _secureStorage.read(key: 'csvFilePath');

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

  Future<void> fetchFiles() async {
    final fetchedFiles = await getFilesFromDirectory();
    setState(() {
      files = fetchedFiles.where((file) {
        if (activeFilter == 'duration' && selectedDurationDays != null) {
          // Filter files based on the last modified date
          final now = DateTime.now();
          final lastModified = file.statSync().modified;
          final difference = now.difference(lastModified).inDays;
          return difference <=
              selectedDurationDays!; // Show files modified within the selected duration
        }
        return false; // No other filters
      }).toList();
    });
    print(files);
  }

  Future<List<FileSystemEntity>> getFilesFromDirectory() async {
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
      // Exclude the downloads folder
      if (file is Directory && file.path == downloadsDirectory?.path) {
        return false;
      }
      return true; // Include all other files and folders
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
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}'; // Customize the date and time format as needed
  }

  // Future<void> _showDurationOptions(BuildContext context) async {
  //   final selectedOption = await showDialog<String>(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: Text('Select Duration'),
  //         content: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: durationOptions.keys.map((String key) {
  //             return ListTile(
  //               title: Text(key),
  //               onTap: () {
  //                 Navigator.pop(
  //                     context, key); // Return the selected duration key
  //               },
  //             );
  //           }).toList(),
  //         ),
  //       );
  //     },
  //   );

  //   if (selectedOption != null) {
  //     setState(() {
  //       selectedDuration = selectedOption;
  //       selectedDurationDays = durationOptions[selectedOption];
  //       activeFilter = 'duration'; // Set the active filter to duration
  //     });
  //     fetchFiles(); // Refresh the file list
  //   }
  // }

  /// Check Bluetooth Status and Request Permissions
  Future<void> _checkBluetoothStatus() async {
    bool hasPermissions = await _requestPermissions();
    if (!hasPermissions) return;

    // Ensure Bluetooth is on
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      print('Bluetooth is off. Asking user to enable it...');
      await FlutterBluePlus.turnOn();
      _waitForBluetoothOn();
    } else {
      _getBluetoothDevices();
    }
  }

  /// Wait for the user to turn Bluetooth on, then start scanning
  void _waitForBluetoothOn() {
    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        print('Bluetooth is now ON. Scanning...');
        _getBluetoothDevices();
      } else {
        print('Bluetooth is still OFF. Waiting...');
      }
    });
  }

  /// Request Permissions for Bluetooth and Location
  Future<bool> _requestPermissions() async {
    var scanPermission = await Permission.bluetoothScan.request();
    var connectPermission = await Permission.bluetoothConnect.request();
    var locationPermission = await Permission.locationWhenInUse.request();

    if (scanPermission.isGranted &&
        connectPermission.isGranted &&
        locationPermission.isGranted) {
      if (!await FlutterBluePlus.isSupported) {
        print('Bluetooth not supported on this device');
        return false;
      }
      return true;
    } else {
      print('Permissions not granted');
      return false;
    }
  }

  /// Get Paired Devices and Start Scanning for Nearby Devices
  Future<void> _getBluetoothDevices() async {
    setState(() {
      _pairedDevices.clear();
      _scannedDevices.clear();
    });

    // Get Paired Devices
    List<BluetoothDevice> bondedDevices = await FlutterBluePlus.bondedDevices;
    setState(() {
      _pairedDevices = bondedDevices;
    });

    // Start Scanning for Nearby Devices
    await _scanForDevices();
  }

  /// Scan for Nearby Devices
  Future<void> _scanForDevices() async {
    setState(() {
      _scannedDevices.clear();
    });

    FlutterBluePlus.startScan(
        timeout: Duration(seconds: 5), androidUsesFineLocation: true);

    FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          _scannedDevices = results
              .map((r) => r.device)
              .where((device) =>
                  !_pairedDevices.contains(device) &&
                  device.platformName.isNotEmpty)
              .toList();
        });
      }
    });

    await Future.delayed(Duration(seconds: 5)); // Ensure scan runs for 5 sec
    FlutterBluePlus.stopScan();

    print('Paired Devices: $_pairedDevices');
    print('Scanned Devices: $_scannedDevices');
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: Text('Scanned Devices: $_scannedDevices'),
    //     showCloseIcon: true,
    //     behavior: SnackBarBehavior.floating, // Make it float on top
    //   ),
    // );
  }

  Widget _buildDeviceList({
    required String title,
    required List<BluetoothDevice> devices,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title == "Scanned Devices"
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      _scanForDevices();
                    },
                    icon: Icon(
                      Icons.sync_sharp,
                      size: 20,
                      color: Colors.black54,
                    ),
                    label: const Text(
                      'Scan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 0, horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      backgroundColor: Colors.grey.shade300,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              )
            : Text(
                title,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
        SizedBox(height: 16),
        SizedBox(
          height: devices.length < 4 ? devices.length * 62.0 : 248,
          child: ListView.builder(
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return DeviceCard(device: device);
            },
          ),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  void _showAlertDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Center(
            child: Text(
              "Action Needed",
              style: TextStyle(fontSize: 24),
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${catchFiles.length} Pending Uploads!',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                "Review and resolve pending uploads.",
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12), // Add spacing above the divider
              const Divider(thickness: 0),
            ],
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      backgroundColor: Colors.grey.shade300,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text("Dismiss"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(this.context, '/reports');
                      // Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue,
                    ),
                    child: const Text("Action"),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  // Function to handle info icon button click

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Welcome back,",
                      style: TextStyle(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${_userName[0].toUpperCase()}${_userName.substring(1)}!",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle, // Ensure the border is circular
                  border: Border.all(
                    color: Color(0xFFDDDDDD),
                    width: 1.0, // Border width
                  ),
                ),
                child: CircleAvatar(
                  backgroundColor: Color(0xFFECF6FF),
                  child: Text(
                    _userName.substring(0, 2).toUpperCase(),
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDeviceList(
                  title: "Paired Devices", devices: _pairedDevices),
              SizedBox(height: 24),
              _buildDeviceList(
                  title: "Scanned Devices", devices: _scannedDevices),

              const SizedBox(height: 14),
              // Reports Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Reports',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  // TextButton(
                  //   onPressed: _handleReportAction,
                  //   style: TextButton.styleFrom(
                  //     backgroundColor: Colors.transparent,
                  //     padding: const EdgeInsets.all(0),
                  //   ),
                  //   child: const Text(
                  //     'View all',
                  //     style: TextStyle(
                  //       fontSize: 16,
                  //       color: Colors.black54,
                  //       fontWeight: FontWeight.w400,
                  //     ),
                  //   ),
                  // ),
                ],
              ),
              const SizedBox(height: 14),
              // Sorting Buttons
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // pending Button
                    IntrinsicWidth(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            activeFilter =
                                'pending'; // Set filter to show pending files
                          });
                          fetchCatchFiles(); // Refresh the list
                          print("pending button clicked!");
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: activeFilter == 'pending'
                                ? Colors.blue
                                : Colors.grey.shade400,
                          ),
                          backgroundColor: activeFilter == 'pending'
                              ? Colors.blue.withOpacity(0.1)
                              : Colors.transparent,
                        ),
                        child: Text(
                          'Pending',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: activeFilter == 'pending'
                                ? Colors.blue
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Reports Button (PDF)

                    const SizedBox(width: 8),
                    // Duration Button
                    IntrinsicWidth(
                      child: OutlinedButton(
                        onPressed: () {
                          // _showDurationOptions(context);
                          setState(() {
                            selectedDurationDays = 7;
                            selectedDuration = 'Last 7 days';
                            activeFilter = 'duration';
                          });
                          fetchFiles();
                          print("Duration button clicked!");
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: activeFilter == 'duration'
                                ? Colors.blue
                                : Colors.grey.shade400,
                          ),
                          backgroundColor: activeFilter == 'duration'
                              ? Colors.blue.withOpacity(0.1)
                              : Colors.transparent,
                        ),
                        child: Text(
                          'Recent',
                          style: TextStyle(
                            fontSize: 16,
                            color: activeFilter == 'duration'
                                ? Colors.blue
                                : Colors.black87,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                    if (selectedDuration !=
                        null) // Display the selected duration
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          selectedDuration!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                  ],
                ),
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
                            activeFilter == "pending"
                                ? SizedBox(
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
                                  )
                                : SizedBox(
                                    width: 40,
                                    child: IconButton(
                                      icon: Transform.rotate(
                                        angle: pi /
                                            2, // Rotate 90 degrees (pi/2 radians)
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
                            activeFilter == "pending"
                                ? SizedBox(
                                    width: 35,
                                    child: IconButton(
                                      icon: Icon(Icons.cloud_off_rounded,
                                          color: Colors.red),
                                      onPressed: () {},
                                    ),
                                  )
                                : SizedBox(
                                    width: 35,
                                    child: IconButton(
                                      icon: Icon(Icons.cloud_done_rounded,
                                          color: Colors.blue),
                                      onPressed: () {},
                                    ),
                                  ),
                            activeFilter == "pending"
                                ? SizedBox()
                                : PopupMenuButton<String>(
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
                                            Icon(Icons.share,
                                                color: Colors.blue),
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
      bottomNavigationBar: BottomNavBar(currentIndex: 0),
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

      await _secureStorage.write(
          key: 'csvFilePath', value: externalStoragePath);
      await _secureStorage.write(
          key: "deviceId", value: fileName.split('_').first);
      await _secureStorage.write(key: "pageIndex", value: "2");

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SystemDetails(),
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

class DeviceCard extends StatefulWidget {
  final BluetoothDevice? device;

  const DeviceCard({
    Key? key,
    this.device,
  }) : super(key: key);

  @override
  _DeviceCardState createState() => _DeviceCardState();
}

class _DeviceCardState extends State<DeviceCard> {
  bool _isConnected = false;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _checkIfConnected();
  }

  /// Check if the device is already connected
  Future<void> _checkIfConnected() async {
    final isConnected = await widget.device?.isConnected;
    setState(() {
      _isConnected = isConnected!;
    });
  }

  /// Connect to the device
  Future<void> _connectDevice() async {
    setState(() {
      _isConnecting = true;
    });

    try {
      await widget.device?.connect();
      setState(() {
        _isConnected = true;
        _isConnecting = false;
      });
    } catch (e) {
      print("Failed to connect: $e");
      setState(() {
        _isConnecting = false;
      });
    }
  }

  /// Disconnect from the device
  Future<void> _disconnectDevice() async {
    setState(() {
      _isConnecting = true;
    });

    try {
      await widget.device?.disconnect();
      setState(() {
        _isConnected = false;
        _isConnecting = false;
      });
    } catch (e) {
      print("Failed to disconnect: $e");
      setState(() {
        _isConnecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: SizedBox(
            width: 170,
            child: Text(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              widget.device?.platformName ?? "Unknown Device",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isConnecting)
                Padding(
                  padding: const EdgeInsets.only(right: 4.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ),
                )
              else
                Text(
                  _isConnected ? "Connected" : "Not Connected",
                  style: TextStyle(
                    fontSize: 14,
                    color: _isConnected ? Colors.blue : Colors.grey.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (_isConnected)
                IconButton(
                  icon: Icon(Icons.info_outline, color: Colors.grey.shade500),
                  onPressed: () => _showDeviceInfo(widget.device),
                ),
            ],
          ),
          onTap: _isConnected ? _disconnectDevice : _connectDevice,
        ),
        Divider(),
      ],
    );
  }

  void _showDeviceInfo(BluetoothDevice? device) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DeviceDetailsPage(device: device),
      ),
    );
    // showDialog(
    //   context: context,
    //   builder: (context) {
    //     return AlertDialog(
    //       title: Text("Device Info"),
    //       content: Text(
    //           "Device Name: ${device.platformName}\nID: ${device.remoteId}"),
    //       actions: [
    //         TextButton(
    //           onPressed: () => Navigator.pop(context),
    //           child: Text("Close"),
    //         ),
    //       ],
    //     );
    //   },
    // );
  }
}
