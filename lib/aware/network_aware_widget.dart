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
  bool _showMessage = false;
  late final Connectivity _connectivity;
  late final Stream<ConnectivityResult> _connectivityStream;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    _connectivity = Connectivity();
    _connectivityStream = _connectivity.onConnectivityChanged;
    _checkInitialState();
    _connectivityStream.listen((ConnectivityResult result) {
      setState(() {
        _isOffline = result == ConnectivityResult.none;
      });
      if (!_isOffline) {
        _checkInternetSpeed();
      }
      _showStatusMessage();
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkInitialState() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    setState(() {
      _isOffline = connectivityResult == ConnectivityResult.none;
    });
    if (!_isOffline) {
      await _checkInternetSpeed();
    }
    _showStatusMessage();
  }

  Future<void> _checkInternetSpeed() async {
    try {
      final stopwatch = Stopwatch()..start();
      final response = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      stopwatch.stop();
      final latency = stopwatch.elapsed;
      setState(() {
        _isSlow = latency > const Duration(seconds: 1);
      });
    } catch (e) {
      setState(() {
        _isSlow = true;
      });
    }
  }

  void _showStatusMessage() {
    setState(() {
      _showMessage = true;
    });

    _messageTimer?.cancel();
    _messageTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showMessage = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showMessage && (_isOffline || _isSlow))
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isOffline
                    ? _buildStatusBanner(
                        message: 'No Internet Connection',
                        color: Colors.red.withOpacity(0.9),
                        icon: Icons.wifi_off,
                      )
                    : _isSlow
                        ? _buildStatusBanner(
                            message: 'Slow Internet Connection',
                            color: Colors.orange.withOpacity(0.9),
                            icon: Icons.wifi_tethering_error,
                          )
                        : const SizedBox.shrink(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusBanner({
    required String message,
    required Color color,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        color: color,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
