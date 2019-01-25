import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PersistanceHandler {
  static final PersistanceHandler _instance = PersistanceHandler._internal();
  SharedPreferences _persistanceService;

  PersistanceHandler._internal();

  factory PersistanceHandler() {
    return _instance;
  }

  static PersistanceHandler getHandler() {
    return _instance;
  }

  Future<SharedPreferences> init() async {
    if (_persistanceService == null) {
      _persistanceService = await SharedPreferences.getInstance();
    }
    return _persistanceService;
  }

  void clear() {
    debugPrint('[clean start] persistanceService.getKeys(): ${_persistanceService.getKeys()}');
    _persistanceService.clear();
    debugPrint('[clean completed] persistanceService.getKeys(): ${_persistanceService.getKeys()}');
  }

  Future<bool> setString(String key, String value) => _persistanceService.setString(key, value);

  String getString(String key) => _persistanceService.getString(key);

  Future<bool> setInt(String key, int value) => _persistanceService.setInt(key, value);

  int getInt(String key) => _persistanceService.getInt(key);

  Future<bool> setBool(String key, bool value) => _persistanceService.setBool(key, value);

  bool getBool(String key) => _persistanceService.getBool(key);

  Future<bool> setDouble(String key, double value) => _persistanceService.setDouble(key, value);

  double getDouble(String key) => _persistanceService.getDouble(key);

  Future<bool> setStringList(String key, List<String> value) => _persistanceService.setStringList(key, value);

  List<String> getStringList(String key) => _persistanceService.getStringList(key);

  get(String key) => _persistanceService.get(key);

  Future<bool> remove(String key) => _persistanceService.remove(key);

  Future<bool> setForDevice(String deviceID, String key, String value) {
    final String encodedDevice = _persistanceService.getString(deviceID);
    Map device;

    if (encodedDevice == null) {
      device = Map();
    } else {
      device = jsonDecode(encodedDevice);
    }

    if (device[key] != value) {
      // debugPrint('Setting \'$key\': \'$value\' for device \'$deviceID\'');
      device[key] = value;
    }

    return _persistanceService.setString(deviceID, jsonEncode(device));
  }

  String getFromDevice(String deviceID, String key) {
    // debugPrint('Getting \'$key\' from device \'$deviceID\': ${jsonDecode(_persistanceService.getString(deviceID))[key]}');
    return jsonDecode(_persistanceService.getString(deviceID))[key];
  }

  getDevice(String deviceID) {
    // debugPrint('Getting device \'$deviceID\': ${_persistanceService.getString(deviceID).toString()}');
    return jsonDecode(_persistanceService.getString(deviceID));
  }

  Set<String> getKeys() {
    return _persistanceService.getKeys();
  }
}
