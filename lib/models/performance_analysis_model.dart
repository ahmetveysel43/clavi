class PerformanceAnalysis {
 final int? id;
 final int sporcuId;
 final String olcumTuru;
 final String degerTuru;
 final String timeRange;
 final DateTime? startDate;
 final DateTime? endDate;
 final DateTime calculationDate;
 
 // Temel İstatistikler
 final double mean;
 final double standardDeviation;
 final double coefficientOfVariation;
 final double minimum;
 final double maximum;
 final double range;
 final double median;
 final int sampleCount;
 final double q25;
 final double q75;
 final double iqr;
 
 // Gelişmiş Analizler
 final double typicalityIndex;
 final double momentum;
 final double trendSlope;
 final double trendStability;
 final double trendRSquared;
 final double trendStrength;
 
 // Güvenilirlik Metrikleri
 final double swc;
 final double mdc;
 final double testRetestReliability;
 final double icc;
 final double cvPercent;
 
 // Performans Değerlendirme
 final String performanceClass;
 final String performanceTrend;
 final double recentChange;
 final double recentChangePercent;
 final int outliersCount;
 
 // Ham Veriler (JSON string olarak)
 final String performanceValuesJson;
 final String datesJson;
 final String zScoresJson;
 final String outliersJson;
 
 // Metadata
 final String analysisVersion;
 final Map<String, dynamic>? additionalData;

 PerformanceAnalysis({
   this.id,
   required this.sporcuId,
   required this.olcumTuru,
   required this.degerTuru,
   required this.timeRange,
   this.startDate,
   this.endDate,
   required this.calculationDate,
   required this.mean,
   required this.standardDeviation,
   required this.coefficientOfVariation,
   required this.minimum,
   required this.maximum,
   required this.range,
   required this.median,
   required this.sampleCount,
   required this.q25,
   required this.q75,
   required this.iqr,
   required this.typicalityIndex,
   required this.momentum,
   required this.trendSlope,
   required this.trendStability,
   required this.trendRSquared,
   required this.trendStrength,
   required this.swc,
   required this.mdc,
   required this.testRetestReliability,
   required this.icc,
   required this.cvPercent,
   required this.performanceClass,
   required this.performanceTrend,
   required this.recentChange,
   required this.recentChangePercent,
   required this.outliersCount,
   required this.performanceValuesJson,
   required this.datesJson,
   required this.zScoresJson,
   required this.outliersJson,
   this.analysisVersion = '1.0',
   this.additionalData,
 });

 Map<String, dynamic> toMap() {
   return {
     'id': id,
     'sporcu_id': sporcuId,
     'olcum_turu': olcumTuru,
     'deger_turu': degerTuru,
     'time_range': timeRange,
     'start_date': startDate?.toIso8601String(),
     'end_date': endDate?.toIso8601String(),
     'calculation_date': calculationDate.toIso8601String(),
     'mean': mean,
     'standard_deviation': standardDeviation,
     'coefficient_of_variation': coefficientOfVariation,
     'minimum': minimum,
     'maximum': maximum,
     'range_value': range, // DÜZELTİLDİ: 'range' yerine 'range_value'
     'median': median,
     'sample_count': sampleCount,
     'q25': q25,
     'q75': q75,
     'iqr': iqr,
     'typicality_index': typicalityIndex,
     'momentum': momentum,
     'trend_slope': trendSlope,
     'trend_stability': trendStability,
     'trend_r_squared': trendRSquared,
     'trend_strength': trendStrength,
     'swc': swc,
     'mdc': mdc,
     'test_retest_reliability': testRetestReliability,
     'icc': icc,
     'cv_percent': cvPercent,
     'performance_class': performanceClass,
     'performance_trend': performanceTrend,
     'recent_change': recentChange,
     'recent_change_percent': recentChangePercent,
     'outliers_count': outliersCount,
     'performance_values_json': performanceValuesJson,
     'dates_json': datesJson,
     'z_scores_json': zScoresJson,
     'outliers_json': outliersJson,
     'analysis_version': analysisVersion,
     'additional_data': additionalData != null ? 
         additionalData.toString() : null,
   };
 }

 factory PerformanceAnalysis.fromMap(Map<String, dynamic> map) {
   return PerformanceAnalysis(
     id: map['id']?.toInt(),
     sporcuId: map['sporcu_id']?.toInt() ?? 0,
     olcumTuru: map['olcum_turu'] ?? '',
     degerTuru: map['deger_turu'] ?? '',
     timeRange: map['time_range'] ?? '',
     startDate: map['start_date'] != null ? 
         DateTime.tryParse(map['start_date']) : null,
     endDate: map['end_date'] != null ? 
         DateTime.tryParse(map['end_date']) : null,
     calculationDate: DateTime.tryParse(map['calculation_date']) ?? 
         DateTime.now(),
     mean: map['mean']?.toDouble() ?? 0.0,
     standardDeviation: map['standard_deviation']?.toDouble() ?? 0.0,
     coefficientOfVariation: map['coefficient_of_variation']?.toDouble() ?? 0.0,
     minimum: map['minimum']?.toDouble() ?? 0.0,
     maximum: map['maximum']?.toDouble() ?? 0.0,
     range: map['range_value']?.toDouble() ?? 0.0, // DÜZELTİLDİ: 'range' yerine 'range_value'
     median: map['median']?.toDouble() ?? 0.0,
     sampleCount: map['sample_count']?.toInt() ?? 0,
     q25: map['q25']?.toDouble() ?? 0.0,
     q75: map['q75']?.toDouble() ?? 0.0,
     iqr: map['iqr']?.toDouble() ?? 0.0,
     typicalityIndex: map['typicality_index']?.toDouble() ?? 0.0,
     momentum: map['momentum']?.toDouble() ?? 0.0,
     trendSlope: map['trend_slope']?.toDouble() ?? 0.0,
     trendStability: map['trend_stability']?.toDouble() ?? 0.0,
     trendRSquared: map['trend_r_squared']?.toDouble() ?? 0.0,
     trendStrength: map['trend_strength']?.toDouble() ?? 0.0,
     swc: map['swc']?.toDouble() ?? 0.0,
     mdc: map['mdc']?.toDouble() ?? 0.0,
     testRetestReliability: map['test_retest_reliability']?.toDouble() ?? 0.0,
     icc: map['icc']?.toDouble() ?? 0.0,
     cvPercent: map['cv_percent']?.toDouble() ?? 0.0,
     performanceClass: map['performance_class'] ?? '',
     performanceTrend: map['performance_trend'] ?? '',
     recentChange: map['recent_change']?.toDouble() ?? 0.0,
     recentChangePercent: map['recent_change_percent']?.toDouble() ?? 0.0,
     outliersCount: map['outliers_count']?.toInt() ?? 0,
     performanceValuesJson: map['performance_values_json'] ?? '[]',
     datesJson: map['dates_json'] ?? '[]',
     zScoresJson: map['z_scores_json'] ?? '[]',
     outliersJson: map['outliers_json'] ?? '[]',
     analysisVersion: map['analysis_version'] ?? '1.0',
     additionalData: map['additional_data'] != null ? 
         map['additional_data'] as Map<String, dynamic>? : null,
   );
 }

 PerformanceAnalysis copyWith({
   int? id,
   int? sporcuId,
   String? olcumTuru,
   String? degerTuru,
   String? timeRange,
   DateTime? startDate,
   DateTime? endDate,
   DateTime? calculationDate,
   double? mean,
   double? standardDeviation,
   double? coefficientOfVariation,
   double? minimum,
   double? maximum,
   double? range,
   double? median,
   int? sampleCount,
   double? q25,
   double? q75,
   double? iqr,
   double? typicalityIndex,
   double? momentum,
   double? trendSlope,
   double? trendStability,
   double? trendRSquared,
   double? trendStrength,
   double? swc,
   double? mdc,
   double? testRetestReliability,
   double? icc,
   double? cvPercent,
   String? performanceClass,
   String? performanceTrend,
   double? recentChange,
   double? recentChangePercent,
   int? outliersCount,
   String? performanceValuesJson,
   String? datesJson,
   String? zScoresJson,
   String? outliersJson,
   String? analysisVersion,
   Map<String, dynamic>? additionalData,
 }) {
   return PerformanceAnalysis(
     id: id ?? this.id,
     sporcuId: sporcuId ?? this.sporcuId,
     olcumTuru: olcumTuru ?? this.olcumTuru,
     degerTuru: degerTuru ?? this.degerTuru,
     timeRange: timeRange ?? this.timeRange,
     startDate: startDate ?? this.startDate,
     endDate: endDate ?? this.endDate,
     calculationDate: calculationDate ?? this.calculationDate,
     mean: mean ?? this.mean,
     standardDeviation: standardDeviation ?? this.standardDeviation,
     coefficientOfVariation: coefficientOfVariation ?? this.coefficientOfVariation,
     minimum: minimum ?? this.minimum,
     maximum: maximum ?? this.maximum,
     range: range ?? this.range,
     median: median ?? this.median,
     sampleCount: sampleCount ?? this.sampleCount,
     q25: q25 ?? this.q25,
     q75: q75 ?? this.q75,
     iqr: iqr ?? this.iqr,
     typicalityIndex: typicalityIndex ?? this.typicalityIndex,
     momentum: momentum ?? this.momentum,
     trendSlope: trendSlope ?? this.trendSlope,
     trendStability: trendStability ?? this.trendStability,
     trendRSquared: trendRSquared ?? this.trendRSquared,
     trendStrength: trendStrength ?? this.trendStrength,
     swc: swc ?? this.swc,
     mdc: mdc ?? this.mdc,
     testRetestReliability: testRetestReliability ?? this.testRetestReliability,
     icc: icc ?? this.icc,
     cvPercent: cvPercent ?? this.cvPercent,
     performanceClass: performanceClass ?? this.performanceClass,
     performanceTrend: performanceTrend ?? this.performanceTrend,
     recentChange: recentChange ?? this.recentChange,
     recentChangePercent: recentChangePercent ?? this.recentChangePercent,
     outliersCount: outliersCount ?? this.outliersCount,
     performanceValuesJson: performanceValuesJson ?? this.performanceValuesJson,
     datesJson: datesJson ?? this.datesJson,
     zScoresJson: zScoresJson ?? this.zScoresJson,
     outliersJson: outliersJson ?? this.outliersJson,
     analysisVersion: analysisVersion ?? this.analysisVersion,
     additionalData: additionalData ?? this.additionalData,
   );
 }
}