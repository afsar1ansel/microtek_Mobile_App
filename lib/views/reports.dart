import 'package:flutter/material.dart';
import 'package:microtek_mobile_app/components/bottom_navbar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:microtek_mobile_app/views/system_details.dart';
import 'dart:math';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:share_plus/share_plus.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final storage = const FlutterSecureStorage();
  List<FileSystemEntity> files = [];
  String activeFilter = 'all'; // Default filter is 'all'
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
    fetchFiles(); // Fetch files from the device storage
    moveFileToCache().then((_) => fetchCatchFiles());
  }

  Future<void> fetchCatchFiles() async {
    final cacheDir = Directory(
        '/storage/emulated/0/Android/data/com.example.microtek_mobile_app/cache');
    final cacheFiles = cacheDir.listSync();

    setState(() {
      catchFiles = cacheFiles;
    });
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

  Future<void> fetchFiles() async {
    final fetchedFiles = await getFilesFromDirectory();
    setState(() {
      files = fetchedFiles.where((file) {
        if (activeFilter == 'all') {
          return true; // Show all files
        } else if (activeFilter == 'pdf') {
          return file.path.endsWith('.pdf'); // Show only PDF files
        } else if (activeFilter == 'csv') {
          return file.path.endsWith('.csv'); // Show only CSV files
        } else if (activeFilter == 'duration' && selectedDurationDays != null) {
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
    return '${date.day}/${date.month}/${date.year}'; // Customize the date format as needed
  }

  Future<void> _showDurationOptions(BuildContext context) async {
    final selectedOption = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Duration'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: durationOptions.keys.map((String key) {
              return ListTile(
                title: Text(key),
                onTap: () {
                  Navigator.pop(
                      context, key); // Return the selected duration key
                },
              );
            }).toList(),
          ),
        );
      },
    );

    if (selectedOption != null) {
      setState(() {
        selectedDuration = selectedOption;
        selectedDurationDays = durationOptions[selectedOption];
        activeFilter = 'duration'; // Set the active filter to duration
      });
      fetchFiles(); // Refresh the file list
    }
  }

  // Variables to store selected dates and times
  DateTime? fromDate;
  TimeOfDay? fromTime;
  DateTime? toDate;
  TimeOfDay? toTime;

// // Track the index of the selected button
//   int _selectedIndex = 0;

//   // Function to handle button press and update the selected index
//   void _onButtonPressed(int index, String text) {
//     setState(() {
//       _selectedIndex = index; // Update selected button
//     });
//     print("Selected button: $text");
//   }

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Reports',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
        ),
        automaticallyImplyLeading: false,
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
// Sorting Buttons (Wrapped in SingleChildScrollView)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // All Button
                    IntrinsicWidth(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            activeFilter =
                                'all'; // Set filter to show all files
                          });
                          fetchFiles(); // Refresh the list
                          print("All button clicked!");
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: activeFilter == 'all'
                                ? Colors.blue
                                : Colors.grey.shade400,
                          ),
                          backgroundColor: activeFilter == 'all'
                              ? Colors.blue.withOpacity(0.1)
                              : Colors.transparent,
                        ),
                        child: Text(
                          'All',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: activeFilter == 'all'
                                ? Colors.blue
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Reports Button (PDF)
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
                    // CSV Button
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
                    const SizedBox(width: 8),
                    // Duration Button
                    IntrinsicWidth(
                      child: OutlinedButton(
                        onPressed: () {
                          _showDurationOptions(
                              context); // Show duration options
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
                          'Duration',
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

              // List of reportsGenerated
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
                            horizontal: 0, vertical: 0),
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
                              fontSize: 16, fontWeight: FontWeight.w400),
                        ),
                        subtitle: Row(
                          children: [
                            Text(
                              formatDate(file
                                  .statSync()
                                  .modified), // Last modified date
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w400),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatFileSize(file.statSync().size), // File size
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w400),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Transform.rotate(
                                angle: pi / 2,
                                child: const Icon(
                                    Icons.arrow_circle_right_sharp,
                                    color: Colors.blue),
                              ),
                              onPressed: () => _openFile(file),
                            ),
                            IconButton(
                              icon: const Icon(Icons.cloud_done_rounded,
                                  color: Colors.green),
                              onPressed: () {},
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
            BottomNavBar(currentIndex: 1),
          ],
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
      await storage.write(key: "pageIndex", value: "1");

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
