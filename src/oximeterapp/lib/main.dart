import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
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
  final List<FlSpot> mockData = [];
  int counter = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _startUpdatingData();
  }

  void _startUpdatingData() {
    timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        // Generate a random value for demonstration purposes
        double newValue = 60 + Random().nextDouble() * 20;

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
