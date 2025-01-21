// device_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive/hive.dart';
import '../data/measurement_data.dart';
import 'previous_data_chart.dart'; // 追加

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  List<BluetoothService> _services = [];
  List<double> velocityData = [];
  List<double> pressureData = [];
  /*変数を増やした。
  List<double> velocityData = [];
  List<double> pressureData0 = [];
  List<double> pressureData1 = [];
   */
  double maxYValue = 150;
  final Guid targetServiceUUID = Guid("12345678-1234-5678-1234-56789abcdef0");
  final Guid targetCharacteristicUUID = Guid("abcdef12-3456-7890-1234-56789abcdef0");

  late StreamSubscription<BluetoothConnectionState> _connectionStateSubscription;

  @override
  void initState() {
    super.initState();

    _connectionStateSubscription = widget.device.connectionState.listen((state) {
      setState(() {
        _connectionState = state;
      });
    });
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    super.dispose();
  }

  bool get isConnected {
    return _connectionState == BluetoothConnectionState.connected;
  }

  Map<String, List<double>> processReceivedData(String rawValue) {
    try {
      List<double> dataList = rawValue
          .split(',')
          .map((item) => double.parse(item.trim()))
          .toList();
      List<double> oddList = [];
      List<double> evenList = [];
      for (int i = 0; i < dataList.length; i++) {
        if (i % 2 == 0) {
          oddList.add(dataList[i]);
        } else {
          evenList.add(dataList[i]);
        }
      }
      /*3で割った余りが0のところに圧力データ1、余りが1のところに圧力データ2、余りが2のところに速度データを格納させる。
      List<double> mod3_0List = [];
      List<double> mod3_1List = [];
      List<double> mod3_2List = [];
      for (int i = 0; i < dataList.length; i++) {
        if (i % 3 == 0) {
          mod3_0List.add(dataList[i]);
        } else if (int i % 3 == 1){
          mod3_1List.add(dataList[i]);
        } else {
          mod3_2List.add(dataList[i]);
      }
      */

      setState(() {
        double newMax = maxYValue;

        if (oddList.isNotEmpty) {
          double oddMax = oddList.reduce((a, b) => a > b ? a : b);
          newMax = newMax > oddMax ? newMax : oddMax;
        }

        if (evenList.isNotEmpty) {
          double evenMax = evenList.reduce((a, b) => a > b ? a : b);
          newMax = newMax > evenMax ? newMax : evenMax;
        }

        maxYValue = newMax;
      });
      /*増えた3つの変数のうちの最大値
      setState(() {
        double newMax = maxYValue;

        if (mod3_0List.isNotEmpty) {
          double oddMax = oddList.reduce((a, b) => a > b ? a : b);
          newMax = newMax > oddMax ? newMax : oddMax;
        }

        if (mod3_1List.isNotEmpty) {
          double evenMax = evenList.reduce((a, b) => a > b ? a : b);
          newMax = newMax > evenMax ? newMax : evenMax;
        }
        if (mod3_2List.isNotEmpty) {
          double evenMax = evenList.reduce((a, b) => a > b ? a : b);
          newMax = newMax > evenMax ? newMax : evenMax;
        }
        maxYValue = newMax;
      });
       */

      return {
        "velocityList": oddList,
        "pressureList": evenList,
        /*増えた変数
        "velocityList": mod3_0List,
        "pressureList0": mod3_1List,
        "pressureList1": mod3_2List,
         */
      };
    } catch (e) {
      print("Error processing data: $e");
      return {
        "velocityList": [],
        "pressureList": [],
      };
      /*
      return {
        "velocityList": [],
        "pressureList0": [],
        "pressureList1": [],
       */
    }
  }

  Future<void> subscribeToNotifications() async {
    velocityData = [];
    pressureData = [];
    /*
    velocityData = [];
    pressureData0 = [];
    pressureData1 = [];
     */
    try {
      _services = await widget.device.discoverServices();
      final BluetoothService targetService = _services.firstWhere((s) => s.uuid == targetServiceUUID);
      final BluetoothCharacteristic characteristic =
      targetService.characteristics.firstWhere((c) => c.uuid == targetCharacteristicUUID);

      // 計測開始の要求を送信
      await characteristic.write(utf8.encode("Start Measurement"));
      await characteristic.setNotifyValue(true);

      characteristic.value.listen((value) {
        final String decodedValue = utf8.decode(value);
        print("Notification Received (Decoded): $decodedValue");

        Map<String, List<double>> processedData = processReceivedData(decodedValue);

        // データを追加
        setState(() {
          velocityData.addAll(processedData["velocityList"] ?? []);
          pressureData.addAll(processedData["pressureList"] ?? []);
        });
        /*
        setState(() {
          velocityData.addAll(processedData["velocityList"] ?? []);
          pressureData0.addAll(processedData["pressureList0"] ?? []);
          pressureData1.addAll(processedData["pressureList1"] ?? []);
        });
         */
      });

      print("通知購読を開始しました。");
    } catch (e) {
      print("Notification Subscription Error: $e");
    }
  }

  Future<void> onConnectPressed() async {
    try {
      await widget.device.connect();
      print("Connect: Success");
    } catch (e) {
      print("Connect Error: $e");
    }
  }

  Future<void> onDisconnectPressed() async {
    try {
      await widget.device.disconnect();
      print("Disconnect: Success");
    } catch (e) {
      print("Disconnect Error: $e");
    }
  }

  Widget buildConnectButton(BuildContext context) {
    return Row(children: [
      TextButton(
        onPressed: isConnected ? onDisconnectPressed : onConnectPressed,
        child: Text(
          isConnected ? "DISCONNECT" : "CONNECT",
          style: Theme.of(context).primaryTextTheme.labelLarge?.copyWith(color: Colors.white),
        ),
      )
    ]);
  }

  Widget buildMeasureButton() {
    return Visibility(
      visible: isConnected,
      child: ElevatedButton(
        onPressed: subscribeToNotifications,
        child: const Text("計測を始める"),
      ),
    );
  }

  Widget buildGraph(double screenWidth, List<double> velocityList, List<double> pressureList) {
    return SizedBox(
      width: screenWidth * 0.95,
      height: screenWidth * 0.95 * 0.65,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: velocityList.asMap().entries.map((entry) {
                int index = entry.key;
                double value = entry.value;
                return FlSpot(index.toDouble(), value);
              }).toList(),
              isCurved: false,
              color: Colors.blue,
              dotData: FlDotData(show: false),
            ),
            LineChartBarData(
              spots: pressureList.asMap().entries.map((entry) {
                int index = entry.key;
                double value = entry.value;
                return FlSpot(index.toDouble(), value);
              }).toList(),
              isCurved: false,
              color: Colors.red,
              dotData: FlDotData(show: false),
            ),
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              axisNameWidget: const Text('[km/h]', style: TextStyle(fontSize: 12)),
              sideTitles: SideTitles(
                showTitles: true,
                interval: 20,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(
              axisNameWidget: const Text('[kg]', style: TextStyle(fontSize: 12)),
              sideTitles: SideTitles(
                showTitles: true,
                interval: 20,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              axisNameWidget: const Text('時間経過', style: TextStyle(fontSize: 12)),
              sideTitles: SideTitles(
                showTitles: true,
                interval: 10,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
          ),
          maxY: maxYValue,
          minY: 0,
          borderData: FlBorderData(show: true),
        ),
      ),
    );
  }
/*3つに増えた
Widget buildGraph(double screenWidth, List<double> velocityList, List<double> pressureList0, List<double> pressureList1) {
    return SizedBox(
      width: screenWidth * 0.95,
      height: screenWidth * 0.95 * 0.65,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: velocityList.asMap().entries.map((entry) {
                int index = entry.key;
                double value = entry.value;
                return FlSpot(index.toDouble(), value);
              }).toList(),
              isCurved: false,
              color: Colors.blue,
              dotData: FlDotData(show: false),
            ),
            LineChartBarData(
              spots: pressureList0.asMap().entries.map((entry) {
                int index = entry.key;
                double value = entry.value;
                return FlSpot(index.toDouble(), value);
              }).toList(),
              isCurved: false,
              color: Colors.red,
              dotData: FlDotData(show: false),
            ),
            LineChartBarData(
              spots: pressureList1.asMap().entries.map((entry) {
                int index = entry.key;
                double value = entry.value;
                return FlSpot(index.toDouble(), value);
              }).toList(),
              isCurved: false,
              color: Colors.red,
              dotData: FlDotData(show: false),
            ),
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              axisNameWidget: const Text('[km/h]', style: TextStyle(fontSize: 12)),
              sideTitles: SideTitles(
                showTitles: true,
                interval: 20,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(
              axisNameWidget: const Text('[kg]', style: TextStyle(fontSize: 12)),
              sideTitles: SideTitles(
                showTitles: true,
                interval: 20,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              axisNameWidget: const Text('時間経過', style: TextStyle(fontSize: 12)),
              sideTitles: SideTitles(
                showTitles: true,
                interval: 10,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
          ),
          maxY: maxYValue,
          minY: 0,
          borderData: FlBorderData(show: true),
        ),
      ),
    );
  }
 */


  // 過去データを見るボタンを追加
  Widget buildViewPastDataButton() {
    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PreviousDataChart()),
        );
      },
      child: const Text("過去データを見る"),
    );
  }

  // データを保存する関数を追加
  Future<void> saveMeasurementData() async {
    final measurementData = MeasurementData(
      dateTime: DateTime.now(),
      velocityData: velocityData,
      pressureData: pressureData,
      /*
      velocityData: velocityData,
      pressureData0: pressureData0,
      pressureData1: pressureData1,
       */
    );

    final box = Hive.box<MeasurementData>('measurementDataBox');
    await box.add(measurementData);
    print("データを保存しました。");
  }

  // 計測を終了し、データを保存するボタンを追加
  Widget buildStopAndSaveButton() {
    return ElevatedButton(
      onPressed: () async {
        // 計測終了処理をここに記述（必要に応じて）
        await saveMeasurementData();
        // データをクリア
        setState(() {
          velocityData = [];
          pressureData = [];
        });
        /*
        setState(() {
          velocityData = [];
          pressureData0 = [];
          pressureData1 = [];
        });
         */
      },
      child: const Text("計測を終了して保存"),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
        actions: [buildConnectButton(context)],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 20),
            isConnected
                ? buildMeasureButton()
                : const Text(
              "つながっていません",
              style: TextStyle(fontSize: 16, color: Colors.red),
            ),
            // 計測中のみ「計測を終了して保存」ボタンを表示
            if (velocityData.isNotEmpty || pressureData.isNotEmpty) buildStopAndSaveButton(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: buildGraph(screenWidth, velocityData, pressureData),
              ),
            ),
            // 過去データを見るボタンを追加
            buildViewPastDataButton(),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}