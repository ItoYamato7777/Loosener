import 'package:hive/hive.dart';

part 'measurement_data.g.dart';

@HiveType(typeId: 0)
class MeasurementData extends HiveObject {
  @HiveField(0)
  DateTime dateTime;

  @HiveField(1)
  List<double> velocityData;

  @HiveField(2)
  List<double> pressureData0;

  @HiveField(3)
  List<double> pressureData1;

  MeasurementData({
    required this.dateTime,
    required this.velocityData,
    required this.pressureData0,
    required this.pressureData1,
  });
}
