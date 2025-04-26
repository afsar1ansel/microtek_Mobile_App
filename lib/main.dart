import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:microtek_mobile_app/views/change_password.dart';
import 'package:microtek_mobile_app/views/home_bluetooth.dart';
import 'package:microtek_mobile_app/views/login.dart';
import 'package:microtek_mobile_app/views/my_profile.dart';
import 'package:microtek_mobile_app/views/profile.dart';
import 'package:microtek_mobile_app/views/reports.dart';
import 'package:microtek_mobile_app/views/splash_screen.dart';
import 'package:microtek_mobile_app/views/system_details.dart';
import 'package:microtek_mobile_app/aware/network_aware_widget.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Microtek',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFF1D4694),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('es'), // Spanish
        Locale('fr'), // French
        Locale('zh'), // Chinese
        Locale('hi'), // Hindi
      ],
      home: NetworkAwareWidget(
        child: const SplashScreen(),
      ),
     routes: {
        '/login': (context) => NetworkAwareWidget(child: const LogIn()),
        '/home': (context) =>
            NetworkAwareWidget(child: const BluetoothDeviceManager()),
        '/reports': (context) =>
            NetworkAwareWidget(child: const ReportsScreen()),
        '/profile': (context) =>
            NetworkAwareWidget(child: const ProfileScreen()),
        '/my_profile': (context) => NetworkAwareWidget(child: MyProfile()),
        // '/change_password': (context) => NetworkAwareWidget(child: const ChangePasswordPage()),
        // '/system_details': (context) => NetworkAwareWidget(child: const SystemDetails()),
      },
    );
  }
}

// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});

//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> {
//   bool _isScanning = false;
//   final List<ScanResult> _devices = [];
//   BluetoothDevice? _connectedDevice;
//   BluetoothCharacteristic? _targetCharacteristic;
//   String? _retrievedData; // Store retrieved data

//   // Request permissions and ensure Bluetooth is enabled
//   Future<bool> _requestPermissions() async {
//     if (await Permission.bluetoothScan.request().isGranted &&
//         await Permission.bluetoothConnect.request().isGranted &&
//         await Permission.location.request().isGranted) {
//       // Check if Bluetooth is supported
//       if (await FlutterBluePlus.isSupported == false) {
//         print('Bluetooth not supported on this device');
//         return false;
//       }

//       // Check if Bluetooth is ON
//       if (await FlutterBluePlus.adapterState.first !=
//           BluetoothAdapterState.on) {
//         print('Bluetooth is off, please turn it on');
//         await FlutterBluePlus.turnOn(); // Prompt user to enable Bluetooth
//         return false;
//       }

//       return true;
//     } else {
//       print('Permissions not granted');
//       return false;
//     }
//   }

//   // Start scanning for devices
//   Future<void> _startScan() async {
//     bool hasPermission = await _requestPermissions();
//     if (!hasPermission) return;

//     setState(() {
//       _isScanning = true;
//       _devices.clear();
//     });

//     FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

//     FlutterBluePlus.scanResults.listen((results) {
//       // print(
//       //     '++++++++++++++++++++++++++++++++++++++results+++++++++++++++++++++++++++++++++++++++++++++');
//       // print(results);
//       // print(
//       //     '++++++++++++++++++++++++++++++++++++++results+++++++++++++++++++++++++++++++++++++++++++++');
//       setState(() {
//         _devices.clear();
//         _devices.addAll(results);
//         _isScanning = false;
//       });
//     }, onError: (e) {
//       print('Scan error: $e');
//     });
//   }

//   void _stopScan() {
//     FlutterBluePlus.stopScan();
//     setState(() => _isScanning = false);
//   }

//   // Connect to a selected device
//   Future<void> _connectToDevice(BluetoothDevice device) async {
//     try {
//       await device.connect();
//       setState(() {
//         _connectedDevice = device;
//         print(
//             '++++++++++++++++++++++++++++++++++++++_connectedDevice+++++++++++++++++++++++++++++++++++++++++++++');
//         print(_connectedDevice);
//         print(
//             '++++++++++++++++++++++++++++++++++++++_connectedDevice+++++++++++++++++++++++++++++++++++++++++++++');
//       });

//       print('Connected to ${device.remoteId}');

//       // Discover services and start fetching data
//       await _discoverServices();
//     } catch (e) {
//       print('Failed to connect: $e');
//     }
//   }

//   // Disconnect from the device
//   Future<void> _disconnectDevice() async {
//     if (_connectedDevice != null) {
//       await _connectedDevice!.disconnect();
//       setState(() {
//         _connectedDevice = null;
//         _targetCharacteristic = null;
//       });
//       print('Disconnected');
//     }
//   }

//   // Discover available services & characteristics
//   Future<void> _discoverServices() async {
//     if (_connectedDevice == null) return;

//     List<BluetoothService> services =
//         await _connectedDevice!.discoverServices();
//     for (BluetoothService service in services) {
//       print(
//           '++++++++++++++++++++++++++++++++++++++service+++++++++++++++++++++++++++++++++++++++++++++');
//       print(service);
//       print(
//           '++++++++++++++++++++++++++++++++++++++service+++++++++++++++++++++++++++++++++++++++++++++');
//       for (BluetoothCharacteristic characteristic in service.characteristics) {
//         print(
//             'Service: ${service.uuid}, Characteristic: ${characteristic.uuid}');

//         // Check if characteristic supports reading
//         if (characteristic.properties.read) {
//           _targetCharacteristic = characteristic;
//           // print(
//           //     '++++++++++++++++++++++++++++++++++++++_targetCharacteristic+++++++++++++++++++++++++++++++++++++++++++++');
//           // print(_targetCharacteristic);
//           // print(
//           //     '++++++++++++++++++++++++++++++++++++++_targetCharacteristic+++++++++++++++++++++++++++++++++++++++++++++');
//           _readCharacteristic(characteristic);
//         }

//         // Check if characteristic supports notifications (live updates)
//         if (characteristic.properties.notify) {
//           _subscribeToCharacteristic(characteristic);
//         }
//       }
//     }
//   }

//   // Read data from a characteristic
//   Future<void> _readCharacteristic(
//       BluetoothCharacteristic characteristic) async {
//     print(
//         '++++++++++++++++++++++++++++++++++++++Characteristic+++++++++++++++++++++++++++++++++++++++++++++');
//     print(characteristic);
//     print(
//         '++++++++++++++++++++++++++++++++++++++Characteristic+++++++++++++++++++++++++++++++++++++++++++++');
//     try {
//       List<int> value = await characteristic.read();
//       String data = utf8.decode(value);
//       setState(() {
//         _retrievedData = data; // Update UI with retrieved data
//       });
//       print('Data Read: $data');
//     } catch (e) {
//       print('Error reading characteristic: $e');
//     }
//   }

//   // Subscribe for live data updates
//   Future<void> _subscribeToCharacteristic(
//       BluetoothCharacteristic characteristic) async {
//     characteristic.lastValueStream.listen((value) {
//       String data = String.fromCharCodes(value);
//       setState(() {
//         _retrievedData = data; // Update UI with live data
//       });
//       print('Live Data: $data');
//     });

//     await characteristic.setNotifyValue(true);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Bluetooth Devices')),
//       body: Column(
//         children: [
//           ElevatedButton(
//             onPressed: _isScanning ? _stopScan : _startScan,
//             child: Text(_isScanning ? 'Stop Scan' : 'Start Scan'),
//           ),
//           Expanded(
//             child: ListView.builder(
//               itemCount: _devices.length,
//               itemBuilder: (context, index) {
//                 final device = _devices[index].device;
//                 return ListTile(
//                   title: Text(device.remoteId.toString()),
//                   subtitle: Text(_devices[index].advertisementData.advName ??
//                       'Unknown Device'),
//                   trailing: ElevatedButton(
//                     onPressed: () => _connectToDevice(device),
//                     child: const Text('Connect'),
//                   ),
//                 );
//               },
//             ),
//           ),
//           if (_connectedDevice != null)
//             Column(
//               children: [
//                 Text('Connected to: ${_connectedDevice!.remoteId}'),
//                 ElevatedButton(
//                   onPressed: _disconnectDevice,
//                   child: const Text('Disconnect'),
//                 ),
//                 if (_retrievedData != null) // Show retrieved data
//                   Padding(
//                     padding: const EdgeInsets.all(8.0),
//                     child: Text('Received Data: $_retrievedData',
//                         style: TextStyle(
//                             fontSize: 18, fontWeight: FontWeight.bold)),
//                   ),
//               ],
//             ),
//         ],
//       ),
//     );
//   }
// }

// class BluetoothTerminalApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Bluetooth Terminal',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//       ),
//       home: BluetoothDeviceListScreen(),
//     );
//   }
// }

// class BluetoothDeviceListScreen extends StatefulWidget {
//   @override
//   _BluetoothDeviceListScreenState createState() =>
//       _BluetoothDeviceListScreenState();
// }

// class _BluetoothDeviceListScreenState extends State<BluetoothDeviceListScreen> {
//   List<BluetoothDevice> pairedDevices = [];
//   List<BluetoothDevice> scannedDevices = [];
//   bool isScanning = false;
//   bool isBluetoothOn = true;
//   BluetoothDevice? connectedDevice;

//   @override
//   void initState() {
//     super.initState();
//     checkBluetoothStatus();
//     getPairedDevices();
//   }

//   /// Check if Bluetooth is enabled
//   void checkBluetoothStatus() async {
//     bool enabled = await FlutterBluePlus.isSupported;
//     setState(() {
//       isBluetoothOn = enabled;
//     });
//   }

//   /// Turn on Bluetooth
//   void turnOnBluetooth() async {
//     await FlutterBluePlus.turnOn();
//     setState(() {
//       isBluetoothOn = true;
//     });
//   }

//   /// Fetch Paired (Bonded) Devices
//   void getPairedDevices() async {
//     List<BluetoothDevice> bondedDevices = await FlutterBluePlus.bondedDevices;
//     setState(() {
//       pairedDevices = bondedDevices;
//     });
//   }

//   /// Start Scanning for New Devices
//   void startScan() {
//     setState(() {
//       scannedDevices.clear();
//       isScanning = true;
//     });

//     FlutterBluePlus.startScan(timeout: Duration(seconds: 5));
//     FlutterBluePlus.scanResults.listen((results) {
//       setState(() {
//         scannedDevices = results
//             .map((r) => r.device)
//             .where((device) =>
//                 !pairedDevices.contains(device) && device.platformName != "")
//             .toList();
//       });
//     }).onDone(() {
//       setState(() {
//         isScanning = false;
//       });
//     });
//   }

//   /// Connect to a device and disconnect from any previously connected device
//   void connectToDevice(BluetoothDevice device) async {
//     if (connectedDevice != null) {
//       await connectedDevice!.disconnect();
//     }
//     await device.connect();
//     setState(() {
//       connectedDevice = device;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Bluetooth Devices")),
//       body: Column(
//         children: [
//           if (!isBluetoothOn) ...[
//             Padding(
//               padding: EdgeInsets.all(16.0),
//               child: Text("Bluetooth is OFF. Please enable it."),
//             ),
//             ElevatedButton(
//               onPressed: turnOnBluetooth,
//               child: Text("Turn On Bluetooth"),
//             ),
//           ],
//           if (isBluetoothOn) ...[
//             ElevatedButton(
//               onPressed: startScan,
//               child: Text(isScanning ? "Scanning..." : "Start Scan"),
//             ),
//             if (pairedDevices.isNotEmpty) ...[
//               Padding(
//                 padding: EdgeInsets.all(8.0),
//                 child: Text("Paired Devices",
//                     style:
//                         TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//               ),
//               Expanded(
//                 child: ListView.builder(
//                   itemCount: pairedDevices.length,
//                   itemBuilder: (context, index) {
//                     return DeviceCard(
//                       device: pairedDevices[index],
//                       onConnect: () => connectToDevice(pairedDevices[index]),
//                       onInfo: () =>
//                           navigateToTerminalScreen(pairedDevices[index]),
//                     );
//                   },
//                 ),
//               ),
//             ],
//             if (scannedDevices.isNotEmpty) ...[
//               Padding(
//                 padding: EdgeInsets.all(8.0),
//                 child: Text("Available Devices",
//                     style:
//                         TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//               ),
//               Expanded(
//                 child: ListView.builder(
//                   itemCount: scannedDevices.length,
//                   itemBuilder: (context, index) {
//                     return DeviceCard(
//                       device: scannedDevices[index],
//                       onConnect: () => connectToDevice(scannedDevices[index]),
//                       onInfo: () =>
//                           navigateToTerminalScreen(scannedDevices[index]),
//                     );
//                   },
//                 ),
//               ),
//             ],
//           ],
//         ],
//       ),
//     );
//   }

//   void navigateToTerminalScreen(BluetoothDevice device) {
//     if (connectedDevice != null &&
//         connectedDevice!.remoteId == device.remoteId) {
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (context) => BluetoothTerminalScreen(device: device),
//         ),
//       );
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Please connect to the device first.")),
//       );
//     }
//   }
// }

// class DeviceCard extends StatelessWidget {
//   final BluetoothDevice device;
//   final VoidCallback onConnect;
//   final VoidCallback onInfo;

//   DeviceCard(
//       {required this.device, required this.onConnect, required this.onInfo});

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
//       child: ListTile(
//         title: Text(device.platformName ?? "Unknown"),
//         subtitle: Text(device.remoteId.toString()),
//         trailing: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             IconButton(
//               icon: Icon(Icons.info),
//               onPressed: onInfo,
//             ),
//             IconButton(
//               icon: Icon(Icons.bluetooth),
//               onPressed: onConnect,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class BluetoothTerminalScreen extends StatefulWidget {
//   final BluetoothDevice device;

//   BluetoothTerminalScreen({required this.device});

//   @override
//   _BluetoothTerminalScreenState createState() =>
//       _BluetoothTerminalScreenState();
// }

// class _BluetoothTerminalScreenState extends State<BluetoothTerminalScreen> {
//   BluetoothCharacteristic? txCharacteristic;
//   BluetoothCharacteristic? rxCharacteristic;
//   List<String> messages = [];
//   String? _retrievedData = "";
//   final TextEditingController messageController = TextEditingController();
//   bool isDeleteConfirmed = false;

//   @override
//   void initState() {
//     super.initState();
//     connectToDevice(widget.device);
//   }

//   /// Connect to a Selected Device
//   void connectToDevice(BluetoothDevice device) async {
//     await device.connect();
//     discoverServices();
//   }

//   /// Discover Bluetooth Services
//   void discoverServices() async {
//     List<BluetoothService> services = await widget.device.discoverServices();
//     for (var service in services) {
//       for (var char in service.characteristics) {
//         if (char.properties.write) {
//           txCharacteristic = char;
//         }
//         if (char.properties.notify || char.properties.read) {
//           rxCharacteristic = char;
//           rxCharacteristic!.setNotifyValue(true);
//           rxCharacteristic!.lastValueStream.listen((value) {
//             String receivedData = String.fromCharCodes(value);
//             setState(() {
//               messages.add("Received: $receivedData");
//               _retrievedData = _retrievedData! + receivedData;
//             });
//           });
//         }
//       }
//     }
//   }

//   void convertAndSaveCSV() async {
//     List<String> rows = _retrievedData!.split('\n');
//     List<String> headers = 'id,date,time,value1,value2'.split(',');

//     List<Map<String, dynamic>> allData = [];

//     for (int i = 1; i < rows.length - 2; i++) {
//       List<String> row = rows[i].split(',');
//       Map<String, dynamic> data = {};

//       for (int j = 0; j < headers.length; j++) {
//         data[headers[j]] = row[j];
//       }
//       allData.add(data);
//     }

//     List<List<String>> csvData = [
//       headers,
//       ...allData.map(
//         (map) =>
//             headers.map((header) => (map[header] ?? "").toString()).toList(),
//       )
//     ];

//     String csvString = const ListToCsvConverter().convert(csvData);

//     final directory = await getExternalStorageDirectory();
//     final path = "${directory?.path}/output_data.csv";

//     final file = File(path);
//     await file.writeAsString(csvString);

//     print("CSV file saved at: $path");
//   }

//   /// Send Data to Bluetooth Device
//   void sendData(String data) async {
//     if (txCharacteristic != null) {
//       await txCharacteristic!.write(data.codeUnits);
//     }
//   }

//   /// Send *GET$ Command to Retrieve Data
//   void retrieveData() {
//     _retrievedData = "";
//     sendData("*GET\$");
//   }

//   /// Send *DELETE$ Command
//   void deleteData() {
//     if (!isDeleteConfirmed) {
//       sendData("*DELETE\$");
//       setState(() {
//         isDeleteConfirmed = true;
//       });
//     } else {
//       sendData("*DELETE\$");
//       setState(() {
//         isDeleteConfirmed = false;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Bluetooth Terminal")),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             Expanded(
//               child: SingleChildScrollView(
//                 child: Column(
//                   children: [
//                     Text(
//                       "Connected to: ${widget.device.platformName ?? "Unknown"}",
//                       style:
//                           TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                     ),
//                     SizedBox(height: 16),
//                     Text(
//                       "Received Data:",
//                       style:
//                           TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                     ),
//                     SizedBox(height: 8),
//                     Text(_retrievedData ?? ""),
//                   ],
//                 ),
//               ),
//             ),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 ElevatedButton(
//                   onPressed: retrieveData,
//                   child: Text("Retrieve Data"),
//                 ),
//                 ElevatedButton(
//                   onPressed: convertAndSaveCSV,
//                   child: Text('Save as CSV'),
//                 ),
//                 ElevatedButton(
//                   onPressed: deleteData,
//                   child: Text(
//                       isDeleteConfirmed ? "Confirm Delete" : "Delete Data"),
//                 ),
//               ],
//             ),
//             Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: TextField(
//                       controller: messageController,
//                       decoration: InputDecoration(labelText: "Enter message"),
//                     ),
//                   ),
//                   IconButton(
//                     icon: Icon(Icons.send),
//                     onPressed: () {
//                       sendData(messageController.text);
//                       messageController.clear();
//                     },
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
