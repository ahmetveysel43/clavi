import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/olcum_model.dart';
import '../models/performance_analysis_model.dart';
import '../utils/statistics_helper.dart';
import 'database_service.dart';

class PerformanceAnalysisService {
  final DatabaseService _databaseService = DatabaseService();

  /// Temel performans verilerini sporcu ID'si, ölçüm türü ve değer türüne göre getirir.
  /// Artık hesaplanan analizleri veritabanına kaydeder.
  Future<Map<String, dynamic>> getPerformanceSummary({
    required int sporcuId,
    required String olcumTuru,
    required String degerTuru,
    int? lastNDays,
    DateTime? startDate,
    DateTime? endDate,
    bool forceRecalculate = false, // Yeni parametre: Zorla yeniden hesapla
  }) async {
    try {
      // Önce kayıtlı analizi kontrol et (eğer zorla hesaplama yoksa)
      if (!forceRecalculate) {
        final savedAnalysis = await _getSavedAnalysis(
          sporcuId: sporcuId,
          olcumTuru: olcumTuru,
          degerTuru: degerTuru,
          lastNDays: lastNDays,
          startDate: startDate,
          endDate: endDate,
        );
        
        if (savedAnalysis != null) {
          debugPrint('Kayıtlı analiz bulundu, veritabanından döndürülüyor');
          return _convertAnalysisToMap(savedAnalysis);
        }
      }

      debugPrint('Yeni analiz hesaplanıyor...');
      
      // Temel performans verilerini al
      final performances = await _getPerformanceData(
        sporcuId: sporcuId,
        olcumTuru: olcumTuru,
        degerTuru: degerTuru,
        lastNDays: lastNDays ?? 90,
        startDate: startDate,
        endDate: endDate,
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

      // SWC hesaplaması
      final swc = await _calculateSWCWithPopulationData(
        sporcuId: sporcuId,
        olcumTuru: olcumTuru,
        degerTuru: degerTuru,
      );
       
      // MDC hesaplaması
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

      // Zaman aralığını belirle
      String timeRange = 'Son ${lastNDays ?? 90} Gün';
      if (startDate != null && endDate != null) {
        timeRange = 'Özel Tarih Aralığı';
      }

      // Analiz sonuçlarını hazırla
      final analysisMap = {
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

      // Analizi veritabanına kaydet
      await _saveAnalysisToDatabase(
        sporcuId: sporcuId,
        olcumTuru: olcumTuru,
        degerTuru: degerTuru,
        timeRange: timeRange,
        startDate: startDate,
        endDate: endDate,
        analysisData: analysisMap,
        reliability: reliability,
      );

      return analysisMap;
    } catch (e) {
      debugPrint('Analiz sırasında hata: $e');
      return {'error': 'Analiz sırasında hata: $e'};
    }
  }

  /// Kayıtlı analizi kontrol et ve döndür
  Future<PerformanceAnalysis?> _getSavedAnalysis({
    required int sporcuId,
    required String olcumTuru,
    required String degerTuru,
    int? lastNDays,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final savedAnalysis = await _databaseService.getLatestPerformanceAnalysis(
        sporcuId: sporcuId,
        olcumTuru: olcumTuru,
        degerTuru: degerTuru,
      );

      if (savedAnalysis == null) {
        return null;
      }

      // Analiz çok eski mi kontrol et (24 saatten eski)
      final analysisAge = DateTime.now().difference(savedAnalysis.calculationDate);
      if (analysisAge.inHours > 24) {
        debugPrint('Kayıtlı analiz çok eski (${analysisAge.inHours} saat), yeniden hesaplanacak');
        return null;
      }

      // Zaman aralığı uyuşuyor mu kontrol et
      String currentTimeRange = 'Son ${lastNDays ?? 90} Gün';
      if (startDate != null && endDate != null) {
        currentTimeRange = 'Özel Tarih Aralığı';
      }

      if (savedAnalysis.timeRange != currentTimeRange) {
        debugPrint('Zaman aralığı uyuşmuyor, yeniden hesaplanacak');
        return null;
      }

      // Özel tarih aralığı kontrolü
      if (startDate != null && endDate != null) {
        if (savedAnalysis.startDate != startDate || savedAnalysis.endDate != endDate) {
          debugPrint('Özel tarih aralığı uyuşmuyor, yeniden hesaplanacak');
          return null;
        }
      }

      debugPrint('Uygun kayıtlı analiz bulundu: ${savedAnalysis.id}');
      return savedAnalysis;
    } catch (e) {
      debugPrint('Kayıtlı analiz kontrol hatası: $e');
      return null;
    }
  }

  /// Analizi veritabanına kaydet
  Future<void> _saveAnalysisToDatabase({
    required int sporcuId,
    required String olcumTuru,
    required String degerTuru,
    required String timeRange,
    DateTime? startDate,
    DateTime? endDate,
    required Map<String, dynamic> analysisData,
    required Map<String, dynamic> reliability,
  }) async {
    try {
      final analysis = PerformanceAnalysis(
        sporcuId: sporcuId,
        olcumTuru: olcumTuru,
        degerTuru: degerTuru,
        timeRange: timeRange,
        startDate: startDate,
        endDate: endDate,
        calculationDate: DateTime.now(),
        
        // Temel istatistikler
        mean: analysisData['mean'] ?? 0.0,
        standardDeviation: analysisData['standardDeviation'] ?? 0.0,
        coefficientOfVariation: analysisData['coefficientOfVariation'] ?? 0.0,
        minimum: analysisData['minimum'] ?? 0.0,
        maximum: analysisData['maximum'] ?? 0.0,
        range: analysisData['range'] ?? 0.0,
        median: analysisData['median'] ?? 0.0,
        sampleCount: analysisData['count'] ?? 0,
        q25: analysisData['q25'] ?? 0.0,
        q75: analysisData['q75'] ?? 0.0,
        iqr: analysisData['iqr'] ?? 0.0,
        
        // Gelişmiş analizler
        typicalityIndex: analysisData['typicalityIndex'] ?? 0.0,
        momentum: analysisData['momentum'] ?? 0.0,
        trendSlope: analysisData['trendSlope'] ?? 0.0,
        trendStability: analysisData['trendStability'] ?? 0.0,
        trendRSquared: analysisData['trendRSquared'] ?? 0.0,
        trendStrength: analysisData['trendStrength'] ?? 0.0,
        
        // Güvenilirlik metrikleri
        swc: analysisData['swc'] ?? 0.0,
        mdc: analysisData['mdc'] ?? 0.0,
        testRetestReliability: reliability['test_retest_reliability'] ?? 0.0,
        icc: reliability['icc'] ?? 0.0,
        cvPercent: reliability['cv_percent'] ?? 0.0,
        
        // Performans değerlendirme
        performanceClass: analysisData['performanceClass'] ?? '',
        performanceTrend: analysisData['performanceTrend'] ?? '',
        recentChange: analysisData['recentChange'] ?? 0.0,
        recentChangePercent: analysisData['recentChangePercent'] ?? 0.0,
        outliersCount: analysisData['outliersCount'] ?? 0,
        
        // JSON veriler
        performanceValuesJson: jsonEncode(analysisData['performanceValues'] ?? []),
        datesJson: jsonEncode(analysisData['dates'] ?? []),
        zScoresJson: jsonEncode(analysisData['zScores'] ?? []),
        outliersJson: jsonEncode(analysisData['outliers'] ?? []),
      );

      final id = await _databaseService.savePerformanceAnalysis(analysis);
      debugPrint('Performans analizi kaydedildi: ID: $id');

      // Eski analizleri temizle (90 günden eski)
      await _databaseService.cleanOldPerformanceAnalyses(daysToKeep: 90);
      
    } catch (e) {
      debugPrint('Analiz kaydetme hatası: $e');
      // Hata durumunda devam et, analiz sonucunu döndür
    }
  }

  /// PerformanceAnalysis modelini Map'e çevir
  Map<String, dynamic> _convertAnalysisToMap(PerformanceAnalysis analysis) {
    try {
      return {
        // Temel istatistikler
        'mean': analysis.mean,
        'standardDeviation': analysis.standardDeviation,
        'coefficientOfVariation': analysis.coefficientOfVariation,
        'minimum': analysis.minimum,
        'maximum': analysis.maximum,
        'range': analysis.range,
        'median': analysis.median,
        'count': analysis.sampleCount,
        'q25': analysis.q25,
        'q75': analysis.q75,
        'iqr': analysis.iqr,

        // Gelişmiş analizler
        'typicalityIndex': analysis.typicalityIndex,
        'momentum': analysis.momentum,
        'trendSlope': analysis.trendSlope,
        'trendStability': analysis.trendStability,
        'trendRSquared': analysis.trendRSquared,
        'trendStrength': analysis.trendStrength,
        'zScores': _parseJsonList(analysis.zScoresJson),

        // Güvenilirlik metrikleri
        'swc': analysis.swc,
        'mdc': analysis.mdc,
        'reliability': {
          'test_retest_reliability': analysis.testRetestReliability,
          'icc': analysis.icc,
          'cv_percent': analysis.cvPercent,
          'source': 'Kayıtlı analiz',
        },

        // Performans değerlendirme
        'performanceClass': analysis.performanceClass,
        'performanceTrend': analysis.performanceTrend,
        'recentChange': analysis.recentChange,
        'recentChangePercent': analysis.recentChangePercent,
        'outliers': _parseJsonList(analysis.outliersJson),
        'outliersCount': analysis.outliersCount,

        // Ham veriler
        'performanceValues': _parseJsonList(analysis.performanceValuesJson),
        'dates': _parseJsonStringList(analysis.datesJson),
        'analysisDate': analysis.calculationDate.toIso8601String(),
        
        // Metadata
        'savedAnalysisId': analysis.id,
        'analysisVersion': analysis.analysisVersion,
      };
    } catch (e) {
      debugPrint('Analiz dönüştürme hatası: $e');
      return {'error': 'Kayıtlı analiz dönüştürülemedi'};
    }
  }

  /// JSON string'i double listesine çevir
  List<double> _parseJsonList(String jsonString) {
    try {
      final List<dynamic> parsed = jsonDecode(jsonString);
      return parsed.map((e) => (e as num).toDouble()).toList();
    } catch (e) {
      debugPrint('JSON list parse hatası: $e');
      return [];
    }
  }

  /// JSON string'i string listesine çevir
  List<String> _parseJsonStringList(String jsonString) {
    try {
      final List<dynamic> parsed = jsonDecode(jsonString);
      return parsed.map((e) => e.toString()).toList();
    } catch (e) {
      debugPrint('JSON string list parse hatası: $e');
      return [];
    }
  }

  /// Performans geçmişini getir
  Future<List<Map<String, dynamic>>> getPerformanceHistory({
    required int sporcuId,
    required String olcumTuru,
    required String degerTuru,
    int limit = 10,
  }) async {
    try {
      final analyses = await _databaseService.getAllPerformanceAnalyses(
        sporcuId: sporcuId,
        olcumTuru: olcumTuru,
        degerTuru: degerTuru,
        limit: limit,
      );

      return analyses.map((analysis) => {
        'id': analysis.id,
        'calculation_date': analysis.calculationDate.toIso8601String(),
        'time_range': analysis.timeRange,
        'mean': analysis.mean,
        'trend_slope': analysis.trendSlope,
        'typicality_index': analysis.typicalityIndex,
        'sample_count': analysis.sampleCount,
        'swc': analysis.swc,
        'mdc': analysis.mdc,
        'performance_trend': analysis.performanceTrend,
      }).toList();
    } catch (e) {
      debugPrint('Performans geçmişi getirme hatası: $e');
      return [];
    }
  }

  /// Performans analizini sil
  Future<bool> deletePerformanceAnalysis(int analysisId) async {
    try {
      final result = await _databaseService.deletePerformanceAnalysis(analysisId);
      return result > 0;
    } catch (e) {
      debugPrint('Performans analizi silme hatası: $e');
      return false;
    }
  }

  /// Sporcu için tüm performans analizlerini sil
  Future<bool> deleteAllAthleteAnalyses(int sporcuId) async {
    try {
      final result = await _databaseService.deleteAllPerformanceAnalyses(sporcuId);
      debugPrint('Sporcu $sporcuId için $result analiz silindi');
      return result >= 0;
    } catch (e) {
      debugPrint('Sporcu analizleri silme hatası: $e');
      return false;
    }
  }

  /// Performans analizi istatistikleri
  Future<Map<String, dynamic>> getAnalysisStatistics() async {
    try {
      return await _databaseService.getPerformanceAnalysisStats();
    } catch (e) {
      debugPrint('Analiz istatistikleri getirme hatası: $e');
      return {};
    }
  }

  // Mevcut metodlar (değişiklik yok) ...
  Future<List<Map<String, dynamic>>> _getPerformanceData({
    required int sporcuId,
    required String olcumTuru,
    required String degerTuru,
    int? lastNDays,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final olcumler = await _databaseService.getOlcumlerBySporcuId(sporcuId);

    final filteredOlcumler = olcumler.where((olcum) {
      try {
        final olcumDate = DateTime.parse(olcum.olcumTarihi);
        // Özel tarih aralığı varsa
        if (startDate != null && endDate != null) {
          return olcumDate.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
                 olcumDate.isBefore(endDate.add(const Duration(seconds: 1))) &&
                 olcum.olcumTuru.toLowerCase() == olcumTuru.toLowerCase();
        }
        // Varsayılan son N gün filtresi
        final cutoffDate = DateTime.now().subtract(Duration(days: lastNDays ?? 90));
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

  /// SWC hesaplaması - Düzeltilmiş populasyon temelli metod
  Future<double> _calculateSWCWithPopulationData({
    required int sporcuId,
    required String olcumTuru,
    required String degerTuru,
  }) async {
    try {
      // Önce popülasyon verisi toplamaya çalış
      final populationSWC = await _calculatePopulationBasedSWC(
        sporcuId: sporcuId,
        olcumTuru: olcumTuru,
        degerTuru: degerTuru,
      );
      
      if (populationSWC > 0) {
        debugPrint('Popülasyon temelli SWC hesaplandı: $populationSWC');
        return populationSWC;
      }
      
      // Popülasyon verisi yetersizse grup normlarını kullan
      final groupNormSWC = await _calculateGroupNormSWC(
        olcumTuru: olcumTuru,
        degerTuru: degerTuru,
        referenceSporcuId: sporcuId,
      );
      
      if (groupNormSWC > 0) {
        debugPrint('Grup norm temelli SWC hesaplandı: $groupNormSWC');
        return groupNormSWC;
      }
      
      // Son çare: literatür temelli SWC
      final literatureSWC = await _calculateLiteratureBasedSWC(
        olcumTuru: olcumTuru,
        degerTuru: degerTuru,
        sporcuId: sporcuId,
      );
      
      debugPrint('Literatür temelli SWC hesaplandı: $literatureSWC');
      return literatureSWC;
      
    } catch (e) {
      debugPrint('SWC hesaplama hatası: $e');
      return 0.0;
    }
  }

  /// Gerçek popülasyon verisi ile SWC hesapla
  Future<double> _calculatePopulationBasedSWC({
    required int sporcuId,
    required String olcumTuru,
    required String degerTuru,
  }) async {
    try {
      // Tüm sporcuları al (hedef sporcu hariç)
      final allSporcular = await _databaseService.getAllSporcular();
      final otherSporcular = allSporcular.where((s) => s.id != sporcuId).toList();
      
      if (otherSporcular.length < 8) {
        debugPrint('Popülasyon SWC için yetersiz sporcu sayısı: ${otherSporcular.length}');
        return 0.0;
      }
      
      // Her sporcunun en iyi performansını al (son 6 ay)
      List<double> populationBestValues = [];
      List<double> populationMeanValues = [];
      
      for (final sporcu in otherSporcular) {
        final performances = await _getPerformanceData(
          sporcuId: sporcu.id!,
          olcumTuru: olcumTuru,
          degerTuru: degerTuru,
          lastNDays: 180, // Son 6 ay
        );
        
        if (performances.length >= 3) {
          final values = performances.map((p) => p['value'] as double).toList();
          
          // En iyi performans (test türüne göre max veya min)
          final bestValue = _getBestPerformance(values, olcumTuru, degerTuru);
          populationBestValues.add(bestValue);
          
          // Ortalama performans
          populationMeanValues.add(StatisticsHelper.calculateMean(values));
        }
      }
      
      if (populationBestValues.length >= 8) {
        // Hopkins metodolojisi: %0.2 × between-athlete SD (en iyi performanslar)
        final swcBest = StatisticsHelper.calculateSWCForTestType(
          populationData: populationBestValues,
          testType: olcumTuru,
          athleteLevel: _determineAthleteLevel(sporcuId),
        );
        
        // Ortalama değerlerden de hesapla (alternatif)
        final swcMean = StatisticsHelper.calculateSWCForTestType(
          populationData: populationMeanValues,
          testType: olcumTuru,
          athleteLevel: _determineAthleteLevel(sporcuId),
        );
        
        // İkisinin ortalamasını al (daha konservatif yaklaşım)
        final finalSWC = (swcBest + swcMean) / 2;
        
        debugPrint('Popülasyon SWC - Best: $swcBest, Mean: $swcMean, Final: $finalSWC');
        return finalSWC;
      }
      
      return 0.0;
    } catch (e) {
      debugPrint('Popülasyon SWC hesaplama hatası: $e');
      return 0.0;
    }
  }

  /// Grup norm temelli SWC hesapla (benzer özellikli sporcular)
  Future<double> _calculateGroupNormSWC({
    required String olcumTuru,
    required String degerTuru,
    required int referenceSporcuId,
  }) async {
    try {
      // Referans sporcunun özelliklerini al
      final referenceSporcu = await _databaseService.getSporcu(referenceSporcuId);
      
      // Benzer özellikteki sporcuları bul
      final allSporcular = await _databaseService.getAllSporcular();
      final similarSporcular = allSporcular.where((sporcu) {
        if (sporcu.id == referenceSporcuId) return false;
        
        // Yaş kriteri (±3 yaş)
        final ageDiff = (sporcu.yas - referenceSporcu.yas).abs();
        if (ageDiff > 3) return false;
        
        // Cinsiyet kriteri
        if (sporcu.cinsiyet != referenceSporcu.cinsiyet) return false;
        
        return true;
      }).toList();
      
      if (similarSporcular.length < 5) {
        debugPrint('Grup norm SWC için yetersiz benzer sporcu: ${similarSporcular.length}');
        return 0.0;
      }
      
      // Benzer sporcuların performanslarını topla
      List<double> groupPerformances = [];
      
      for (final sporcu in similarSporcular) {
        final performances = await _getPerformanceData(
          sporcuId: sporcu.id!,
          olcumTuru: olcumTuru,
          degerTuru: degerTuru,
          lastNDays: 365, // Son 1 yıl
        );
        
        if (performances.length >= 2) {
          final values = performances.map((p) => p['value'] as double).toList();
          // Her sporcunun ortalamasını al
          groupPerformances.add(StatisticsHelper.calculateMean(values));
        }
      }
      
      if (groupPerformances.length >= 5) {
       return StatisticsHelper.calculateSWCForTestType(
         populationData: groupPerformances,
         testType: olcumTuru,
         athleteLevel: _determineAthleteLevel(referenceSporcuId),
       );
     }
     
     return 0.0;
   } catch (e) {
     debugPrint('Grup norm SWC hesaplama hatası: $e');
     return 0.0;
   }
 }

 /// Literatür temelli SWC hesapla
 Future<double> _calculateLiteratureBasedSWC({
   required String olcumTuru,
   required String degerTuru,
   required int sporcuId,
 }) async {
   try {
     // Sporcunun kendi verilerinden baseline hesapla
     final performances = await _getPerformanceData(
       sporcuId: sporcuId,
       olcumTuru: olcumTuru,
       degerTuru: degerTuru,
       lastNDays: 365,
     );
     
     if (performances.isEmpty) return 0.0;
     
     final values = performances.map((p) => p['value'] as double).toList();
     final meanValue = StatisticsHelper.calculateMean(values);
     
     // Test türüne göre literatür temelli SWC yüzdeleri
     Map<String, double> literatureSWCPercent = {
       // CMJ (Countermovement Jump)
       'CMJ_YUKSEKLIK': 1.8,     // %1.8 (Hopkins vd., 2009)
       'CMJ_UCUSSURESI': 1.5,
       'CMJ_GUC': 2.1,
       
       // SJ (Squat Jump)
       'SJ_YUKSEKLIK': 2.0,      // %2.0 (Turner vd., 2015)
       'SJ_UCUSSURESI': 1.7,
       'SJ_GUC': 2.3,
       
       // DJ (Drop Jump)
       'DJ_YUKSEKLIK': 2.2,      // %2.2 (Gathercole vd., 2015)
       'DJ_RSI': 6.5,            // RSI daha yüksek varyabilite
       'DJ_TEMASSURESI': 4.1,
       'DJ_UCUSSURESI': 1.9,
       'DJ_GUC': 2.5,
       
       // RJ (Repeated Jump)
       'RJ_YUKSEKLIK': 2.8,      // %2.8 (Claudino vd., 2017)
       'RJ_RSI': 8.2,
       'RJ_RITIM': 3.5,
       'RJ_TEMASSURESI': 5.1,
       'RJ_UCUSSURESI': 2.4,
       'RJ_GUC': 3.1,
       
       // Sprint
       'SPRINT_KAPI1': 0.8,      // %0.8 (Hopkins vd., 2009)
       'SPRINT_KAPI2': 0.7,
       'SPRINT_KAPI3': 0.6,
       'SPRINT_KAPI4': 0.5,
       'SPRINT_KAPI5': 0.4,
       'SPRINT_KAPI6': 0.4,
       'SPRINT_KAPI7': 0.3,
     };
     
     final key = '${olcumTuru.toUpperCase()}_${degerTuru.toUpperCase()}';
     final swcPercent = literatureSWCPercent[key] ?? 2.0; // %2.0 varsayılan
     
     // Sporcu seviyesine göre düzeltme faktörü
     final athleteLevel = _determineAthleteLevel(sporcuId);
     double levelMultiplier = 1.0;
     
     switch (athleteLevel) {
       case 'elite':
         levelMultiplier = 0.7; // Elite sporcularda daha küçük değişimler anlamlı
         break;
       case 'trained':
         levelMultiplier = 1.0; // Standart
         break;
       case 'recreational':
         levelMultiplier = 1.3; // Rekreasyonel sporcularda daha büyük değişimler gerekli
         break;
     }
     
     final literatureSWC = meanValue * (swcPercent / 100) * levelMultiplier;
     
     debugPrint('Literatür SWC - Test: $key, Yüzde: $swcPercent%, Seviye: $athleteLevel, Sonuç: $literatureSWC');
     return literatureSWC;
     
   } catch (e) {
     debugPrint('Literatür SWC hesaplama hatası: $e');
     return 0.0;
   }
 }

 /// En iyi performansı belirle (test türüne göre max veya min)
 double _getBestPerformance(List<double> values, String olcumTuru, String degerTuru) {
   if (values.isEmpty) return 0.0;
   
   // Düşük değerler daha iyi olan metrikler
   final lowerIsBetter = [
     'temassuresi', 'kapi1', 'kapi2', 'kapi3', 'kapi4', 'kapi5', 'kapi6', 'kapi7'
   ];
   
   final isLowerBetter = lowerIsBetter.any((metric) => 
     degerTuru.toLowerCase().contains(metric));
   
   return isLowerBetter ? values.reduce(math.min) : values.reduce(math.max);
 }

 /// Sporcu seviyesini belirle (basit algoritma)
 String _determineAthleteLevel(int sporcuId) {
   // Bu metod daha karmaşık hale getirilebilir
   // Şimdilik basit bir yaklaşım kullanıyoruz
   
   // Sporcu yaşına ve test sayısına göre basit sınıflandırma
   // Gerçek uygulamada daha sofistike kriterler kullanılabilir
   
   return 'trained'; // Varsayılan olarak 'trained' seviye
   
   // Gelecekte eklenebilecek kriterler:
   // - Sporcu yaşı ve deneyimi
   // - Performans seviyeleri
   // - Test sayısı ve düzenliliği
   // - Spor dalı ve rekabet seviyesi
 }

 /// MDC hesaplaması - Düzeltilmiş metod
 Future<double> _calculateMDCFromDatabase({
   required int sporcuId,
   required String olcumTuru,
   required String degerTuru,
 }) async {
   try {
     // Tüm ölçümleri al ve tarihe göre sırala
     final olcumler = await _databaseService.getOlcumlerBySporcuId(sporcuId);
     
     // İlgili test türündeki ölçümleri filtrele
     final filteredOlcumler = olcumler.where((olcum) {
       return olcum.olcumTuru.toLowerCase() == olcumTuru.toLowerCase();
     }).toList();
     
     if (filteredOlcumler.length < 4) {
       debugPrint('MDC hesaplama için yetersiz veri: ${filteredOlcumler.length} ölçüm');
       return 0.0;
     }
     
     // Tarihe göre sırala
     filteredOlcumler.sort((a, b) => a.olcumTarihi.compareTo(b.olcumTarihi));
     
     // Test-retest çiftlerini bul (3 farklı yöntemle)
     List<double> testRetestPairs = [];
     
     // Yöntem 1: Aynı gün içindeki multiple ölçümler
     testRetestPairs.addAll(_findSameDayPairs(filteredOlcumler, degerTuru));
     
     // Yöntem 2: Ardışık günlerdeki ölçümler (1-3 gün arası)
     if (testRetestPairs.length < 4) {
       testRetestPairs.addAll(_findConsecutiveDayPairs(filteredOlcumler, degerTuru));
     }
     
     // Yöntem 3: En yakın ölçümler (maksimum 7 gün arası)
     if (testRetestPairs.length < 4) {
       testRetestPairs.addAll(_findNearestMeasurements(filteredOlcumler, degerTuru));
     }
     
     // Yöntem 4: Son çare - aynı test koşullarındaki ölçümler
     if (testRetestPairs.length < 4) {
       testRetestPairs.addAll(_findSimilarConditionPairs(filteredOlcumler, degerTuru));
     }
     
     debugPrint('MDC hesaplama - Bulunan test-retest çift sayısı: ${testRetestPairs.length ~/ 2}');
     
     if (testRetestPairs.length >= 4) {
       final mdc = StatisticsHelper.calculateMDC(testRetestPairs);
       debugPrint('Hesaplanan MDC: $mdc');
       return mdc;
     }
     
     // Eğer hala yeterli veri yoksa, popülasyon temelli tahmini MDC hesapla
     return _estimateMDCFromPopulation(olcumTuru, degerTuru, filteredOlcumler);
     
   } catch (e) {
     debugPrint('MDC hesaplama hatası: $e');
     return 0.0;
   }
 }

 /// Aynı gün içindeki multiple ölçümleri bul
 List<double> _findSameDayPairs(List<Olcum> olcumler, String degerTuru) {
   List<double> pairs = [];
   Map<String, List<double>> dailyMeasurements = {};
   
   for (final olcum in olcumler) {
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
   
   // Aynı gün içinde 2+ ölçüm olan günleri işle
   for (final measurements in dailyMeasurements.values) {
     if (measurements.length >= 2) {
       // Tüm kombinasyonları test-retest çifti olarak kullan
       for (int i = 0; i < measurements.length - 1; i++) {
         pairs.add(measurements[i]);
         pairs.add(measurements[i + 1]);
       }
     }
   }
   
   return pairs;
 }

 /// Ardışık günlerdeki ölçümleri bul (1-3 gün arası)
 List<double> _findConsecutiveDayPairs(List<Olcum> olcumler, String degerTuru) {
   List<double> pairs = [];
   
   for (int i = 0; i < olcumler.length - 1; i++) {
     try {
       final date1 = DateTime.parse(olcumler[i].olcumTarihi);
       final date2 = DateTime.parse(olcumler[i + 1].olcumTarihi);
       final daysDiff = date2.difference(date1).inDays;
       
       // 1-3 gün arasındaki ölçümler
       if (daysDiff >= 1 && daysDiff <= 3) {
         final deger1 = olcumler[i].degerler.firstWhere(
           (d) => d.degerTuru.toLowerCase() == degerTuru.toLowerCase(),
           orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
         );
         
         final deger2 = olcumler[i + 1].degerler.firstWhere(
           (d) => d.degerTuru.toLowerCase() == degerTuru.toLowerCase(),
           orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
         );
         
         if (deger1.deger > 0 && deger2.deger > 0) {
           pairs.add(deger1.deger);
           pairs.add(deger2.deger);
         }
       }
     } catch (e) {
       continue; // Tarih parse hatası durumunda devam et
     }
   }
   
   return pairs;
 }

 /// En yakın ölçümleri bul (maksimum 7 gün arası)
 List<double> _findNearestMeasurements(List<Olcum> olcumler, String degerTuru) {
   List<double> pairs = [];
   
   for (int i = 0; i < olcumler.length - 1; i++) {
     try {
       final date1 = DateTime.parse(olcumler[i].olcumTarihi);
       final date2 = DateTime.parse(olcumler[i + 1].olcumTarihi);
       final daysDiff = date2.difference(date1).inDays;
       
       // 4-7 gün arasındaki ölçümler (daha önceki yöntemlerle bulunamayanlar)
       if (daysDiff >= 4 && daysDiff <= 7) {
         final deger1 = olcumler[i].degerler.firstWhere(
           (d) => d.degerTuru.toLowerCase() == degerTuru.toLowerCase(),
           orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
         );
         
         final deger2 = olcumler[i + 1].degerler.firstWhere(
           (d) => d.degerTuru.toLowerCase() == degerTuru.toLowerCase(),
           orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
         );
         
         if (deger1.deger > 0 && deger2.deger > 0) {
           pairs.add(deger1.deger);
           pairs.add(deger2.deger);
         }
       }
     } catch (e) {
       continue;
     }
   }
   
   return pairs;
 }

 /// Benzer test koşullarındaki ölçümleri bul
 List<double> _findSimilarConditionPairs(List<Olcum> olcumler, String degerTuru) {
   List<double> pairs = [];
   
   // Test ID'si aynı olan ölçümleri grupla (aynı test session'ı)
   Map<int?, List<Olcum>> testGroups = {};
   
   for (final olcum in olcumler) {
     testGroups.putIfAbsent(olcum.testId, () => []);
     testGroups[olcum.testId]!.add(olcum);
   }
   
   // Her test grubu içindeki ölçümleri çiftler halinde kullan
   for (final group in testGroups.values) {
     if (group.length >= 2) {
       for (int i = 0; i < group.length - 1; i++) {
         final deger1 = group[i].degerler.firstWhere(
           (d) => d.degerTuru.toLowerCase() == degerTuru.toLowerCase(),
           orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
         );
         
         final deger2 = group[i + 1].degerler.firstWhere(
           (d) => d.degerTuru.toLowerCase() == degerTuru.toLowerCase(),
           orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
         );
         
         if (deger1.deger > 0 && deger2.deger > 0) {
           pairs.add(deger1.deger);
           pairs.add(deger2.deger);
         }
       }
     }
   }
   
   return pairs;
 }

 /// Popülasyon temelli MDC tahmini
 Future<double> _estimateMDCFromPopulation(String olcumTuru, String degerTuru, List<Olcum> athleteData) async {
   try {
     // Test türüne göre literatür temelli MDC değerleri (yüzde olarak)
     Map<String, double> literatureMDCPercent = {
       'CMJ_YUKSEKLIK': 5.5,     // %5.5 tipik MDC
       'CMJ_UCUSSURESI': 4.8,
       'CMJ_GUC': 8.2,
       'SJ_YUKSEKLIK': 6.1,
       'SJ_UCUSSURESI': 5.2,
       'SJ_GUC': 9.1,
       'DJ_YUKSEKLIK': 7.3,
       'DJ_RSI': 12.5,
       'RJ_YUKSEKLIK': 8.9,
       'RJ_RSI': 15.2,
       'SPRINT_KAPI1': 2.1,
       'SPRINT_KAPI2': 1.8,
       'SPRINT_KAPI3': 1.6,
       'SPRINT_KAPI4': 1.5,
       'SPRINT_KAPI5': 1.4,
       'SPRINT_KAPI6': 1.3,
       'SPRINT_KAPI7': 1.2,
     };
     
     final key = '${olcumTuru.toUpperCase()}_${degerTuru.toUpperCase()}';
     final mdcPercent = literatureMDCPercent[key] ?? 7.0; // %7 varsayılan
     
     // Sporcunun kendi verilerinden ortalama hesapla
     List<double> values = [];
     for (final olcum in athleteData) {
       final deger = olcum.degerler.firstWhere(
         (d) => d.degerTuru.toLowerCase() == degerTuru.toLowerCase(),
         orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
       );
       if (deger.deger > 0) {
         values.add(deger.deger);
       }
     }
     
     if (values.isNotEmpty) {
       final mean = StatisticsHelper.calculateMean(values);
       final estimatedMDC = mean * (mdcPercent / 100);
       
       debugPrint('Tahmini MDC hesaplandı: $estimatedMDC (Ortalama: $mean, %$mdcPercent)');
       return estimatedMDC;
     }
     
     return 0.0;
   } catch (e) {
     debugPrint('Tahmini MDC hesaplama hatası: $e');
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

 /// Sporcu karşılaştırma analizi
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
     for (final data in athleteData.values) {
       final values = List<double>.from(data['performanceValues']);
       allValues.addAll(values);
     }

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
   final percentile = StatisticsHelper.calculatePercentile(
       referenceValues,
       ((referenceValues.where((v) => v <= value).length / referenceValues.length) * 100));

   if (percentile >= 90) return 'En İyi %10';
   if (percentile >= 75) return 'En İyi %25';
   if (percentile >= 50) return 'Ortalama Üstü';
   if (percentile >= 25) return 'Ortalama Altı';
   return 'En Düşük %25';
 }
}