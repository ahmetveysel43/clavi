// services/performance_analysis_service.dart

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/olcum_model.dart';
import '../utils/statistics_helper.dart';
import 'database_service.dart';

class PerformanceAnalysisService {
  final DatabaseService _databaseService = DatabaseService();
  
  Future<Map<String, dynamic>> getPerformanceSummary({
    required int sporcuId,
    required String olcumTuru,
    required String degerTuru,
    int lastNDays = 90,
  }) async {
    try {
      // Temel performans verilerini al
      final performances = await _getPerformanceData(
        sporcuId: sporcuId,
        olcumTuru: olcumTuru,
        degerTuru: degerTuru,
        lastNDays: lastNDays,
      );
      
      if (performances.isEmpty) {
        return {'error': 'Yeterli veri bulunamadı'};
      }
      
      final values = performances.map((p) => p['value'] as double).toList();
      final dates = performances.map((p) => p['date'] as String).toList();
      
      // Temel istatistikler
      final mean = StatisticsHelper.calculateMean(values);
      final stdDev = StatisticsHelper.calculateStandardDeviation(values);
      final cv = StatisticsHelper.calculateCV(values);
      final min = values.reduce(math.min);
      final max = values.reduce(math.max);
      final range = max - min;
      final median = StatisticsHelper.calculateMedian(values);
      
      // Gelişmiş analizler
      final typicalityIndex = StatisticsHelper.calculateTypicalityIndex(values);
      final momentum = StatisticsHelper.calculateMomentum(values);
      final trendAnalysis = StatisticsHelper.analyzePerformanceTrend(values);
      final zScores = StatisticsHelper.calculateZScores(values);
      
      // SWC hesaplaması - Düzeltilmiş
      final swc = await _calculateSWCWithPopulationData(
        sporcuId: sporcuId,
        olcumTuru: olcumTuru,
        degerTuru: degerTuru,
      );
      
      // MDC hesaplaması - Düzeltilmiş
      final mdc = await _calculateMDCFromDatabase(
        sporcuId: sporcuId,
        olcumTuru: olcumTuru,
        degerTuru: degerTuru,
      );
      
      // Test güvenilirlik verilerini al
      Map<String, dynamic> reliability = await _getTestReliability(
        olcumTuru: olcumTuru,
        degerTuru: degerTuru,
      );
      
      // Performans sınıflandırması
      final performanceClass = StatisticsHelper.classifyPerformance(values.last, values);
      
      // Son performans değişimi
      double recentChange = 0;
      double recentChangePercent = 0;
      if (values.length >= 2) {
        recentChange = values.last - values.first;
        recentChangePercent = values.first != 0 ? (recentChange / values.first) * 100 : 0;
      }
      
      // Outlier analizi
      final outliers = StatisticsHelper.detectOutliers(values);
      
      // Çeyreklik değerler
      final q25 = StatisticsHelper.calculatePercentile(values, 25);
      final q75 = StatisticsHelper.calculatePercentile(values, 75);
      final iqr = q75 - q25;
      
      // Performans trendi
      String performanceTrend = 'Kararlı';
      if (values.length >= 6) {
        final recent3 = values.sublist(values.length - 3);
        final previous3 = values.sublist(values.length - 6, values.length - 3);
        final recentMean = StatisticsHelper.calculateMean(recent3);
        final previousMean = StatisticsHelper.calculateMean(previous3);
        final changePercent = previousMean != 0 ? ((recentMean - previousMean) / previousMean) * 100 : 0;
        
        if (changePercent > 2) {
          performanceTrend = 'Yükseliş';
        } else if (changePercent < -2) {
          performanceTrend = 'Düşüş';
        }
      }
      
      return {
        // Temel istatistikler
        'mean': mean,
        'standardDeviation': stdDev,
        'coefficientOfVariation': cv,
        'minimum': min,
        'maximum': max,
        'range': range,
        'median': median,
        'count': values.length,
        'q25': q25,
        'q75': q75,
        'iqr': iqr,
        
        // Gelişmiş analizler
        'typicalityIndex': typicalityIndex,
        'momentum': momentum,
        'trendSlope': trendAnalysis['trend'],
        'trendStability': trendAnalysis['stability'],
        'trendRSquared': trendAnalysis['r_squared'],
        'trendStrength': trendAnalysis['trend_strength'],
        'zScores': zScores,
        
        // Güvenilirlik metrikleri
        'swc': swc,
        'mdc': mdc,
        'reliability': reliability,
        
        // Performans değerlendirme
        'performanceClass': performanceClass,
        'performanceTrend': performanceTrend,
        'recentChange': recentChange,
        'recentChangePercent': recentChangePercent,
        'outliers': outliers,
        'outliersCount': outliers.length,
        
        // Ham veriler
        'performanceValues': values,
        'dates': dates,
        'analysisDate': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {'error': 'Analiz sırasında hata: $e'};
    }
  }
  
  Future<List<Map<String, dynamic>>> _getPerformanceData({
    required int sporcuId,
    required String olcumTuru,
    required String degerTuru,
    required int lastNDays,
  }) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: lastNDays));
    final olcumler = await _databaseService.getOlcumlerBySporcuId(sporcuId);
    
    final filteredOlcumler = olcumler.where((olcum) {
      try {
        final olcumDate = DateTime.parse(olcum.olcumTarihi);
        return olcumDate.isAfter(cutoffDate) && 
               olcum.olcumTuru.toLowerCase() == olcumTuru.toLowerCase();
      } catch (e) {
        return false;
      }
    }).toList();
    
    final performances = <Map<String, dynamic>>[];
    
    for (final olcum in filteredOlcumler) {
      // Değer türü eşleştirmesi (case-insensitive)
      final deger = olcum.degerler.firstWhere(
        (d) => d.degerTuru.toLowerCase() == degerTuru.toLowerCase(),
        orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
      );
      
      if (deger.deger > 0) {
        performances.add({
          'value': deger.deger,
          'date': olcum.olcumTarihi,
          'testId': olcum.testId,
          'olcumSirasi': olcum.olcumSirasi,
        });
      }
    }
    
    // Tarihe göre sırala
    performances.sort((a, b) => a['date'].compareTo(b['date']));
    
    return performances;
  }
  
  /// Test güvenilirlik verilerini al
  Future<Map<String, dynamic>> _getTestReliability({
    required String olcumTuru,
    required String degerTuru,
  }) async {
    // Bu metodun gerçek implementasyonu veritabanına bağlı
    // Şimdilik varsayılan değerler döndürüyoruz
    
    Map<String, double> defaultReliability = {
      'CMJ': 0.95,
      'SJ': 0.93,
      'DJ': 0.88,
      'RJ': 0.82,
      'SPRINT': 0.98,
    };
    
    final reliability = defaultReliability[olcumTuru.toUpperCase()] ?? 0.90;
    
    return {
      'test_retest_reliability': reliability,
      'icc': reliability,
      'cv_percent': (1 - reliability) * 10, // Basit CV tahmini
      'source': 'Varsayılan değer',
    };
  }
  
  /// MDC hesaplaması - Düzeltilmiş metod
  Future<double> _calculateMDCFromDatabase({
    required int sporcuId,
    required String olcumTuru,
    required String degerTuru,
  }) async {
    try {
      // Aynı gün içinde yapılan test-retest ölçümlerini bul
      final olcumler = await _databaseService.getOlcumlerBySporcuId(sporcuId);
      
      Map<String, List<double>> dailyMeasurements = {};
      
      for (final olcum in olcumler) {
        if (olcum.olcumTuru.toLowerCase() != olcumTuru.toLowerCase()) continue;
        
        final date = olcum.olcumTarihi.split('T')[0]; // Sadece tarih kısmı
        final deger = olcum.degerler.firstWhere(
          (d) => d.degerTuru.toLowerCase() == degerTuru.toLowerCase(),
          orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
        );
        
        if (deger.deger > 0) {
          dailyMeasurements.putIfAbsent(date, () => []);
          dailyMeasurements[date]!.add(deger.deger);
        }
      }
      
      // Test-retest çiftlerini oluştur
      List<double> testRetestData = [];
      for (final measurements in dailyMeasurements.values) {
        if (measurements.length >= 2) {
          // Aynı gün içindeki ilk iki ölçümü test-retest olarak kullan
          testRetestData.add(measurements[0]);
          testRetestData.add(measurements[1]);
        }
      }
      
      if (testRetestData.length >= 4) {
        return StatisticsHelper.calculateMDC(testRetestData);
      }
      
      return 0.0;
    } catch (e) {
      debugPrint('MDC hesaplama hatası: $e');
      return 0.0;
    }
  }
  
  /// SWC hesaplaması - Populasyon verisi ile
  Future<double> _calculateSWCWithPopulationData({
    required int sporcuId,
    required String olcumTuru,
    required String degerTuru,
  }) async {
    try {
      // Tüm sporcuların verilerini al (populasyon verisi)
      final allSporcular = await _databaseService.getAllSporcular();
      List<double> populationData = [];
      
      for (final sporcu in allSporcular) {
        if (sporcu.id == sporcuId) continue; // Kendisini hariç tut
        
        final performances = await _getPerformanceData(
          sporcuId: sporcu.id!,
          olcumTuru: olcumTuru,
          degerTuru: degerTuru,
          lastNDays: 365, // Son 1 yıl
        );
        
        if (performances.isNotEmpty) {
          // Her sporcunun ortalamasını al
          final values = performances.map((p) => p['value'] as double).toList();
          populationData.add(StatisticsHelper.calculateMean(values));
        }
      }
      
      if (populationData.length >= 5) {
        // Test türüne özel SWC hesapla
        return StatisticsHelper.calculateSWCForTestType(
          populationData: populationData,
          testType: olcumTuru,
          athleteLevel: 'trained', // Bu bilgiyi sporcu modelinden alabilirsiniz
        );
      }
      
      // Populasyon verisi yoksa sporcunun kendi verilerini kullan
      final ownData = await _getPerformanceData(
        sporcuId: sporcuId,
        olcumTuru: olcumTuru,
        degerTuru: degerTuru,
        lastNDays: 365,
      );
      
      if (ownData.isNotEmpty) {
        final values = ownData.map((p) => p['value'] as double).toList();
        return StatisticsHelper.calculateSWC(betweenAthleteData: values);
      }
      
      return 0.0;
    } catch (e) {
      debugPrint('SWC hesaplama hatası: $e');
      return 0.0;
    }
  }
  
  /// Detaylı performans raporu
  Future<Map<String, dynamic>> getDetailedPerformanceReport({
    required int sporcuId,
    required String olcumTuru,
    required String degerTuru,
    int lastNDays = 90,
  }) async {
    
    final basicSummary = await getPerformanceSummary(
      sporcuId: sporcuId,
      olcumTuru: olcumTuru,
      degerTuru: degerTuru,
      lastNDays: lastNDays,
    );
    
    if (basicSummary.containsKey('error')) {
      return basicSummary;
    }
    
    final values = List<double>.from(basicSummary['performanceValues']);
    final dates = List<String>.from(basicSummary['dates']);
    
    // Ek analizler
    final intraIndividualCV = StatisticsHelper.calculateIntraIndividualCV(values);
    final percentiles = {
      '10th': StatisticsHelper.calculatePercentile(values, 10),
      '25th': StatisticsHelper.calculatePercentile(values, 25),
      '50th': StatisticsHelper.calculatePercentile(values, 50),
      '75th': StatisticsHelper.calculatePercentile(values, 75),
      '90th': StatisticsHelper.calculatePercentile(values, 90),
      '95th': StatisticsHelper.calculatePercentile(values, 95),
    };
    
    // Moving averages
    final movingAverage3 = StatisticsHelper.calculateMovingAverage(values, 3);
    final movingAverage5 = StatisticsHelper.calculateMovingAverage(values, 5);
    final exponentialMA = StatisticsHelper.calculateExponentialMovingAverage(values, 0.3);
    
    // Normalize edilmiş veriler
    final normalizedData = StatisticsHelper.normalizeData(values);
    final standardizedData = StatisticsHelper.standardizeData(values);
    
    // İlerleme analizi (eğer tarihler mevcut ise)
    Map<String, dynamic> progressAnalysis = {};
    if (dates.isNotEmpty) {
      try {
        final parsedDates = dates.map((d) => DateTime.parse(d)).toList();
        progressAnalysis = StatisticsHelper.analyzeAthleteProgress(
          performanceData: values,
          testDates: parsedDates,
          testType: olcumTuru,
          smallestWorthwhileChange: basicSummary['swc'],
          minimalDetectableChange: basicSummary['mdc'] > 0 ? basicSummary['mdc'] : null,
        );
      } catch (e) {
        progressAnalysis = {'error': 'Tarih analizi hatası: $e'};
      }
    }
    
    // RSI analizi (eğer sıçrama testi ise)
    Map<String, dynamic> rsiAnalysis = {};
    if (['CMJ', 'SJ', 'DJ', 'RJ'].contains(olcumTuru.toUpperCase())) {
      rsiAnalysis = await _calculateRSIAnalysis(sporcuId, olcumTuru, lastNDays);
    }
    
    // Sprint analizi (eğer sprint testi ise)
    Map<String, dynamic> sprintAnalysis = {};
    if (olcumTuru.toUpperCase() == 'SPRINT') {
      sprintAnalysis = await _calculateSprintAnalysis(sporcuId, lastNDays);
    }
    
    return {
      ...basicSummary,
      'intraIndividualCV': intraIndividualCV,
      'percentiles': percentiles,
      'movingAverage3': movingAverage3,
      'movingAverage5': movingAverage5,
      'exponentialMA': exponentialMA,
      'normalizedData': normalizedData,
      'standardizedData': standardizedData,
      'progressAnalysis': progressAnalysis,
      'rsiAnalysis': rsiAnalysis,
      'sprintAnalysis': sprintAnalysis,
    };
  }
  
  /// RSI analizi
  Future<Map<String, dynamic>> _calculateRSIAnalysis(int sporcuId, String olcumTuru, int lastNDays) async {
    try {
      // Flight time ve contact time verilerini al
      final flightTimeData = await _getPerformanceData(
        sporcuId: sporcuId,
        olcumTuru: olcumTuru,
        degerTuru: 'ucussuresi',
        lastNDays: lastNDays,
      );
      
      final contactTimeData = await _getPerformanceData(
        sporcuId: sporcuId,
        olcumTuru: olcumTuru,
        degerTuru: 'temassuresi',
        lastNDays: lastNDays,
      );
      
      if (flightTimeData.isEmpty || contactTimeData.isEmpty) {
        return {'error': 'RSI hesaplama için yeterli veri yok'};
      }
      
      final flightTimes = flightTimeData.map((d) => d['value'] as double).toList();
      final contactTimes = contactTimeData.map((d) => d['value'] as double).toList();
      
      // RSI hesaplamaları
      if (olcumTuru.toUpperCase() == 'RJ' && flightTimes.length == contactTimes.length) {
        return StatisticsHelper.calculateRepeatedJumpRSI(
          flightTimes: flightTimes,
          contactTimes: contactTimes,
        );
      } else if (flightTimes.isNotEmpty && contactTimes.isNotEmpty) {
        // Tek sıçrama RSI
        final avgFlightTime = StatisticsHelper.calculateMean(flightTimes);
        final avgContactTime = StatisticsHelper.calculateMean(contactTimes);
        
        final rsi = StatisticsHelper.calculateRSIFromFlightTime(
          flightTime: avgFlightTime,
          contactTime: avgContactTime,
        );
        
        return {
          'average_rsi': rsi,
          'flight_time_cv': StatisticsHelper.calculateCV(flightTimes),
          'contact_time_cv': StatisticsHelper.calculateCV(contactTimes),
        };
      }
      
      return {'error': 'RSI hesaplama verilerinde uyumsuzluk'};
    } catch (e) {
      return {'error': 'RSI analizi hatası: $e'};
    }
  }
  
  /// Sprint analizi
  Future<Map<String, dynamic>> _calculateSprintAnalysis(int sporcuId, int lastNDays) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: lastNDays));
      final olcumler = await _databaseService.getOlcumlerBySporcuId(sporcuId);
      
      final sprintOlcumler = olcumler.where((olcum) {
        try {
          final olcumDate = DateTime.parse(olcum.olcumTarihi);
          return olcumDate.isAfter(cutoffDate) && 
                 olcum.olcumTuru.toLowerCase() == 'sprint';
        } catch (e) {
          return false;
        }
      }).toList();
      
      if (sprintOlcumler.isEmpty) {
        return {'error': 'Sprint analizi için veri yok'};
      }
      
      // En son sprint testini analiz et
      final latestSprint = sprintOlcumler.last;
      
      // Kapı değerlerini topla
      Map<int, double> kapiDegerler = {};
      for (final deger in latestSprint.degerler) {
        final kapiMatch = RegExp(r'KAPI(\d+)').firstMatch(deger.degerTuru.toUpperCase());
        if (kapiMatch != null) {
          final kapiNo = int.parse(kapiMatch.group(1)!);
          kapiDegerler[kapiNo] = deger.deger;
        }
      }
      
      if (kapiDegerler.length < 3) {
        return {'error': 'Sprint analizi için yeterli kapı verisi yok'};
      }
      
      // Sprint kinematiği hesapla
      final kinematics = StatisticsHelper.calculateSprintKinematics(kapiDegerler);
      
      return {
        'latest_sprint_analysis': kinematics,
        'gate_count': kapiDegerler.length,
        'test_date': latestSprint.olcumTarihi,
      };
    } catch (e) {
      return {'error': 'Sprint analizi hatası: $e'};
    }
  }
  
  /// Sportçu karşılaştırma analizi
  Future<Map<String, dynamic>> compareAthletes({
    required List<int> sporcuIds,
    required String olcumTuru,
    required String degerTuru,
    int lastNDays = 90,
  }) async {
    try {
      Map<int, Map<String, dynamic>> athleteData = {};
      
      for (final sporcuId in sporcuIds) {
        final summary = await getPerformanceSummary(
          sporcuId: sporcuId,
          olcumTuru: olcumTuru,
          degerTuru: degerTuru,
          lastNDays: lastNDays,
        );
        
        if (!summary.containsKey('error')) {
          athleteData[sporcuId] = summary;
        }
      }
      
      if (athleteData.isEmpty) {
        return {'error': 'Karşılaştırma için yeterli veri yok'};
      }
      
      // Tüm sporcu değerlerini birleştir
      final allValues = <double>[];
      athleteData.values.forEach((data) {
        final values = List<double>.from(data['performanceValues']);
        allValues.addAll(values);
      });
      
      // Grup istatistikleri
      final groupStats = {
        'group_mean': StatisticsHelper.calculateMean(allValues),
        'group_std': StatisticsHelper.calculateStandardDeviation(allValues),
        'group_cv': StatisticsHelper.calculateCV(allValues),
        'between_athlete_swc': StatisticsHelper.calculateSWC(betweenAthleteData: allValues),
      };
      
      // Her sporcu için z-score hesapla (gruba göre)
      final groupMean = groupStats['group_mean']!;
      final groupStd = groupStats['group_std']!;
      
      for (final entry in athleteData.entries) {
        final athleteMean = entry.value['mean'];
        final zScore = groupStd > 0 ? (athleteMean - groupMean) / groupStd : 0;
        entry.value['group_z_score'] = zScore;
        entry.value['performance_ranking'] = _rankPerformance(athleteMean, allValues);
      }
      
      return {
        'athlete_data': athleteData,
        'group_statistics': groupStats,
        'comparison_date': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {'error': 'Karşılaştırma analizi hatası: $e'};
    }
  }
  
  /// Performans sıralaması hesapla
  String _rankPerformance(double value, List<double> referenceValues) {
    final percentile = StatisticsHelper.calculatePercentile(referenceValues, 
      ((referenceValues.where((v) => v <= value).length / referenceValues.length) * 100));
    
    if (percentile >= 90) return 'En İyi %10';
    if (percentile >= 75) return 'En İyi %25';
    if (percentile >= 50) return 'Ortalama Üstü';
    if (percentile >= 25) return 'Ortalama Altı';
    return 'En Düşük %25';
  }
}