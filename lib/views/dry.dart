import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:io';

import 'package:microtek_mobile_app/views/device_details.dart';

Future<void> moveFileToCacheDry(storage) async {
  try {
    final path = await storage.read(key: 'csvFilePath');
    if (path == null) {
      print("No file path found.");
      return;
    }
    final file = File(path);
    if (await file.exists()) {
      final fileName = path.split('/').last;
      final cacheDir = Directory(
          '/storage/emulated/0/Android/data/com.example.mesha_bluetooth_data_retrieval/cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      final cachePath = '${cacheDir.path}/$fileName';
      await file.copy(cachePath);
      final cacheFile = File(cachePath);
      if (await cacheFile.exists()) {
        print("File successfully copied to cache.");
        await file.delete();
        print("Original file deleted.");
      } else {
        print("File not found in cache directory after copying.");
      }
    } else {
      print("File does not exist at path: $path");
    }
  } catch (e) {
    print("Error moving file to cache: $e");
  }
}

Future<void> navigateBasedOnPageIndex(storage, context, device) async {
  final pageIndex = await storage.read(key: 'pageIndex') ?? '0';
  switch (pageIndex) {
    case '0':
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DeviceDetailsPage(device: device),
        ),
      );
      break;
    case '1':
      Navigator.pushReplacementNamed(context, '/reports');
      break;
    case '2':
      Navigator.pushReplacementNamed(context, '/home');
      break;
    default:
      print('Invalid page index: $pageIndex');
      Navigator.pushReplacementNamed(context, '/home');
  }
}
