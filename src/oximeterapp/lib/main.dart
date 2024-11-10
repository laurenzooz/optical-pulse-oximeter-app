import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _connectionStatus = 'Disconnected';
  final String _targetDeviceName = 'Optical Pulse Oximeter'; // Replace with your device name
  final String _targetServiceUuid = 'adf2a6e6-9b6d-4b5f-a487-77e21aafbc88'; // Replace with your service UUID
  final String _targetCharacteristicUuid = '00002a37-0000-1000-8000-00805f9b34fb'; // Replace with your characteristic UUID
  List<BleDevice> _discoveredDevices = [];
  final List<String> _receivedDataLogs = [];

  @override
  void initState() {
    super.initState();
    UniversalBle.onConnectionChange = _onConnectionChange;
    UniversalBle.onValueChange = _onValueChange;
    UniversalBle.onScanResult = _onScanResult;
    _checkBluetoothAvailability();
  }

  void _checkBluetoothAvailability() async {
    AvailabilityState state = await UniversalBle.getBluetoothAvailabilityState();
    if (state == AvailabilityState.poweredOn) {
      _startScan();
    }
    UniversalBle.onAvailabilityChange = (state) {
      if (state == AvailabilityState.poweredOn) {
        _startScan();
      }
    };
  }

  void _startScan() {
    UniversalBle.startScan(
      scanFilter: ScanFilter(
        withServices: [_targetServiceUuid],
      ),
    );
  }

  void _onScanResult(BleDevice device) {
    // Check if the device is already in the list
    if (!_discoveredDevices.any((element) => element.deviceId == device.deviceId)) {
      setState(() {
        _discoveredDevices.add(device);
        _receivedDataLogs.add('Discovered device: ${device.name} - ${device.deviceId}');
      });
    }
  }

  void _onConnectionChange(String deviceId, bool isConnected, String? error) {
    setState(() {
      _connectionStatus = isConnected ? 'Connected' : 'Disconnected';
      _receivedDataLogs.add('Connection status changed: $_connectionStatus');
    });
    if (isConnected) {
      _discoverServices(deviceId);
    }
  }

  Future<void> _discoverServices(String deviceId) async {

    setState(() {
        _receivedDataLogs.add('Trying to rediscover');
      });
    try {
      List<BleService> services = await UniversalBle.discoverServices(deviceId);
      for (var service in services) {
        setState(() {
        _receivedDataLogs.add(service.uuid);
      });
        if (service.uuid == _targetServiceUuid) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid == _targetCharacteristicUuid) {

              setState(() {
                _receivedDataLogs.add('Trying to rediscover');
              });
              // Check if the characteristic supports notification or indication
            //  if (characteristic.properties.contains(CharacteristicProperty.notify) ||
              //    characteristic.properties.contains(CharacteristicProperty.indicate)) {
                await UniversalBle.setNotifiable(
                  deviceId,
                  service.uuid,
                  characteristic.uuid,
                  BleInputProperty.notification, // or BleInputProperty.indication if supported
                );
                setState(() {
                  _receivedDataLogs.add('Notification set for characteristic ${characteristic.uuid}');
                });
             // } else {
               // setState(() {
                  _receivedDataLogs.add('Characteristic ${characteristic.uuid} does not support notification/indication');
                //});
              //}
            }
          }
        } else {
          setState(() {
                  _receivedDataLogs.add('No device found vittu');
                });
        }
      }
    } catch (e) {
      setState(() {
        _receivedDataLogs.add('Error discovering services: $e');
      });
    }
  }

  void _onValueChange(String deviceId, String characteristicId, List<int> value) {
    final dataAsString = String.fromCharCodes(value);
    setState(() {
      _receivedDataLogs.add('Raw data: $value');
      _receivedDataLogs.add('Decoded data: $dataAsString');
    });
  }

  Future<void> _connectToDevice() async {
    try {
      for (BleDevice device in _discoveredDevices) {
        if (device.name == _targetDeviceName) {
          setState(() {
            _receivedDataLogs.add('Attempting to connect to ${device.name}');
          });
          await UniversalBle.connect(device.deviceId);
          break;
        }
      }
    } catch (e) {
      setState(() {
        _receivedDataLogs.add('Error connecting to device: $e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('BLE Test App'),
        ),
        body: Column(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text('Connection Status: $_connectionStatus'),
                  ElevatedButton(
                    onPressed: _connectToDevice,
                    child: const Text('Connect'),
                  ),
                   ElevatedButton(
                  onPressed: () {
                    if (_connectionStatus == 'Connected') {
                      _discoverServices(_discoveredDevices.firstWhere((d) => d.name == _targetDeviceName).deviceId);
                    } else {
                      setState(() {
                        _receivedDataLogs.add('Device not connected. Connect first.');
                      });
                    }
                  },
                  child: const Text('Rediscover Services'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ListView.builder(
                  itemCount: _receivedDataLogs.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_receivedDataLogs[index]),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
