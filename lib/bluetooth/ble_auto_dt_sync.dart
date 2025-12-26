import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';

class BleAutoDateTimeSync {
  static final Guid serviceUUID = Guid("0000FFF0-0000-1000-8000-00805F9B34FB");
  static final Guid txUUID = Guid("0000FFF2-0000-1000-8000-00805F9B34FB");
  static final Guid rxUUID = Guid("0000FFF1-0000-1000-8000-00805F9B34FB");

  bool _dtSent = false;
  StreamSubscription<List<int>>? _rxSub;

  /// Build *DT=ddMMyyyyHHmmss$ command
  String _buildDtCommand() {
    final now = DateTime.now();
    final formatted = DateFormat('ddMMyyHHmmss').format(now);
    return "*DT=$formatted\$";
  }

  /// Connect → discover → send DT → listen for ACK (if any)
  Future<void> connectAndSyncTime(BluetoothDevice device) async {
    try {
      debugPrint("🔵 BLE: Connecting to device...");
      await device.connect(
        autoConnect: false,
        timeout: const Duration(seconds: 15),
      );

      debugPrint("✅ BLE: Connected");

      final services = await device.discoverServices();
      debugPrint("🔍 BLE: Services discovered (${services.length})");

      BluetoothCharacteristic? txChar;
      BluetoothCharacteristic? rxChar;

      for (final service in services) {
        if (service.uuid == serviceUUID) {
          for (final char in service.characteristics) {
            if (char.uuid == txUUID && char.properties.write) {
              txChar = char;
            }
            if (char.uuid == rxUUID &&
                (char.properties.notify || char.properties.read)) {
              rxChar = char;
            }
          }
        }
      }

      if (txChar == null) {
        throw Exception("TX characteristic (FFF2) not found");
      }

      // Enable RX notify if available (for ACK)
      if (rxChar != null) {
        await rxChar.setNotifyValue(true);
        _listenForAck(rxChar);
      }

      await _sendDt(txChar);
    } catch (e) {
      debugPrint("❌ BLE DT Sync failed: $e");
      rethrow;
    }
  }

  /// Send DT only once per connection
  Future<void> _sendDt(BluetoothCharacteristic txChar) async {
    if (_dtSent) {
      debugPrint("⚠️ DT already sent, skipping");
      return;
    }

    final command = _buildDtCommand();

    debugPrint("📤 Sending DT command: $command");

    await txChar.write(
      command.codeUnits,
      withoutResponse: false,
    );

    _dtSent = true;

    debugPrint("✅ DT write completed (GATT_SUCCESS)");
  }

  /// Listen for device ACK (optional)
  void _listenForAck(BluetoothCharacteristic rxChar) {
    _rxSub?.cancel();

    _rxSub = rxChar.lastValueStream.listen((value) {
      final response = String.fromCharCodes(value).trim();

      if (response.isEmpty) return;

      debugPrint("📥 Device response: $response");

      // OPTIONAL: You can check for specific ACK keywords
      if (response.contains("DT") ||
          response.contains("OK") ||
          response.contains("TIME")) {
        debugPrint("🎯 DT command acknowledged by device");
      }
    });
  }

  /// Call before reconnecting
  void reset() {
    debugPrint("🔄 Resetting DT sync state");
    _dtSent = false;
    _rxSub?.cancel();
    _rxSub = null;
  }
}
