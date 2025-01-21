// device_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive/hive.dart';
import 'dart:math'; // max() を使う場合に必要
import '../data/measurement_data.dart';
import 'previous_data_chart.dart'; // 過去データ表示画面（実装は別ファイル）

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  // 接続状態
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;

  // デバイスから取得したサービスやキャラクタリスティクスのリスト
  List<BluetoothService> _services = [];

  // ★ 変数を「速度」「圧力1」「圧力2」で 3 つに分割
  List<double> velocityData = [];
  List<double> pressureData0 = [];
  List<double> pressureData1 = [];

  // グラフの y 軸最大値を管理
  double maxYValue = 150;

  // ターゲットのサービス/キャラクタリスティクス UUID
  final Guid targetServiceUUID = Guid("12345678-1234-5678-1234-56789abcdef0");
  final Guid targetCharacteristicUUID = Guid("abcdef12-3456-7890-1234-56789abcdef0");

  late StreamSubscription<BluetoothConnectionState> _connectionStateSubscription;

  @override
  void initState() {
    super.initState();

    // デバイスの接続状態を監視し、UI を更新
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

  // 接続中かどうか
  bool get isConnected {
    return _connectionState == BluetoothConnectionState.connected;
  }

  /// 受信した生データを "pressureData0", "pressureData1", "velocityData" に振り分ける
  /// BLE から受け取った文字列はカンマ区切り想定
  /// データの順番は「余り0→圧力1、余り1→圧力2、余り2→速度」
  Map<String, List<double>> processReceivedData(String rawValue) {
    try {
      // カンマ区切りで分割して double に変換
      List<double> dataList = rawValue
          .split(',')
          .map((item) => double.parse(item.trim()))
          .toList();

      // 3 種類に振り分け
      List<double> mod3_0List = []; // pressureData0
      List<double> mod3_1List = []; // pressureData1
      List<double> mod3_2List = []; // velocityData

      for (int i = 0; i < dataList.length; i++) {
        if (i % 3 == 0) {
          mod3_0List.add(dataList[i]);
        } else if (i % 3 == 1) {
          mod3_1List.add(dataList[i]);
        } else {
          mod3_2List.add(dataList[i]);
        }
      }

      // 受け取った部分の最大値を確認し、グラフ用の maxYValue を更新
      setState(() {
        double newMax = maxYValue;

        if (mod3_0List.isNotEmpty) {
          double localMax = mod3_0List.reduce(max);
          newMax = newMax > localMax ? newMax : localMax;
        }
        if (mod3_1List.isNotEmpty) {
          double localMax = mod3_1List.reduce(max);
          newMax = newMax > localMax ? newMax : localMax;
        }
        if (mod3_2List.isNotEmpty) {
          double localMax = mod3_2List.reduce(max);
          newMax = newMax > localMax ? newMax : localMax;
        }

        maxYValue = newMax;
      });

      return {
        "pressureList0": mod3_0List,
        "pressureList1": mod3_1List,
        "velocityList": mod3_2List,
      };
    } catch (e) {
      print("Error processing data: $e");
      // エラー時は空のリストを返す
      return {
        "pressureList0": [],
        "pressureList1": [],
        "velocityList": [],
      };
    }
  }

  /// 計測開始（Notify を購読）してデータを受信
  Future<void> subscribeToNotifications() async {
    // 新たに計測を開始する前にリストを初期化
    velocityData = [];
    pressureData0 = [];
    pressureData1 = [];

    try {
      // サービスを探索
      _services = await widget.device.discoverServices();

      // ターゲットサービスを見つける
      final BluetoothService targetService =
      _services.firstWhere((s) => s.uuid == targetServiceUUID);

      // ターゲットキャラクタリスティクスを見つける
      final BluetoothCharacteristic characteristic =
      targetService.characteristics
          .firstWhere((c) => c.uuid == targetCharacteristicUUID);

      // 計測開始要求を送信（相手側が受け取って処理を開始する想定）
      await characteristic.write(utf8.encode("Start Measurement"));

      // Notify の購読を有効にする
      await characteristic.setNotifyValue(true);

      // 受信したデータを listen し、UI に反映
      characteristic.value.listen((value) {
        final String decodedValue = utf8.decode(value);
        print("Notification Received (Decoded): $decodedValue");

        // データをパースして 3 種類のリストに分割
        Map<String, List<double>> processedData = processReceivedData(decodedValue);

        setState(() {
          velocityData.addAll(processedData["velocityList"] ?? []);
          pressureData0.addAll(processedData["pressureList0"] ?? []);
          pressureData1.addAll(processedData["pressureList1"] ?? []);
        });
      });

      print("通知購読を開始しました。");
    } catch (e) {
      print("Notification Subscription Error: $e");
    }
  }

  /// BLE デバイスに接続
  Future<void> onConnectPressed() async {
    try {
      await widget.device.connect();
      print("Connect: Success");
    } catch (e) {
      print("Connect Error: $e");
    }
  }

  /// BLE デバイスから切断
  Future<void> onDisconnectPressed() async {
    try {
      await widget.device.disconnect();
      print("Disconnect: Success");
    } catch (e) {
      print("Disconnect Error: $e");
    }
  }

  /// CONNECT / DISCONNECT ボタン
  Widget buildConnectButton(BuildContext context) {
    return Row(
      children: [
        TextButton(
          onPressed: isConnected ? onDisconnectPressed : onConnectPressed,
          child: Text(
            isConnected ? "DISCONNECT" : "CONNECT",
            style: Theme.of(context).primaryTextTheme.labelLarge?.copyWith(
              color: Colors.white,
            ),
          ),
        )
      ],
    );
  }

  /// 計測開始ボタン
  Widget buildMeasureButton() {
    return Visibility(
      visible: isConnected,
      child: ElevatedButton(
        onPressed: subscribeToNotifications,
        child: const Text("計測を始める"),
      ),
    );
  }

  /// グラフ描画（速度、圧力1、圧力2 の 3 本をプロット）
  Widget buildGraph(
      double screenWidth,
      List<double> velocityList,
      List<double> pressureList0,
      List<double> pressureList1,
      ) {
    return SizedBox(
      width: screenWidth * 0.95,
      height: screenWidth * 0.95 * 0.65,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            // Velocity（青）
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
            // Pressure 0（赤）
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
            // Pressure 1（緑）
            LineChartBarData(
              spots: pressureList1.asMap().entries.map((entry) {
                int index = entry.key;
                double value = entry.value;
                return FlSpot(index.toDouble(), value);
              }).toList(),
              isCurved: false,
              color: Colors.green,
              dotData: FlDotData(show: false),
            ),
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              axisNameWidget: const Text('[Value]', style: TextStyle(fontSize: 12)),
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
              axisNameWidget: const Text('[Value]', style: TextStyle(fontSize: 12)),
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

  /// 過去データを見るボタン
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

  /// 計測データを Hive に保存
  Future<void> saveMeasurementData() async {
    // Hive で管理する MeasurementData を作成
    // ここでは、MeasurementData にフィールドを追加している前提です
    final measurementData = MeasurementData(
      dateTime: DateTime.now(),
      velocityData: velocityData,
      pressureData0: pressureData0,
      pressureData1: pressureData1,
    );

    // box に追加して永続化
    final box = Hive.box<MeasurementData>('measurementDataBox');
    await box.add(measurementData);
    print("データを保存しました。");
  }

  /// 計測を終了してデータ保存
  Widget buildStopAndSaveButton() {
    return ElevatedButton(
      onPressed: () async {
        // 必要に応じて計測停止の処理を相手側へ送信するならここで書く
        // 例: Stop Measurement など

        // データ保存
        await saveMeasurementData();

        // リストをクリア
        setState(() {
          velocityData.clear();
          pressureData0.clear();
          pressureData1.clear();
        });
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
            const SizedBox(height: 20),
            isConnected
                ? buildMeasureButton()
                : const Text(
              "つながっていません",
              style: TextStyle(fontSize: 16, color: Colors.red),
            ),
            // 受信データがあるときのみ「計測を終了して保存」ボタンを表示
            if (velocityData.isNotEmpty ||
                pressureData0.isNotEmpty ||
                pressureData1.isNotEmpty)
              buildStopAndSaveButton(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: buildGraph(
                  screenWidth,
                  velocityData,
                  pressureData0,
                  pressureData1,
                ),
              ),
            ),
            // 過去データを見るボタン
            buildViewPastDataButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
