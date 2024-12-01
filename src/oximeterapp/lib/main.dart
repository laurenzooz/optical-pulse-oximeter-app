import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:fl_chart/fl_chart.dart';

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
  String searchCharacteristicUUID = '00002a37-0000-1000-8000-00805f9b34fb';

  final List<FlSpot> bpmData = [];
  int counter = 0;
  int graphMaxSize = 8192;
  int graphDrawnSize = 80;

  double currentMinX = 0.0;
  double currentMaxX = 80.0; // Initial range


  DateTime? lastUpdate;

  @override
  void initState() {
    super.initState();
    _initializeBLE();
    UniversalBle.onValueChange = _onCharacteristicValueChange;
    UniversalBle.onConnectionChange = _onConnectionChange;
  }

  Future<void> _initializeBLE() async {
    AvailabilityState state =
        await UniversalBle.getBluetoothAvailabilityState();
    if (state != AvailabilityState.poweredOn) {
      return;
    }

    UniversalBle.onScanResult = (device) {
      print("Device found: ${device.name}"); // Log device name
      if (device.name == searchDeviceName) {
        _connectToDevice(device);
        UniversalBle.stopScan();
      }
    };
    UniversalBle.startScan();
  }

  Future<void> _connectToDevice(BleDevice device) async {
    try {
      await UniversalBle.connect(device.deviceId);
      // _discoverServices is now called in _onConnectionChange after successful connection
    } catch (e) {
      setState(() {
        _connectionStatus = 'Error connecting';
      });
    }
  }

  void _onConnectionChange(String deviceId, bool isConnected, String? error) {
    setState(() {
      _connectedDeviceName = isConnected ? searchDeviceName : 'Unknown';
      _connectionStatus = isConnected ? 'Connected' : 'Disconnected';
      if (isConnected) {
        _discoverServices(
            deviceId); // Kutsutaan _discoverServices onnistuneen yhteyden jälkeen
      } else {
        _receivedValue = 'Waiting for data...';
      }
    });
  }

  Future<void> _discoverServices(String deviceId) async {
    try {
      List<BleService> services = await UniversalBle.discoverServices(deviceId);

      for (var service in services) {
        if (service.uuid == searchServiceUUID) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid == searchCharacteristicUUID) {
              // Enable notifications
              await UniversalBle.setNotifiable(
                deviceId,
                searchServiceUUID,
                searchCharacteristicUUID,
                BleInputProperty.notification,
              );
              print('Notifications enabled for: ${characteristic.uuid}');
            }
          }
        }
      }
    } catch (e) {
      print('Error discovering services: $e');
    }
  }
  
void _onCharacteristicValueChange(
    String deviceId, String characteristicId, Uint8List value) {
  final currentTime = DateTime.now();

  if (value[2] > 0 && value[1] < 255) {
    _receivedValue = value[2].toString();
  } else {
    _receivedValue = 'Waiting for data...';
  }

  // Check if 50ms have passed since the last update
  if (lastUpdate == null || currentTime.difference(lastUpdate!).inMilliseconds >= 20) {
    lastUpdate = currentTime; // Update the last update time

    setState(() {      
      counter++;

      // Add the new data point
      bpmData.add(FlSpot(counter.toDouble(), value[1].toDouble()));
      // Keep the list to a fixed size by removing the oldest data point
      if (bpmData.length > graphMaxSize) {
        bpmData.removeAt(0);
      }

      if (counter > graphDrawnSize) {
          currentMinX += 1; // Increment minX gradually
          currentMaxX += 1; // Increment maxX gradually
        }
    });
  }
}


  @override
  void dispose() {
    UniversalBle.disconnect(_connectedDeviceName);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Connection Status: $_connectionStatus',  style: const TextStyle(color: Colors.white)),
            Text('Connected Device: $_connectedDeviceName',  style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 20),
            Text(
              '$_receivedValue ❤️',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              
            ),

            // draw graph
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(       
                  minX: currentMinX,
                  maxX: currentMaxX,
                  minY: -20.0,
                  maxY: 320.0,
                  lineBarsData: [
                  LineChartBarData(
                    spots: bpmData,
                    isCurved: false,
                    barWidth: 2,
                    color: const Color.fromARGB(255, 121, 173, 161),
                    dotData: FlDotData(show: false),
                  ),
                ],
                  titlesData: FlTitlesData(show: false),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: const Color(0xFFC9C9C9))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
