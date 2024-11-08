import 'dart:async';
import 'dart:math';
import 'dart:typed_data'; // Import the dart:typed_data library
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
  double _floatValue = 0.0;
  final List<FlSpot> mockData = [];
  int counter = 0;
  Timer? timer;

  String searchDeviceName = 'Optical Pulse Oximeter';
  String searchServiceUUID = 'adf2a6e6-9b6d-4b5f-a487-77e21aafbc88';
  String searchCharasteristicUUID = '2A37';

  @override
  void initState() {
    super.initState();
    _initializeBLE();
    _startUpdatingData();
  }

  Future<void> _initializeBLE() async {
    // 1. Check Bluetooth availability
    AvailabilityState state = await UniversalBle.getBluetoothAvailabilityState();
    if (state != AvailabilityState.poweredOn) {
      // Handle Bluetooth not enabled
      print('Bluetooth is not enabled');
      return;
    }

    // 2. Start scanning for devices
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
      // 3. Connect to the device
      await UniversalBle.connect(device.deviceId);
      setState(() {
        _connectedDeviceName = device.name ?? 'Unknown';
      });

      // 4. Discover services and characteristics
      await UniversalBle.discoverServices(device.deviceId);
      List<BleService> services = await UniversalBle.discoverServices(device.deviceId);
      for (var service in services) {
        if (service.uuid == searchServiceUUID) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid == searchCharasteristicUUID) {
              _readFloatValue(device.deviceId, characteristic.uuid);
            }
          }
        }
      }
    } catch (e) {
      // Handle connection error
      print('Error connecting to device: $e');
    }
  }

  Future<void> _readFloatValue(String deviceId, String characteristicUuid) async {
    try {
      // 5. Read the float value
      Uint8List data = await UniversalBle.readValue(
      deviceId,
      searchServiceUUID, // Replace with your service UUID
      characteristicUuid,
    );

      // 6. Convert byte data to float
      if (data.length == 4) {
        ByteData byteData = ByteData.view(Uint8List.fromList(data).buffer);
        double floatValue = byteData.getFloat32(0, Endian.little); // Adjust endianness if needed
        setState(() {
          _floatValue = floatValue;
        });
      } else {
        print('Invalid data length for float value');
      }
    } catch (e) {
      // Handle read error
      print('Error reading characteristic: $e');
    }
  }

  void _startUpdatingData() {
    timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        // Use the _floatValue received from the BLE device
        double newValue = _floatValue; 

        // Add the new data point
        mockData.add(FlSpot(counter.toDouble(), newValue));

        // Keep the list to a fixed size by removing the oldest data point
        if (mockData.length > 50) {
          mockData.removeAt(0);
        }

        // Increment counter for the x-axis
        counter++;
      });
    });
  }

  @override
  void dispose() {
    timer?.cancel(); // Cancel the timer to free resources when not in use
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
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minX: mockData.isNotEmpty ? mockData.first.x : 0,
                  maxX: mockData.isNotEmpty ? mockData.last.x : 6,
                  minY: 50, // Fixed y-axis minimum
                  maxY: 80, // Fixed y-axis maximum
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
                      show: true, border: Border.all(color: const Color(0xFFC9C9C9))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}