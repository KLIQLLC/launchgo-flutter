import 'dart:io';
import 'package:flutter/services.dart';

/// iOS PushKit (VoIP) registration control + logging.
///
/// This lets us disable PushKit when logged out so VoIP pushes stop waking/showing CallKit.
class VoipPushKitService {
  static const MethodChannel _channel = MethodChannel('com.launchgo.app/pushkit');

  static Future<void> enable() async {
    if (!Platform.isIOS) return;
    await _channel.invokeMethod('enableVoip');
  }

  static Future<void> disable() async {
    if (!Platform.isIOS) return;
    await _channel.invokeMethod('disableVoip');
  }

  static Future<String?> getVoipToken() async {
    if (!Platform.isIOS) return null;
    final token = await _channel.invokeMethod<String>('getVoipToken');
    return token;
  }
}


