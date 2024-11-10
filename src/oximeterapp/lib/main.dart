// ignore_for_file: avoid_print

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';

class ResultWidget extends StatelessWidget {
  final List<String> results;
  final Function(int?) onClearTap;

  const ResultWidget({
    Key? key,
    required this.results,
    required this.onClearTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(results[index]),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => onClearTap(index),
                ),
              );
            },
          ),
        ),
        if (results.isNotEmpty)
          TextButton(
            onPressed: () => onClearTap(null),
            child: const Text('Clear All'),
          ),
      ],
    );
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Optical Pulse Oximeter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF67CCAA)),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Optical Pulse Oximeter'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _connectedDeviceName = 'Unknown';
  String _receivedValue = 'Waiting for data...';
  String _connectionStatus = 'Disconnected';

  // Replace with your actual device name, service UUID, and characteristic UUID
  String searchDeviceName = 'Optical Pulse Oximeter'; 
  String searchServiceUUID = 'adf2a6e6-9b6d-4b5f-a487-77e21aafbc88';
  String searchCharacteristicUUID = '2A37'; 

  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _initializeBLE();
    UniversalBle.onValueChange = _onCharacteristicValueChange;
    UniversalBle.onConnectionChange = _onConnectionChange;
  }

  Future<void> _initializeBLE() async {
    AvailabilityState state = await UniversalBle.getBluetoothAvailabilityState();
    if (state != AvailabilityState.poweredOn) {
      _addLog('Bluetooth is not enabled', '');
      return;
    }

    UniversalBle.onScanResult = (device) {
      print("Device found: ${device.name}"); // Log device name
      if (device.name == searchDeviceName) {
        _addLog('Device found', device.name);
        _connectToDevice(device);
        UniversalBle.stopScan();
      }
    };
    _addLog('Scanning for devices...', '');
    UniversalBle.startScan();
  }

  Future<void> _connectToDevice(BleDevice device) async {
    try {
      _addLog('Connecting to device...', device.name);
      await UniversalBle.connect(device.deviceId); 
      // _discoverServices is now called in _onConnectionChange after successful connection
    } catch (e) {
      _addLog('Error connecting to device: $e', '');
      setState(() {
        _connectionStatus = 'Error connecting'; 
      });
    }
  }

  void _onConnectionChange(String deviceId, bool isConnected, String? error) {
    _addLog('Connection status changed', isConnected ? 'Connected' : 'Disconnected');
    setState(() {
      _connectedDeviceName = isConnected ? searchDeviceName : 'Unknown';
      _connectionStatus = isConnected ? 'Connected' : 'Disconnected';
      if (isConnected) {
        _discoverServices(deviceId); // Kutsutaan _discoverServices onnistuneen yhteyden jälkeen
      } else {
        _receivedValue = 'Waiting for data...';
      }
    });
  }


  Future<void> _discoverServices(String deviceId) async {
    try {
      _addLog('Discovering services...', '');
      List<BleService> services = await UniversalBle.discoverServices(deviceId);
      _addLog('Services discovered:', services.length);

      for (var service in services) {
        if (service.uuid == searchServiceUUID) {
          _addLog('Found service:', service.uuid);
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid == searchCharacteristicUUID) {
              _addLog('Found characteristic:', characteristic.uuid);

              // Enable notifications 
              await UniversalBle.setNotifiable(
                deviceId,
                searchServiceUUID,
                searchCharacteristicUUID,
                BleInputProperty.notification,
              );
              _addLog('Notifications enabled for:', characteristic.uuid);
              setState(() {
                _receivedValue = characteristic.uuid; 
    });
            }
          }
        }
      }
    } catch (e) {
      _addLog('Error discovering services: $e', '');
    }
  }

  void _onCharacteristicValueChange(
      String deviceId, String characteristicId, Uint8List value) {
    print('Raw data received: $value');
    String receivedString = String.fromCharCodes(value);
    _addLog('Received data:', receivedString);

    setState(() {
      _receivedValue = receivedString; 
    });
  }

  @override
  void dispose() {
    UniversalBle.disconnect(_connectedDeviceName);
    super.dispose();
  }

  void _addLog(String type, dynamic data) {
    if (mounted) {
      setState(() {
        _logs.add('$type: ${data.toString()}');
      });
    } else {
      print('$type: ${data.toString()}'); // Tulostetaan loki konsoliin, jos setState ei ole mahdollinen
    }
  
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            
            Text('Connection Status: $_connectionStatus'),
            Text('Connected Device: $_connectedDeviceName'),
            const SizedBox(height: 20),
            Text(
              'Received Value: $_receivedValue',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ResultWidget(
              results: _logs,
              onClearTap: (int? index) {
                setState(() {
                  if (index != null) {
                    _logs.removeAt(index);
                  } else {
                    _logs.clear();
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}