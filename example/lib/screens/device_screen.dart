import 'dart:async';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  List<BluetoothService> _services = [];
  Map<String, List<double>> processedDataMap = {};
  List<double> velocityData = [];
  List<double> pressureData =[];
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

  /// BLEデータを処理してカンマ区切りの文字列を奇数・偶数で分けた数値リストに変換
  Map<String, List<double>> processReceivedData(String rawValue) {
    try {
      // カンマ区切りで分割し、数値に変換
      List<double> dataList = rawValue
          .split(',')
          .map((item) => double.parse(item.trim()))
          .toList();
      // 奇数と偶数リストを作成
      List<double> oddList = [];
      List<double> evenList = [];
      for (int i = 0; i < dataList.length; i++) {
        if (i % 2 == 0) {
          oddList.add(dataList[i]); // 0ベースで偶数インデックスは奇数個目
        } else {
          evenList.add(dataList[i]); // 1ベースで偶数インデックス
        }
      }
      // oddListとevenListの中の最大値をmaxYValueに代入する
      setState(() {
        double newMax = maxYValue; // 現在の maxYValue を保持

        if (oddList.isNotEmpty) {
          double oddMax = oddList.reduce((a, b) => a > b ? a : b);
          newMax = newMax > oddMax ? newMax : oddMax; // より大きい値を選ぶ
        }

        if (evenList.isNotEmpty) {
          double evenMax = evenList.reduce((a, b) => a > b ? a : b);
          newMax = newMax > evenMax ? newMax : evenMax; // より大きい値を選ぶ
        }

        maxYValue = newMax; // 更新された最大値を代入
      });


      // 結果をMapで返す
      return {
        "velocityList": oddList,
        "pressureList": evenList,
      };
    } catch (e) {
      print("Error processing data: $e");
      return {
        "velocityList": [],
        "pressureList": [],
      };
    }
  }


  Future<void> subscribeToNotifications() async {
    processedDataMap = {};
    velocityData = [];
    pressureData =[];
    try {
      _services = await widget.device.discoverServices();
      final BluetoothService targetService = _services.firstWhere((s) => s.uuid == targetServiceUUID);
      final BluetoothCharacteristic characteristic =
      targetService.characteristics.firstWhere((c) => c.uuid == targetCharacteristicUUID);
      //計測開始の要求を送信
      await characteristic.write(utf8.encode("Start Measurement"));
      await characteristic.setNotifyValue(true);
      characteristic.value.listen((value) {
        final String decodedValue = utf8.decode(value);
        print("Notification Received (Decoded): $decodedValue");

        // データを処理してリストに変換
        Map<String, List<double>> processedDataMap = processReceivedData(decodedValue);

        print("受け取ったデータを処理したもの  $processedDataMap");

        // 一時的なリストにデータを保存
        List<double> tempVelocityData = processedDataMap["velocityList"] ?? [];
        List<double> tempPressureData = processedDataMap["pressureList"] ?? [];

        // グラフデータを更新（メインリストにマージ）
        setState(() {
          velocityData.addAll(tempVelocityData);
          pressureData.addAll(tempPressureData);
        });

        print("velocity Data: $velocityData");
        print("pressure Data: $pressureData");
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
          ))
    ]);
  }

  Widget buildMeasureButton() {
    return Visibility(
      //visible: isConnected,
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
              dotData: FlDotData(show: false), // 点を非表示に設定
            ),
            LineChartBarData(
              spots: pressureList.asMap().entries.map((entry) {
                int index = entry.key;
                double value = entry.value;
                return FlSpot(index.toDouble(), value);
              }).toList(),
              isCurved: false,
              color: Colors.red,
              dotData: FlDotData(show: false), // 点を非表示に設定
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


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.platformName),
        actions: [buildConnectButton(context)],
      ),
      body: Align( // Column全体の横方向の配置を中央揃えにする
        alignment: Alignment.topCenter, // 上部中央に配置
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start, // 縦方向は上から順に配置
          crossAxisAlignment: CrossAxisAlignment.center, // 横方向は中央揃え
          children: [
            SizedBox(height: 20), // AppBarとボタン間に余白を追加
            isConnected
                ? buildMeasureButton() // isConnected が true の場合
                : const Text( // isConnected が false の場合
                  "つながっていません",
                  style: TextStyle(fontSize: 16, color: Colors.red),
                ),
            Expanded(child: Padding(padding: const EdgeInsets.all(16.0), child: buildGraph(screenWidth, velocityData, pressureData))),
          ],
        ),
      ),
    );
  }
}
