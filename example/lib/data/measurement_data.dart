// import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';
// import 'package:hive_flutter/hive_flutter.dart';
//
// import 'device_screen.dart';
// import 'measurement_data.dart';
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Hive.initFlutter();
//   Hive.registerAdapter(MeasurementDataAdapter());
//   await Hive.openBox<MeasurementData>('measurementDataBox');
//
//   runApp(MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   // アプリのウィジェットツリーを構築
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Bluetooth Measurement App',
//       home: DeviceScreen(device: /* ここにBluetoothDeviceを渡します */),
//     );
//   }
// }
