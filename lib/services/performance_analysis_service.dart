import 'package:flutter/foundation.dart';
import 'dart:math' as math; // Math kütüphanesi eklendi
import '../models/olcum_model.dart'; ////
import '../utils/statistics_helper.dart'; //
import 'database_service.dart'; //

class PerformanceAnalysisService {
  final DatabaseService _databaseService = DatabaseService();
  
  /// Bir sporcunun belirli bir ölçüm türü ve değeri için zaman içindeki performans analizini yapar
  Future<Map<String, dynamic>> analyzePerformanceOverTime({
    required int sporcuId,
    required String olcumTuru,
    required String degerTuru,
    String? baslangicTarihi,
    String? bitisTarihi,
  }) async {
    try {
      // Sporcu ölçümlerini al
      final olcumler = await _databaseService.getOlcumlerBySporcuId(sporcuId); //
      
      // Ölçüm türüne göre filtrele
      final filteredOlcumler = olcumler.where((o) => 
        o.olcumTuru.toUpperCase() == olcumTuru.toUpperCase()).toList(); //
      
      if (filteredOlcumler.isEmpty) {
        return {'error': 'Bu ölçüm türünde veri bulunamadı'}; //
      }
      
      // Ölçümleri tarihe göre sırala (eskiden yeniye)
      filteredOlcumler.sort((a, b) => a.olcumTarihi.compareTo(b.olcumTarihi)); //
      
      // Zaman aralığına göre filtrele
      if (baslangicTarihi != null) {
        filteredOlcumler.removeWhere((o) => o.olcumTarihi.compareTo(baslangicTarihi) < 0); //
      }
      if (bitisTarihi != null) {
        filteredOlcumler.removeWhere((o) => o.olcumTarihi.compareTo(bitisTarihi) > 0); //
      }
      
      if (filteredOlcumler.isEmpty) {
        return {'error': 'Belirtilen tarih aralığında veri bulunamadı'}; //
      }
      
      // İstenen değer türüne göre değerleri topla
      List<double> performanceValues = [];
      List<String> dates = [];
      
      for (var olcum in filteredOlcumler) {
        final deger = olcum.degerler.firstWhere(
          (d) => d.degerTuru.toUpperCase() == degerTuru.toUpperCase(), //
          orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0), //
        );
        
        if (deger.deger != 0) { //
          performanceValues.add(deger.deger); //
          dates.add(olcum.olcumTarihi); //
        }
      }
      
      if (performanceValues.isEmpty) {
        return {'error': 'Bu değer türünde veri bulunamadı'}; //
      }
      
      // Minimum, maksimum ve ilgili tarihler
      final minValue = performanceValues.reduce((a, b) => a < b ? a : b); //
      final maxValue = performanceValues.reduce((a, b) => a > b ? a : b); //
      final minIndex = performanceValues.indexOf(minValue); //
      final maxIndex = performanceValues.indexOf(maxValue); //
      
      // İstatistiksel analizler
      final mean = performanceValues.reduce((a, b) => a + b) / performanceValues.length; //
      final stdDev = StatisticsHelper.calculateStandardDeviation(performanceValues); //
      final cvPercentage = (stdDev / mean) * 100; // Varyasyon katsayısı //
      
      // Tipiklik indeksi (tutarlılık ölçüsü)
      final typicalityIndex = StatisticsHelper.calculateTypicalityIndex(performanceValues); //
      
      // Trend analizi
      final trendAnalysis = StatisticsHelper.analyzePerformanceTrend(performanceValues); //
      
      // Son durumda performans momentumu (son 3 ölçüm)
      double momentum = 0;
      if (performanceValues.length >= 6) {
        momentum = StatisticsHelper.calculateMomentum(performanceValues); //
      }
      
      // SWC (En Küçük Değerli Değişim) hesaplaması
      final swc = StatisticsHelper.calculateSWC(performanceValues); //
      
      // Başlangıç-bitiş değişimi
      final startValue = performanceValues.first; //
      final endValue = performanceValues.last; //
      final totalChange = endValue - startValue; //
      final percentChange = (totalChange / startValue) * 100; //
      
      // Analizin kendisi
      // final now = DateTime.now().toIso8601String(); // Bu satır kullanılmadığı için kaldırıldı.
      final analysis = {
        'performanceValues': performanceValues, //
        'dates': dates, //
        'mean': mean, //
        'stdDev': stdDev, //
        'cvPercentage': cvPercentage, //
        'typicalityIndex': typicalityIndex, //
        'trend': trendAnalysis['trend'], //
        'stability': trendAnalysis['stability'], //
        'momentum': momentum, //
        'swc': swc, //
        'minValue': minValue, //
        'maxValue': maxValue, //
        'minDate': dates[minIndex], //
        'maxDate': dates[maxIndex], //
        'startValue': startValue, //
        'endValue': endValue, //
        'totalChange': totalChange, //
        'percentChange': percentChange, //
        'firstDate': dates.first, //
        'lastDate': dates.last, //
        'numberOfSamples': performanceValues.length, //
      };
      
      // Analiz sonuçlarını veritabanına kaydet
      await _databaseService.savePerformansAnaliz(
        sporcuId: sporcuId, //
        olcumTuru: olcumTuru, //
        degerTuru: degerTuru, //
        baslangicTarihi: dates.first, //
        bitisTarihi: dates.last, //
        ortalama: mean, //
        stdDev: stdDev, //
        cvYuzde: cvPercentage, //
        trendSlope: trendAnalysis['trend'] as double, //
        momentum: momentum, //
        typicalityIndex: typicalityIndex, //
      );
      
      return analysis;
    } catch (e) {
      debugPrint('Performans analizi hatası: $e'); //
      return {'error': 'Analiz sırasında bir hata oluştu: $e'}; //
    }
  }
  
  /// İki ölçüm arasındaki değişimin anlamlı olup olmadığını değerlendirir
  Future<Map<String, dynamic>> evaluatePerformanceChange({
    required double preValue,
    required double postValue,
    required String olcumTuru,
    required String degerTuru,
  }) async {
    try {
      // Test güvenilirlik verilerini al
      final guvenilirlik = await _databaseService.getTestGuvenilirlik(
        olcumTuru: olcumTuru, //
        degerTuru: degerTuru, //
      );
      
      // Değişim miktarı
      final change = postValue - preValue; //
      final percentChange = (change / preValue) * 100; //
      
      // Sonuç
      Map<String, dynamic> result = {
        'preValue': preValue, //
        'postValue': postValue, //
        'absoluteChange': change, //
        'percentChange': percentChange, //
      };
      
      // Eğer güvenilirlik verileri mevcutsa anlamlılık değerlendirmesi yap
      if (guvenilirlik != null) {
        final sem = guvenilirlik['TestRetestSEM'] as double?; //
        final mdc95 = guvenilirlik['MDC95'] as double?; //
        final swc = guvenilirlik['SWC'] as double?; //
        
        if (sem != null) {
          final rci = StatisticsHelper.calculateRCI(preValue, postValue, sem); //
          result['rci'] = rci; //
          result['isReliableChange'] = rci.abs() > 1.96; // %95 güven aralığı //
        }
        
        if (mdc95 != null) {
          result['mdc95'] = mdc95; //
          result['exceedsMDC'] = change.abs() > mdc95; //
        }
        
        if (swc != null) {
          result['swc'] = swc; //
          result['exceedsSWC'] = change.abs() > swc; //
        }
        
        // Genel değerlendirme
        result['isSignificantChange'] = 
          (result['exceedsMDC'] as bool? ?? false) || 
          (result['isReliableChange'] as bool? ?? false); //
        
        result['isPracticallyMeaningful'] = 
          (result['exceedsSWC'] as bool? ?? false); //
      }
      
      return result;
    } catch (e) {
      debugPrint('Performans değişimi değerlendirme hatası: $e'); //
      return {'error': 'Değerlendirme sırasında bir hata oluştu: $e'}; //
    }
  }
  
  /// Test güvenilirlik verilerini günceller (test-retest verileri ile)
  Future<bool> updateTestReliabilityData({
    required String olcumTuru,
    required String degerTuru,
    required List<double> testRetestData,
    double confidenceLevel = 0.95,
    String swcMethod = 'cohen',
    double swcCoefficient = 0.2,
  }) async {
    try {
      if (testRetestData.length < 4) {
        return false; // Yetersiz veri
      }
      
      // MDC hesapla
      final mdc = StatisticsHelper.calculateMDC(
        testRetestData, //
        confidenceLevel: confidenceLevel //
      );
      
      // Test-retest farkları
      List<double> differences = [];
      for (int i = 0; i < testRetestData.length; i += 2) {
        differences.add(testRetestData[i] - testRetestData[i + 1]); //
      }
      
      // SEM hesapla
      final stdDev = StatisticsHelper.calculateStandardDeviation(differences); //
      final sem = stdDev / math.sqrt(2); //
      
      // SWC hesapla
      final List<double> uniqueValues = [];
      for (int i = 0; i < testRetestData.length; i += 2) {
        uniqueValues.add(testRetestData[i]); //
      }
      
      final swc = StatisticsHelper.calculateSWC(
        uniqueValues, //
        method: swcMethod, //
        coefficient: swcCoefficient, //
      );
      
      // Veritabanına kaydet
      await _databaseService.saveTestGuvenilirlik(
        olcumTuru: olcumTuru, //
        degerTuru: degerTuru, //
        testRetestSEM: sem, //
        mdc95: mdc, //
        swc: swc, //
      );
      
      return true;
    } catch (e) {
      debugPrint('Test güvenilirlik verisi güncellenirken hata: $e'); //
      return false;
    }
  }
  
  /// Sporcunun dönemsel performans özeti
  Future<Map<String, dynamic>> getPerformanceSummary({
    required int sporcuId,
    required String olcumTuru,
    required String degerTuru,
    int lastNDays = 90,
  }) async {
    try {
      // Son analizi veritabanından çekmeyi dene
      final cachedAnalysis = await _databaseService.getPerformansAnaliz(
        sporcuId: sporcuId, //
        olcumTuru: olcumTuru, //
        degerTuru: degerTuru, //
      );
      
      // Eğer önbellekteki analiz çok eskiyse (>7 gün) yeniden hesapla
      if (cachedAnalysis != null) {
        final lastAnalysisDate = DateTime.parse(cachedAnalysis['SonAnalizTarihi'] as String); //
        final now = DateTime.now();
        final difference = now.difference(lastAnalysisDate).inDays; //
        
        if (difference <= 7) {
          // Önbelleği kullan
          return cachedAnalysis; //
        }
      }
      
      // Analizi yeniden hesapla
      final baslangicTarihi = DateTime.now().subtract(Duration(days: lastNDays)).toIso8601String(); //
      
      return await analyzePerformanceOverTime(
        sporcuId: sporcuId, //
        olcumTuru: olcumTuru, //
        degerTuru: degerTuru, //
        baslangicTarihi: baslangicTarihi, //
      );
    } catch (e) {
      debugPrint('Performans özeti alınırken hata: $e'); //
      return {'error': 'Performans özeti alınırken bir hata oluştu: $e'}; //
    }
  }
}