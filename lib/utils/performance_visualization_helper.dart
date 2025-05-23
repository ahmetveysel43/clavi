import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;

class PerformanceVisualizationHelper {
  /// Performans trendi grafiği oluşturur
  static Widget buildPerformanceTrendChart({
    required List<double> performanceValues,
    required List<String> dates,
    double? swc,
    double? mdc,
    bool isHigherBetter = true, // Yüksek değerler daha iyi mi?
    String title = 'Performans Trendi',
    String yAxisLabel = 'Değer',
    Color lineColor = Colors.blue,
    double? minY,
    double? maxY,
  }) {
    if (performanceValues.isEmpty || dates.isEmpty || performanceValues.length != dates.length) {
      return Container(
        height: 200,
        child: const Center(
          child: Text('Grafik için yeterli veri yok'),
        ),
      );
    }

    // Eksenleri belirle
    double chartMinY = minY ?? performanceValues.reduce((a, b) => a < b ? a : b) * 0.9;
    double chartMaxY = maxY ?? performanceValues.reduce((a, b) => a > b ? a : b) * 1.1;
    
    // Veri noktaları oluştur
    List<FlSpot> spots = [];
    for (int i = 0; i < performanceValues.length; i++) {
      spots.add(FlSpot(i.toDouble(), performanceValues[i]));
    }
    
    // Eğer SWC ve MDC değerleri varsa, bantlar oluştur
    List<HorizontalLine> extraLines = [];
    
    // Başlangıç değeri
    final startValue = performanceValues.isNotEmpty ? performanceValues.first : 0;
    
    // SWC bant oluştur
    if (swc != null) {
      final swcUpper = startValue + swc;
      final swcLower = startValue - swc;
      
      extraLines.add(
        HorizontalLine(
          y: swcUpper,
          color: Colors.orange.withOpacity(0.5),
          dashArray: [5, 5],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.topRight,
            labelResolver: (line) => 'SWC+',
            style: const TextStyle(color: Colors.orange, fontSize: 10),
          ),
        ),
      );
      
      extraLines.add(
        HorizontalLine(
          y: swcLower,
          color: Colors.orange.withOpacity(0.5),
          dashArray: [5, 5],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.bottomRight,
            labelResolver: (line) => 'SWC-',
            style: const TextStyle(color: Colors.orange, fontSize: 10),
          ),
        ),
      );
    }
    
    // MDC bant oluştur
    if (mdc != null) {
      final mdcUpper = startValue + mdc;
      final mdcLower = startValue - mdc;
      
      extraLines.add(
        HorizontalLine(
          y: mdcUpper,
          color: Colors.red.withOpacity(0.5),
          dashArray: [5, 5],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.topRight,
            labelResolver: (line) => 'MDC+',
            style: const TextStyle(color: Colors.red, fontSize: 10),
          ),
        ),
      );
      
      extraLines.add(
        HorizontalLine(
          y: mdcLower,
          color: Colors.red.withOpacity(0.5),
          dashArray: [5, 5],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.bottomRight,
            labelResolver: (line) => 'MDC-',
            style: const TextStyle(color: Colors.red, fontSize: 10),
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 300,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                horizontalInterval: (chartMaxY - chartMinY) / 5,
                verticalInterval: math.max(1, performanceValues.length ~/ 10).toDouble(),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < dates.length && index % math.max(1, dates.length ~/ 5) == 0) {
                        // Tarih string'ini DateTime'a çevir
                        try {
                          final date = DateTime.parse(dates[index]);
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              '${date.day}/${date.month}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        } catch (e) {
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              '$index',
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        }
                      }
                      return const SizedBox.shrink();
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(
                          value.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                    reservedSize: 40,
                  ),
                  axisNameWidget: Text(
                    yAxisLabel,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: true),
              minX: 0,
              maxX: (performanceValues.length - 1).toDouble(),
              minY: chartMinY,
              maxY: chartMaxY,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: lineColor,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: performanceValues.length < 15, // 15'ten az nokta varsa noktaları göster
                    getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                      radius: 4,
                      color: lineColor,
                      strokeWidth: 1,
                      strokeColor: Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: lineColor.withOpacity(0.2),
                  ),
                ),
              ],
              extraLinesData: ExtraLinesData(
                horizontalLines: extraLines,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  /// Performans değişimi kartı oluşturur
  static Widget buildPerformanceChangeCard({
    required double preValue,
    required double postValue,
    double? swc,
    double? mdc,
    bool isHigherBetter = true,
    String label = 'Performans',
    String unit = '',
    Color color = Colors.blue,
    VoidCallback? onTap,
  }) {
    final change = postValue - preValue;
    final percentChange = (change / preValue) * 100;
    
    // Değişim yönünü belirle
    final isPositiveChange = isHigherBetter ? change > 0 : change < 0;
    final changeIcon = isPositiveChange ? Icons.arrow_upward : Icons.arrow_downward;
    final changeColor = isPositiveChange ? Colors.green : Colors.red;
    
    // MDC yorumu
    String mdcComment = '';
    if (mdc != null) {
      if (change.abs() > mdc) {
        mdcComment = 'Gerçek değişim (>MDC)';
      } else {
        mdcComment = 'Ölçüm hatası dahilinde';
      }
    }
    
    // SWC yorumu
    String swcComment = '';
    if (swc != null) {
      if (change.abs() > swc) {
        swcComment = 'Anlamlı değişim (>SWC)';
      } else {
        swcComment = 'Minimal değişim (<SWC)';
      }
    }
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Önceki',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${preValue.toStringAsFixed(2)} $unit',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: changeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(changeIcon, color: changeColor, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${percentChange.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: changeColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sonraki',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${postValue.toStringAsFixed(2)} $unit',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (mdcComment.isNotEmpty || swcComment.isNotEmpty) ...[
                const Divider(),
                if (mdcComment.isNotEmpty)
                  Text(
                    mdcComment,
                    style: TextStyle(
                      fontSize: 12,
                      color: change.abs() > (mdc ?? 0) ? Colors.green : Colors.orange,
                    ),
                  ),
                if (swcComment.isNotEmpty)
                  Text(
                    swcComment,
                    style: TextStyle(
                      fontSize: 12,
                      color: change.abs() > (swc ?? 0) ? Colors.green : Colors.orange,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  /// Performans özet kartı oluşturur
 // lib/utils/performance_visualization_helper.dart

// ... other code ...

  static Widget buildPerformanceSummaryCard({
    required Map<String, dynamic> analysis,
    required String title,
    required String unit,
    Color color = Colors.blue,
    bool isHigherBetter = true,
    VoidCallback? onTap,
  }) {
    final mean = analysis['mean'] as double? ?? 0;
    final stdDev = analysis['stdDev'] as double? ?? 0;
    final cvPercentage = analysis['cvPercentage'] as double? ?? 0;
    final typicalityIndex = analysis['typicalityIndex'] as double? ?? 0;
    final trend = analysis['trend'] as double? ?? 0;
    final firstDate = analysis['firstDate'] as String? ?? '';
    final lastDate = analysis['lastDate'] as String? ?? '';

    String formattedFirstDate = '';
    String formattedLastDate = '';
    try {
      if (firstDate.isNotEmpty) {
        final firstDateTime = DateTime.parse(firstDate);
        formattedFirstDate = '${firstDateTime.day}/${firstDateTime.month}/${firstDateTime.year}';
      }
      if (lastDate.isNotEmpty) {
        final lastDateTime = DateTime.parse(lastDate);
        formattedLastDate = '${lastDateTime.day}/${lastDateTime.month}/${lastDateTime.year}';
      }
    } catch (e) {
      // Keep original if parsing fails
      formattedFirstDate = firstDate;
      formattedLastDate = lastDate;
    }

    IconData trendIcon;
    Color trendColor;
    if (trend > 0) {
      trendIcon = Icons.trending_up;
      trendColor = isHigherBetter ? Colors.green : Colors.red;
    } else if (trend < 0) {
      trendIcon = Icons.trending_down;
      trendColor = isHigherBetter ? Colors.red : Colors.green;
    } else {
      trendIcon = Icons.trending_flat;
      trendColor = Colors.orange;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start, // Align items to the start vertically
                children: [
                  Expanded( // Title should be able to take available space
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                      // overflow: TextOverflow.ellipsis, // Optional: if title can be very long
                      // maxLines: 2,
                    ),
                  ),
                  const SizedBox(width: 8), // Add spacing before trend indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: trendColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(trendIcon, color: trendColor, size: 16),
                        const SizedBox(width: 4),
                        Text( // Removed Flexible here as Row is MainAxisSize.min
                          'Trend: ${trend.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: trendColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          // overflow: TextOverflow.ellipsis, // Optional
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (formattedFirstDate.isNotEmpty && formattedLastDate.isNotEmpty)
                Text(
                  '$formattedFirstDate - $formattedLastDate',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                )
              else if (formattedFirstDate.isNotEmpty)
                 Text(
                  formattedFirstDate,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                )
              else if (lastDate.isNotEmpty)
                 Text(
                  formattedLastDate,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              const SizedBox(height: 16),
              Row( // This is the Row around line 435
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded( // Wrap _buildSummaryMetric with Expanded
                    child: _buildSummaryMetric(
                      label: 'Ortalama',
                      value: '${mean.toStringAsFixed(2)} $unit',
                      icon: Icons.bar_chart,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 8), // Spacing
                  Expanded( // Wrap _buildSummaryMetric with Expanded
                    child: _buildSummaryMetric(
                      label: 'Std. Sapma',
                      value: stdDev.toStringAsFixed(2),
                      icon: Icons.waves,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 8), // Spacing
                  Expanded( // Wrap _buildSummaryMetric with Expanded
                    child: _buildSummaryMetric(
                      label: 'CV%',
                      value: '${cvPercentage.toStringAsFixed(1)}%',
                      icon: Icons.percent,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Tutarlılık Skoru: ${typicalityIndex.toStringAsFixed(0)}/100',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: typicalityIndex / 100,
                color: _getTypicalityColor(typicalityIndex),
                backgroundColor: Colors.grey[200],
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildSummaryMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 4),
        Text( // No Flexible needed here as parent Expanded will handle width
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 14, // Slightly reduce font size if space is tight
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 1, // Constrain to one line for value
        ),
        const SizedBox(height: 2),
        Text( // No Flexible needed here
          label,
          style: TextStyle(
            fontSize: 11, // Slightly reduce font size
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 1, // Constrain to one line for label
        ),
      ],
    );
  }
  
  static Color _getTypicalityColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.lightGreen;
    if (score >= 40) return Colors.orange;
    if (score >= 20) return Colors.deepOrange;
    return Colors.red;
  }
}