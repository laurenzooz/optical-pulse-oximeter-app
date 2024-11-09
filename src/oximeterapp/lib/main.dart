import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:universal_ble/universal_ble.dart';

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
  String _receivedValue = 'test'; 
  //final List<FlSpot> mockData = [];
  int counter = 0;
  Timer? timer;

  String searchDeviceName = 'Optical Pulse Oximeter';
  String searchServiceUUID = 'adf2a6e6-9b6d-4b5f-a487-77e21aafbc88';
  String searchCharasteristicUUID = '2A37'; 

  @override
  void initState() {
    super.initState();
    _initializeBLE();

    UniversalBle.onValueChange = _onCharacteristicValueChange; 
    //_startUpdatingData();
  }

  Future<void> _initializeBLE() async {
    AvailabilityState state = await UniversalBle.getBluetoothAvailabilityState();
    if (state != AvailabilityState.poweredOn) {
      print('Bluetooth is not enabled');
      return;
    }

    UniversalBle.onScanResult = (device) {
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
      setState(() {
        _connectedDeviceName = device.name ?? 'Unknown';
      });

      await UniversalBle.discoverServices(device.deviceId);
      List<BleService> services =
          await UniversalBle.discoverServices(device.deviceId);
      for (var service in services) {
        if (service.uuid == searchServiceUUID) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid == searchCharasteristicUUID) {
              _readCharacteristicValue(device.deviceId, characteristic.uuid);
            }
          }
        }
      }
    } catch (e) {
      print('Error connecting to device: $e');
    }
  }

  Future<void> _readCharacteristicValue(
      String deviceId, String characteristicUuid) async {
    try {
      await UniversalBle.setNotifiable(
        deviceId,
        searchServiceUUID,
        characteristicUuid,
        BleInputProperty.notification,
      );
      print('Notifications enabled for characteristic: $characteristicUuid');

    } catch (e) {
      print('Error reading characteristic or setting notifications: $e');
      setState(() {
        _receivedValue = 'ERROR reading';
      });
    }
  }

  void _onCharacteristicValueChange(
      String deviceId, String characteristicUuid, Uint8List value) {
    // This callback will be triggered whenever the characteristic value changes
    if (characteristicUuid == searchCharasteristicUUID) { 
      String hexString = value.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ');
      setState(() {
        _receivedValue = 'Raw Bytes: $hexString';
      });
      print('Received data (hex): $hexString');
    }
  }

/*
  void _startUpdatingData() {
    timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        mockData.add(FlSpot(counter.toDouble(), _receivedValue));
        if (mockData.length > 50) {
          mockData.removeAt(0);
        }
        counter++;
      });
    });
  }*/

  @override
  void dispose() {
    // Disable notifications for the characteristic when the widget is disposed
    UniversalBle.setNotifiable(
      _connectedDeviceName, // Assuming this holds the deviceId 
      searchServiceUUID,
      searchCharasteristicUUID,
      BleInputProperty.disabled,
    );
    super.dispose();
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
            Text('Connected Device: $_connectedDeviceName'),
            const SizedBox(height: 20),
            Text(
              'Received Value: $_receivedValue',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            /*SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minX: mockData.isNotEmpty ? mockData.first.x : 0,
                  maxX: mockData.isNotEmpty ? mockData.last.x : 6,
                  minY: 50, 
                  maxY: 200, 
                  lineBarsData: [
                    LineChartBarData(
                      spots: mockData,
                      isCurved: false,
                      barWidth: 2,
                      color: const Color(0xFF347A6A),
                    ),
                  ],
                  titlesData: FlTitlesData(show: false),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: const Color(0xFFC9C9C9))),
                ),
              ),
            ),*/
          ],
        ),
      ),
    );
  }
}