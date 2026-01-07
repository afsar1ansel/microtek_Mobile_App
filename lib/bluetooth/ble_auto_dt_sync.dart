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
  BluetoothCharacteristic?
      _rxChar; // keep a reference so we can disable notifications later

  /// Build *DT=ddMMyyyyHHmmss$ command
  String _buildDtCommand() {
    final now = DateTime.now();
    final formatted = DateFormat('ddMMyyHHmmss').format(now);
    return "*DT=$formatted\$";
  }

  /// Connect → discover → send DT → listen for ACK (if any)
  ///
  /// stopAfterWrite: when true (default), stop listening and disable RX
  /// notifications immediately after a successful write. When false,
  /// keep the notification subscription active to wait for an ACK from the
  /// device.
  Future<void> connectAndSyncTime(BluetoothDevice device,
      {bool stopAfterWrite = true}) async {
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
        _rxChar = rxChar; // keep reference for stopping later
        await rxChar.setNotifyValue(true);
        // Only attach the ACK listener if we plan to wait for an ACK.
        if (!stopAfterWrite) {
          _listenForAck(rxChar);
        }
      }

      await _sendDt(txChar);

      // If requested, stop listening immediately after a successful write
      if (stopAfterWrite) {
        debugPrint(
            "🛑 stopAfterWrite=true — stopping RX listener immediately after DT write");
        await stopListening();
      }
    } catch (e) {
      debugPrint("❌ BLE DT Sync failed: $e");
      rethrow;
    }
  }

  /// Send DT only once per connection
  /// Send DT and optionally return right away. Use `stopListening()` to
  /// stop notifications/subscription when you no longer want to listen for ACK.
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
  void _listenForAck(BluetoothCharacteristic rxChar,
      {bool stopAfterAck = true}) {
    // Cancel any previous subscription first
    _rxSub?.cancel();

    _rxSub = rxChar.lastValueStream.listen((value) async {
      final response = String.fromCharCodes(value).trim();

      if (response.isEmpty) return;

      debugPrint("📥 Device response: $response");

      // OPTIONAL: You can check for specific ACK keywords
      if (response.contains("DT") ||
          response.contains("OK") ||
          response.contains("TIME")) {
        debugPrint("🎯 DT command acknowledged by device");

        // If requested, stop listening after the ACK. We perform a fast-path
        // cancellation of the subscription first so no additional events are
        // delivered, then disable notifications on the characteristic.
        if (stopAfterAck) {
          // Cancel subscription immediately (fast path)
          final sub = _rxSub;
          _rxSub = null;
          try {
            await sub?.cancel();
            debugPrint("🔕 Subscription cancelled immediately after ACK");
          } catch (e) {
            debugPrint("Error cancelling subscription immediately: $e");
          }

          // Disable notifications on the RX characteristic (async)
          try {
            if (_rxChar != null) {
              await _rxChar!.setNotifyValue(false);
              debugPrint("🔕 Notifications disabled on RX characteristic");
              _rxChar = null;
            }
          } catch (e) {
            debugPrint("Error disabling notifications after ACK: $e");
          }
        }
      }
    });
  }

  /// Stop listening to RX notifications and cancel the subscription.
  /// Safe to call multiple times.
  Future<void> stopListening() async {
    debugPrint("🛑 Stopping DT ACK listener");
    try {
      if (_rxChar != null) {
        await _rxChar!.setNotifyValue(false);
        _rxChar = null;
      }
    } catch (e) {
      debugPrint("Error disabling notifications: $e");
    }

    try {
      await _rxSub?.cancel();
    } catch (e) {
      debugPrint("Error cancelling subscription: $e");
    }
    _rxSub = null;
  }

  /// Call before reconnecting
  void reset() {
    debugPrint("🔄 Resetting DT sync state");
    _dtSent = false;
    _rxSub?.cancel();
    _rxSub = null;
    _rxChar = null;
  }
}
