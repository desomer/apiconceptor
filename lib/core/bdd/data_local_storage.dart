import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

//import '../../config/logging/logging.dart';

/// Base class containing a unified API for key-value pairs' storage.
/// This class provides low level methods for storing:
/// - Sensitive keys using [FlutterSecureStorage]
/// - Insensitive keys using [SharedPreferences]
class KeyValueStorageBase {
  /// Instance of shared preferences
  static SharedPreferences? _sharedPrefs;

  /// Instance of flutter secure storage
  static FlutterSecureStorage? _secureStorage;

  /// Singleton instance of KeyValueStorage Helper
  static const instance = KeyValueStorageBase._();

  /// Private constructor
  const KeyValueStorageBase._();

  /// Initializer for shared prefs and flutter secure storage
  /// Should be called in main before runApp and
  /// after WidgetsBinding.FlutterInitialized(), to allow for synchronous tasks
  /// when possible.
  static Future<void> init() async {
    _sharedPrefs ??= await SharedPreferences.getInstance();
    const windowOptions = WindowsOptions(
      //encryptedSharedPreferences: true,
    );
    _secureStorage ??= const FlutterSecureStorage(wOptions: windowOptions);
  }

  /// Reads the value for the key from common preferences storage
  T? getCommon<T>(String key) {
    try {
      return switch (T) {
        const (String) => _sharedPrefs!.getString(key) as T?,
        const (List<String>) => _sharedPrefs!.getStringList(key) as T?,
        const (int) => _sharedPrefs!.getInt(key) as T?,
        const (bool) => _sharedPrefs!.getBool(key) as T?,
        const (double) => _sharedPrefs!.getDouble(key) as T?,
        _ => _sharedPrefs!.get(key) as T?
      };
    } on PlatformException catch (ex) {
      appLogger.debug('$ex');
      return null;
    }
  }

  /// Reads the decrypted value for the key from secure storage
  Future<String?> getEncrypted(String key) {
    try {
      return _secureStorage!.read(key: key);
    } on PlatformException catch (ex) {
      appLogger.debug('$ex');
      return Future<String?>.value();
    }
  }

  /// Sets the value for the key to common preferences storage
  Future<bool> setCommon<T>(String key, T value) {
    return switch (T) {
      const (String) => _sharedPrefs!.setString(key, value as String),
      const (List<String>) =>
        _sharedPrefs!.setStringList(key, value as List<String>),
      const (int) => _sharedPrefs!.setInt(key, value as int),
      const (bool) => _sharedPrefs!.setBool(key, value as bool),
      const (double) => _sharedPrefs!.setDouble(key, value as double),
      _ => _sharedPrefs!.setString(key, value as String)
    };
  }

  /// Sets the encrypted value for the key to secure storage
  Future<bool> setEncrypted(String key, String value) {
    try {
      _secureStorage!.write(key: key, value: value);
      return Future.value(true);
    } on PlatformException catch (ex) {
      appLogger.debug('$ex');
      return Future.value(false);
    }
  }

  Future<bool> removeCommon(String key) => _sharedPrefs!.remove(key);

  Future<void> removeEncrypted(String key) => _secureStorage!.delete(key: key);

  /// Erases common preferences keys
  Future<bool> clearCommon() => _sharedPrefs!.clear();

  /// Erases encrypted keys
  Future<bool> clearEncrypted() async {
    try {
      await _secureStorage!.deleteAll();
      return true;
    } on PlatformException catch (ex) {
      appLogger.debug('$ex');
      return false;
    }
  }
}

final appLogger = AppLogger();

class AppLogger 
{
   void debug(dynamic msg)
   {
      print('$msg');
   }
}