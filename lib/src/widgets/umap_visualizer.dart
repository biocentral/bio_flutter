import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:bio_flutter/bio_flutter.dart';
import 'package:bio_flutter/src/util/format_util.dart';

@immutable
class UmapVisualizer extends StatefulWidget {
  final double radius;

  final UMAPData umapData;
  final List<Map<String, String>>? pointData;
  final String? pointIdentifierKey;

  const UmapVisualizer({super.key, required this.umapData, this.pointData, this.pointIdentifierKey, this.radius = 6.0});

  @override
  State<UmapVisualizer> createState() => _UmapVisualizerState();
}

class _UmapVisualizerState extends State<UmapVisualizer> {
  static const Color _defaultColor = Colors.blue;
  static const TextStyle _defaultTextStyle = TextStyle(fontSize: 10);
  static const int _maxCharsToDisplay = 20; // Tooltips, Categories

  late Color _dotColor;
  late TextStyle _textStyle;

  // category -> (sub-category -> number of values in pointData for sub-category)
  late Map<String, UMAPCategory>? _selectableUMAPCategories;

  late Map<String, Color>? _subCategoryToColorMap;
  late Map<String, bool>? _visibleSubCategoriesMap;

  String? _selectedCategory;
  final List<int> _selectedSpots = [];

  @override
  void initState() {
    super.initState();
    _selectableUMAPCategories = UMAPData.sortedUMAPCategoriesFromPointData(widget.pointData);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _textStyle = Theme.of(context).textTheme.displaySmall ?? _defaultTextStyle;
    try {
      _dotColor = Theme.of(context).colorScheme.secondary;
    } catch (e) {
      _dotColor = _defaultColor;
    }
  }

  List<ScatterSpot> scatterSpotsFromUmapData() {
    if (_selectedCategory != null) {
      List<ScatterSpot> result = [];

      int index = 0;
      for ((double, double) coordinate in widget.umapData.coordinates) {
        String categoryValueOfProtein = widget.pointData![index][_selectedCategory]!;
        // Filter invisible categories
        if (_visibleSubCategoriesMap![categoryValueOfProtein] == true) {
          result.add(ScatterSpot(coordinate.$1, coordinate.$2,
              dotPainter: FlDotCirclePainter(
                  color: _subCategoryToColorMap![categoryValueOfProtein] ?? _defaultColor, radius: widget.radius)));
        }
        index++;
      }
      return result;
    }

    final FlDotCirclePainter dotPainter = FlDotCirclePainter(color: _dotColor, radius: widget.radius);
    return widget.umapData.coordinates
        .map((coordinate) => ScatterSpot(coordinate.$1, coordinate.$2, dotPainter: dotPainter))
        .toList();
  }

  Map<String, Color> calculateCategoryToColorMap() {
    Map<String, Color> result = {};

    if (_selectedCategory != null) {
      int index = 0;
      for (String categoryValue in _selectableUMAPCategories![_selectedCategory!]!.subCategoriesWithOccurrences.keys) {
        // TODO Color palette
        result[categoryValue] = Colors.primaries[index % Colors.primaries.length];
        index += 1;
      }
    }
    return result;
  }

  String getTooltipInformationFromSpotIndex(int spotIndex) {
    Map<String, String>? pointDataPoint = widget.pointData?.elementAt(spotIndex);
    if (pointDataPoint == null) {
      return "";
    }
    String tooltipText = "";
    if (widget.pointIdentifierKey != null && pointDataPoint[widget.pointIdentifierKey] != null) {
      tooltipText += pointDataPoint[widget.pointIdentifierKey]!;
    }
    if (_selectedCategory != null && pointDataPoint[_selectedCategory] != null) {
      tooltipText += "\n";
      tooltipText += shorten(pointDataPoint[_selectedCategory]!, _maxCharsToDisplay);
    }
    return tooltipText;
  }

  void onSelectedCategory(String? selectedCategory) {
    _selectedCategory = selectedCategory;
    _subCategoryToColorMap = calculateCategoryToColorMap();
    if (_selectedCategory == null) {
      _visibleSubCategoriesMap = null;
    } else {
      List<String> subCategories =
          _selectableUMAPCategories![_selectedCategory!]!.subCategoriesWithOccurrences.keys.toList();
      _visibleSubCategoriesMap = Map.fromEntries(
          List.generate(subCategories.length, (index) => MapEntry<String, bool>(subCategories[index], true)));
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(border: Border.all()),
        child: Column(
          children: [
            Flexible(flex: 1, child: buildCategorySelectionMenu()),
            Flexible(
              flex: 4,
              child: Row(
                children: [
                  Flexible(
                    flex: 3,
                    fit: FlexFit.loose,
                    child: buildScatterChart(),
                  ),
                  Flexible(flex: 1, child: buildCategoryValueDisplay()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCategorySelectionMenu() {
    if (_selectableUMAPCategories == null) {
      return Container();
    }

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: DropdownMenu<String>(
        enableFilter: false,
        leadingIcon: const Icon(Icons.search),
        label: const Text("Select category.."),
        dropdownMenuEntries: _selectableUMAPCategories!.entries
            .map((MapEntry<String, UMAPCategory> entry) => DropdownMenuEntry<String>(
                value: entry.key,
                label: "${entry.value.name}: ${entry.value.subCategoriesWithOccurrences.length} subcategories"))
            .toList(),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          contentPadding: EdgeInsets.symmetric(vertical: 5.0),
        ),
        onSelected: onSelectedCategory,
      ),
    );
  }

  Widget buildScatterChart() {
    double minX = widget.umapData.minX();
    double maxX = widget.umapData.maxX();
    double minY = widget.umapData.minY();
    double maxY = widget.umapData.maxY();
    double axisIntervalHorizontal = (maxX - minX);
    double axisIntervalVertical = (maxY - minY);

    List<ScatterSpot> scatterSpots = scatterSpotsFromUmapData();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ScatterChart(
        ScatterChartData(
            scatterSpots: scatterSpots,
            minX: minX,
            maxX: maxX,
            minY: minY,
            maxY: maxY,
            borderData: FlBorderData(
              show: true,
            ),
            gridData: const FlGridData(
              show: true,
            ),
            titlesData: FlTitlesData(
                show: true,
                leftTitles: AxisTitles(
                    sideTitles: SideTitles(reservedSize: 50, showTitles: true, interval: axisIntervalVertical)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(reservedSize: 0, showTitles: false)),
                bottomTitles: AxisTitles(
                    sideTitles: SideTitles(reservedSize: 50, showTitles: true, interval: axisIntervalHorizontal)),
                topTitles: const AxisTitles(sideTitles: SideTitles(reservedSize: 0, showTitles: false))),
            showingTooltipIndicators: _selectedSpots,
            scatterTouchData: ScatterTouchData(
              enabled: true,
              handleBuiltInTouches: false,
              mouseCursorResolver: (FlTouchEvent touchEvent, ScatterTouchResponse? response) {
                return response == null || response.touchedSpot == null ? MouseCursor.defer : SystemMouseCursors.click;
              },
              touchTooltipData: ScatterTouchTooltipData(
                tooltipBgColor: Colors.black,
                getTooltipItems: (ScatterSpot touchedBarSpot) {
                  int indexOfSpot = scatterSpots.indexOf(touchedBarSpot);
                  String tooltipText = getTooltipInformationFromSpotIndex(indexOfSpot);
                  return ScatterTooltipItem(
                    tooltipText,
                    textStyle: TextStyle(
                      height: 1.2,
                      color: Colors.grey[100],
                      fontStyle: FontStyle.italic,
                    ),
                    bottomMargin: 10,
                  );
                },
              ),
              touchCallback: widget.pointData == null
                  ? null
                  : (FlTouchEvent event, ScatterTouchResponse? touchResponse) {
                      if (touchResponse == null || touchResponse.touchedSpot == null) {
                        return;
                      }
                      if (event is FlTapUpEvent) {
                        final sectionIndex = touchResponse.touchedSpot!.spotIndex;
                        setState(() {
                          if (_selectedSpots.contains(sectionIndex)) {
                            _selectedSpots.remove(sectionIndex);
                          } else {
                            _selectedSpots.add(sectionIndex);
                          }
                        });
                      }
                    },
            )),
        swapAnimationDuration: const Duration(milliseconds: 0), // No animation
      ),
    );
  }

  Widget buildCategoryValueDisplay() {
    if (_selectedCategory == null) {
      return Container();
    }

    List<MapEntry<String, int>> subCategoriesWithOccurrences =
        _selectableUMAPCategories![_selectedCategory!]!.subCategoriesWithOccurrences.entries.toList();
    subCategoriesWithOccurrences.sort((e1, e2) => e1.value.compareTo(e2.value));
    subCategoriesWithOccurrences = subCategoriesWithOccurrences.reversed.toList();
    return SingleChildScrollView(
      child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.all(8.0),
          separatorBuilder: (context, index) {
            if (index != subCategoriesWithOccurrences.length - 1) {
              return const Divider();
            }
            return Container();
          },
          itemCount: subCategoriesWithOccurrences.length,
          itemBuilder: (context, index) {
            MapEntry<String, int> mapEntryValues = subCategoriesWithOccurrences.toList()[index];
            bool subCategoryVisibility = _visibleSubCategoriesMap?[mapEntryValues.key] ?? true;
            return Card(
              child: ListTile(
                title: Text("N: ${mapEntryValues.value} - ${shorten(mapEntryValues.key, _maxCharsToDisplay)}",
                    style: _textStyle.copyWith(color: _subCategoryToColorMap?[mapEntryValues.key] ?? _defaultColor)),
                trailing: IconButton(
                    icon: subCategoryVisibility ? const Icon(Icons.visibility) : const Icon(Icons.visibility_off),
                    onPressed: () {
                      if (_visibleSubCategoriesMap != null) {
                        setState(() {
                          _visibleSubCategoriesMap![mapEntryValues.key] = !subCategoryVisibility;
                        });
                      }
                    }),
              ),
            );
          }),
    );
  }
}
