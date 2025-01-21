// previous_data_chart.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:fl_chart/fl_chart.dart';
import '../data/measurement_data.dart';

class PreviousDataChart extends StatefulWidget {
  @override
  _PreviousDataChartState createState() => _PreviousDataChartState();
}

class _PreviousDataChartState extends State<PreviousDataChart> {
  late Box<MeasurementData> measurementBox;

  @override
  void initState() {
    super.initState();
    measurementBox = Hive.box<MeasurementData>('measurementDataBox');
  }

  void deleteMeasurement(int index) {
    setState(() {
      measurementBox.deleteAt(index);
    });
  }

  void showGraph(MeasurementData data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MeasurementGraphScreen(measurementData: data),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("過去の計測データ"),
        ),
        body: ListView.builder(
          itemCount: measurementBox.length,
          itemBuilder: (context, index) {
            final data = measurementBox.getAt(index)!;
            final formattedDate = "${data.dateTime.year}/${data.dateTime.month}/${data.dateTime.day} ${data.dateTime.hour}:${data.dateTime.minute}:${data.dateTime.second}";
            return ListTile(
              title: Text(formattedDate),
              trailing: IconButton(
                icon: Icon(Icons.delete),
                onPressed: () {
                  deleteMeasurement(index);
                },
              ),
              onTap: () {
                showGraph(data);
              },
            );
          },
        ));
  }
}

class MeasurementGraphScreen extends StatelessWidget {
  final MeasurementData measurementData;

  MeasurementGraphScreen({required this.measurementData});

  @override
  Widget build(BuildContext context) {
    final velocityList = measurementData.velocityData;
    final pressureList0 = measurementData.pressureData0;
    final pressureList1 = measurementData.pressureData1;
    final maxYValue = [
      ...velocityList,
      ...pressureList0,
      ...pressureList1,
    ].reduce((a, b) => a > b ? a : b);

    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Text("計測データのグラフ"),
      ),
      body: Center(
        child: buildGraph(screenWidth, velocityList, pressureList0, maxYValue),
      ),
    );
  }

  Widget buildGraph(double screenWidth, List<double> velocityList, List<double> pressureList, double maxYValue) {
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
}
