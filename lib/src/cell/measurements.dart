import 'package:flutter/material.dart';

@immutable
class CellMeasurements {
  final double forwardScatter;
  final double sideScatter;
  final Map<String, double> fluorescence;
  final Map<String, double> additional;

  const CellMeasurements({
    required this.forwardScatter,
    required this.sideScatter,
    this.fluorescence = const {},
    this.additional = const {},
  });

  double? getMeasurement(String parameter) {
    if (parameter == 'FSC') return forwardScatter;
    if (parameter == 'SSC') return sideScatter;
    return fluorescence[parameter] ?? additional[parameter];
  }

  bool hasMeasurement(String parameter) {
    return parameters.contains(parameter);
  }

  List<String> get parameters => [
    'FSC',
    'SSC',
    ...fluorescence.keys,
    ...additional.keys,
  ];
}
