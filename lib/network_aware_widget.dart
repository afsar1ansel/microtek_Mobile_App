import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

class NetworkAwareWidget extends StatefulWidget {
  final Widget child;

  const NetworkAwareWidget({super.key, required this.child});

  @override
  State<NetworkAwareWidget> createState() => _NetworkAwareWidgetState();
}

class _NetworkAwareWidgetState extends State<NetworkAwareWidget> {
  bool _isOffline = false;
  bool _isSlow = false;
  late final Connectivity _connectivity;
  late final Stream<ConnectivityResult> _connectivityStream;

  @override
  void initState() {
    super.initState();
    _connectivity = Connectivity();
    _connectivityStream = _connectivity.onConnectivityChanged;
    // Initial check
    _checkInitialState();
    // Listen for changes
    _connectivityStream.listen((ConnectivityResult result) {
      setState(() {
        _isOffline = result == ConnectivityResult.none;
      });
      if (!_isOffline) {
        _checkInternetSpeed();
      }
    });
  }

  Future<void> _checkInitialState() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    setState(() {
      _isOffline = connectivityResult == ConnectivityResult.none;
    });
    if (!_isOffline) {
      await _checkInternetSpeed();
    }
  }

  // Function to check internet latency
  // Function to check internet latency
  Future<void> _checkInternetSpeed() async {
    try {
      final stopwatch = Stopwatch()..start();
      final response = await http
          .get(Uri.parse('[https://www.google.com](https://www.google.com)'));
      stopwatch.stop();
      final latency = stopwatch.elapsed;
      if (latency > Duration(seconds: 1)) {
        setState(() {
          _isSlow = true; // Slow connection
        });
      } else {
        setState(() {
          _isSlow = false; // Fast connection
        });
      }
    } catch (e) {
      // Handle the exception
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isOffline)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.red,
              padding: const EdgeInsets.all(8),
              child: const Text(
                'No Internet Connection',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        if (_isSlow)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.orange,
              padding: const EdgeInsets.all(8),
              child: const Text(
                'Slow Internet Connection',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}
