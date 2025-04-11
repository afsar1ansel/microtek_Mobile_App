import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  int _currentFrame = 0;
  late Timer _animationTimer;
  final int _totalFrames = 6;
  final int _frameDuration = 450;

  // Animation controllers
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late AnimationController _fadeController;


  @override
  void initState() {
    super.initState();
    // _printAllSecureStorageData(); // 👈 Print everything

    // Animation for scaling the first two frames
    _scaleController = AnimationController(
      duration: Duration(milliseconds: _frameDuration * 2),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeInOut,
      ),
    );

    // Animation for fading between all frames
    _fadeController = AnimationController(
      duration: Duration(milliseconds: _frameDuration),
      vsync: this,
    );

    _startAnimation();
  }

  void _startAnimation() {
    // Start both animations
    _scaleController.forward();
    _fadeController.forward();

    // Timer to control frame changes
    _animationTimer = Timer.periodic(
      Duration(milliseconds: _frameDuration),
      (timer) {
        if (_currentFrame < _totalFrames - 1) {
          setState(() {
            _currentFrame++;
            // Only reset fade controller after first two frames
            if (_currentFrame >= 2) {
              _fadeController.reset();
              _fadeController.forward();
            }
          });
        } else {
          timer.cancel();
          _verifyAuthToken();
        }
      },
    );
  }

  Future<void> _printAllSecureStorageData() async {
    final allData = await storage.readAll();
    debugPrint('📦 All stored secure data:');
    allData.forEach((key, value) {
      debugPrint('$key: $value');
    });
  }

  Future<void> _verifyAuthToken() async {
    try {
      final token = await storage.read(key: 'userToken');
      debugPrint('Token: $token');

      if (token != null) {
        final response = await http.post(
          Uri.parse('https://met.microtek.in/app-users/validate-token'),
          body: {'token': token},
        );

        debugPrint('Response: ${response.body}');

        final responseBody = json.decode(response.body);
        if (response.statusCode == 200 && responseBody['errFlag'] == 0) {
          _navigateTo('/home');
        } else {
          _navigateTo('/login');
        }
      } else {
        debugPrint('No token found');
        _navigateTo('/login');
      }
    } catch (e) {
      debugPrint('Error: $e');
      _navigateTo('/login');
    }
  }

  void _navigateTo(String route) {
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  void dispose() {
    _animationTimer.cancel();
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _currentFrame <= 1 ? Colors.black : Colors.transparent,
      body: AnimatedSwitcher(
        duration: Duration(milliseconds: _frameDuration),
        transitionBuilder: (Widget child, Animation<double> animation) {
          // Special transition for first two frames
          if (_currentFrame <= 1) {
            return ScaleTransition(
              scale: _scaleAnimation,
              child: FadeTransition(
                opacity: _fadeController,
                child: child,
              ),
            );
          }
          // Standard fade transition for remaining frames
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: Container(
          key: ValueKey<int>(_currentFrame),
          decoration: _currentFrame <= 1
              ? null
              : const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1D4694),
                      Color(0x4D1E562D),
                    ],
                    stops: [0.4, 0.98],
                  ),
                ),
          child: _currentFrame <= 1
              ? Center(
                  child: Image.asset(
                    'assets/animations/splash_$_currentFrame.png',
                    width: MediaQuery.of(context).size.width * 0.5,
                    fit: BoxFit.contain,
                  ),
                )
              : Image.asset(
                  'assets/animations/splash_$_currentFrame.png',
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),
        ),
      ),
    );
  }
}
