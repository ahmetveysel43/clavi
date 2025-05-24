import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/sporcu_model.dart';
import '../models/olcum_model.dart';
import '../models/performance_analysis_model.dart'; // YENİ EKLENEN
import '../services/database_service.dart';
import '../widgets/pdf_action_widget.dart'; // YENİ EKLENEN

class DikeyProfilScreen extends StatefulWidget {
  const DikeyProfilScreen({super.key});

  @override
  State<DikeyProfilScreen> createState() => _DikeyProfilScreenState();
}

class _DikeyProfilScreenState extends State<DikeyProfilScreen> {
  final DatabaseService _databaseService = DatabaseService();
  Sporcu? _secilenSporcu;
  List<Sporcu> _sporcular = [];
  bool _isLoading = true;
  bool _isSaving = false; // YENİ EKLENEN - Kayıt durumu
  List<Olcum> _olcumler = [];
  List<Olcum> _tumOlcumler = [];
  List<bool> _seciliOlcumler = [];
  List<Olcum> _hesaplamayaGirecekOlcumler = [];
  List<double> _jumpHeights = [];
  final List<double> _additionalMasses = [0, 20, 40, 60, 80];
  List<double> _forces = [];
  List<double> _velocities = [];
  PerformanceAnalysis? _savedAnalysis; // YENİ EKLENEN - Kaydedilen analiz

  // Dikey profil sonuçları
  double _bodyMass = 0.0;
  double _legLength = 0.0;
  double _sittingHeight = 0.0;
  double _pushOffDistance = 0.0;
  double _f0PerKg = 0.0;
  double _v0PerKg = 0.0;
  double _pmaxPerKg = 0.0;
  double _sfvPerKg = 0.0;
  double _sfvOptPerKg = 0.0;
  double _sfvOpt30PerKg = 0.0;
  double _fvimb = 0.0;
  double _rSquared = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSporcular();
  }

  // ========== VERİTABANI KAYIT İŞLEMLERİ ==========
  
  /// Dikey profil analizini veritabanına kaydet
  Future<void> _saveAnalysisToDatabase() async {
    if (_secilenSporcu == null || _hesaplamayaGirecekOlcumler.isEmpty) {
      _showSnackBar('Kaydedilecek geçerli analiz verisi yok', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Performans analizi objesi oluştur
      final analysis = PerformanceAnalysis(
        sporcuId: _secilenSporcu!.id!,
        olcumTuru: 'DikeyProfil',
        degerTuru: 'KuvvetHizAnalizi',
        timeRange: 'Seçili Ölçümler',
        calculationDate: DateTime.now(),
        
        // Temel istatistikler (dikey profil için adapte edilmiş)
        mean: _jumpHeights.isNotEmpty ? _jumpHeights.reduce((a, b) => a + b) / _jumpHeights.length : 0.0,
        standardDeviation: _calculateStandardDeviation(_jumpHeights),
        coefficientOfVariation: _calculateCV(_jumpHeights),
        minimum: _jumpHeights.isNotEmpty ? _jumpHeights.reduce(math.min) : 0.0,
        maximum: _jumpHeights.isNotEmpty ? _jumpHeights.reduce(math.max) : 0.0,
        range: _jumpHeights.isNotEmpty ? (_jumpHeights.reduce(math.max) - _jumpHeights.reduce(math.min)) : 0.0,
        median: _calculateMedian(_jumpHeights),
        sampleCount: _jumpHeights.length,
        q25: _calculatePercentile(_jumpHeights, 25),
        q75: _calculatePercentile(_jumpHeights, 75),
        iqr: _calculatePercentile(_jumpHeights, 75) - _calculatePercentile(_jumpHeights, 25),
        
        // Dikey profil spesifik değerler
        typicalityIndex: _rSquared * 100, // R² değerini tipiklik indeksi olarak kullan
        momentum: _calculateMomentum(),
        trendSlope: _sfvPerKg,
        trendStability: _rSquared,
        trendRSquared: _rSquared,
        trendStrength: _calculateTrendStrength(),
        
        // Güvenilirlik metrikleri (dikey profil için adapte)
        swc: _calculateSWC(),
        mdc: _calculateMDC(),
        testRetestReliability: _rSquared,
        icc: _rSquared,
        cvPercent: _calculateCV(_jumpHeights),
        
        // Performans değerlendirme
        performanceClass: _getPerformanceClass(),
        performanceTrend: _getPerformanceTrend(),
        recentChange: _calculateRecentChange(),
        recentChangePercent: _calculateRecentChangePercent(),
        outliersCount: _calculateOutliersCount(),
        
        // JSON veriler
        performanceValuesJson: jsonEncode(_jumpHeights),
        datesJson: jsonEncode(_hesaplamayaGirecekOlcumler.map((o) => o.olcumTarihi).toList()),
        zScoresJson: jsonEncode(_calculateZScores(_jumpHeights)),
        outliersJson: jsonEncode(_identifyOutliers(_jumpHeights)),
        
        // Dikey profil spesifik ek veriler
        additionalData: {
          'dikeyProfil': {
            'bodyMass': _bodyMass,
            'legLength': _legLength,
            'sittingHeight': _sittingHeight,
            'pushOffDistance': _pushOffDistance,
            'f0PerKg': _f0PerKg,
            'v0PerKg': _v0PerKg,
            'pmaxPerKg': _pmaxPerKg,
            'sfvPerKg': _sfvPerKg,
            'sfvOptPerKg': _sfvOptPerKg,
            'sfvOpt30PerKg': _sfvOpt30PerKg,
            'fvimb': _fvimb,
            'profileType': _getProfileType(),
            'interpretation': _getProfileInterpretation(),
            'recommendations': _getRecommendations(),
            'forces': _forces,
            'velocities': _velocities,
            'additionalMasses': _additionalMasses,
            'selectedMeasurements': _hesaplamayaGirecekOlcumler.map((o) => {
              'id': o.id,
              'type': o.olcumTuru,
              'order': o.olcumSirasi,
              'testId': o.testId,
              'date': o.olcumTarihi,
              'height': _getHeightFromOlcum(o),
            }).toList(),
          }
        },
      );

      // Veritabanına kaydet
      final analysisId = await _databaseService.savePerformanceAnalysis(analysis);
      _savedAnalysis = analysis.copyWith(id: analysisId);
      
      _showSnackBar(
        'Dikey profil analizi başarıyla veritabanına kaydedildi (ID: $analysisId)', 
        isError: false
      );

      debugPrint('DikeyProfil analizi kaydedildi: ID=$analysisId, Sporcu=${_secilenSporcu!.ad}');
      
    } catch (e) {
      debugPrint('DikeyProfil analizi kaydetme hatası: $e');
      _showSnackBar('Analiz kaydetme hatası: $e', isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // ========== İSTATİSTİK HESAPLAMA HELPER METODLARI ==========
  
  double _calculateStandardDeviation(List<double> values) {
    if (values.isEmpty) return 0.0;
    double mean = values.reduce((a, b) => a + b) / values.length;
    double sumSquaredDiffs = values.fold(0.0, (sum, value) => sum + math.pow(value - mean, 2));
    return math.sqrt(sumSquaredDiffs / values.length);
  }
  
  double _calculateCV(List<double> values) {
    if (values.isEmpty) return 0.0;
    double mean = values.reduce((a, b) => a + b) / values.length;
    double stdDev = _calculateStandardDeviation(values);
    return mean != 0 ? (stdDev / mean) * 100 : 0.0;
  }
  
  double _calculateMedian(List<double> values) {
    if (values.isEmpty) return 0.0;
    List<double> sorted = List.from(values)..sort();
    int middle = sorted.length ~/ 2;
    if (sorted.length % 2 == 0) {
      return (sorted[middle - 1] + sorted[middle]) / 2;
    } else {
      return sorted[middle];
    }
  }
  
  double _calculatePercentile(List<double> values, int percentile) {
    if (values.isEmpty) return 0.0;
    List<double> sorted = List.from(values)..sort();
    double index = (percentile / 100) * (sorted.length - 1);
    int lowerIndex = index.floor();
    int upperIndex = index.ceil();
    
    if (lowerIndex == upperIndex) {
      return sorted[lowerIndex];
    } else {
      double weight = index - lowerIndex;
      return sorted[lowerIndex] * (1 - weight) + sorted[upperIndex] * weight;
    }
  }
  
  double _calculateMomentum() {
    // Son 3 ölçümün trend yönünü hesapla
    if (_jumpHeights.length < 3) return 0.0;
    
    List<double> recent = _jumpHeights.take(3).toList();
    double firstHalf = recent.take(recent.length ~/ 2).reduce((a, b) => a + b) / (recent.length ~/ 2);
    double secondHalf = recent.skip(recent.length ~/ 2).reduce((a, b) => a + b) / (recent.length - recent.length ~/ 2);
    
    return ((secondHalf - firstHalf) / firstHalf) * 100;
  }
  
  double _calculateTrendStrength() {
    return _rSquared > 0.8 ? 1.0 : _rSquared > 0.6 ? 0.5 : 0.0;
  }
  
  double _calculateSWC() {
    // Smallest Worthwhile Change - 0.2 x SD olarak hesapla
    return _calculateStandardDeviation(_jumpHeights) * 0.2;
  }
  
  double _calculateMDC() {
    // Minimal Detectable Change - 1.96 x SEM olarak hesapla
    double sem = _calculateStandardDeviation(_jumpHeights) / math.sqrt(_jumpHeights.length);
    return 1.96 * sem;
  }
  
  String _getPerformanceClass() {
    if (_fvimb.isNaN) return 'Hesaplanamadı';
    
    if (_pmaxPerKg > 50) return 'Mükemmel';
    if (_pmaxPerKg > 40) return 'İyi';
    if (_pmaxPerKg > 30) return 'Orta';
    return 'Düşük';
  }
  
  String _getPerformanceTrend() {
    if (_jumpHeights.length < 2) return 'Belirsiz';
    
    double firstValue = _jumpHeights.first;
    double lastValue = _jumpHeights.last;
    double change = ((lastValue - firstValue) / firstValue) * 100;
    
    if (change > 5) return 'Yükseliş';
    if (change < -5) return 'Düşüş';
    return 'Stabil';
  }
  
  double _calculateRecentChange() {
    if (_jumpHeights.length < 2) return 0.0;
    return _jumpHeights.last - _jumpHeights.first;
  }
  
  double _calculateRecentChangePercent() {
    if (_jumpHeights.length < 2 || _jumpHeights.first == 0) return 0.0;
    return ((_jumpHeights.last - _jumpHeights.first) / _jumpHeights.first) * 100;
  }
  
  int _calculateOutliersCount() {
    List<double> outliers = _identifyOutliers(_jumpHeights);
    return outliers.length;
  }
  
  List<double> _calculateZScores(List<double> values) {
    if (values.isEmpty) return [];
    double mean = values.reduce((a, b) => a + b) / values.length;
    double stdDev = _calculateStandardDeviation(values);
    if (stdDev == 0) return List.filled(values.length, 0.0);
    return values.map((value) => (value - mean) / stdDev).toList();
  }
  
  List<double> _identifyOutliers(List<double> values) {
    if (values.length < 4) return [];
    
    double q1 = _calculatePercentile(values, 25);
    double q3 = _calculatePercentile(values, 75);
    double iqr = q3 - q1;
    double lowerBound = q1 - 1.5 * iqr;
    double upperBound = q3 + 1.5 * iqr;
    
    return values.where((value) => value < lowerBound || value > upperBound).toList();
  }

  // ========== PDF VERİ HAZIRLAMA ==========
  
  Map<String, dynamic> get _pdfAnalysisData {
    return {
      // Temel bilgiler
      'bodyMass': _bodyMass,
      'legLength': _legLength,
      'sittingHeight': _sittingHeight,
      'pushOffDistance': _pushOffDistance,
      
      // Profil sonuçları
      'f0PerKg': _f0PerKg,
      'v0PerKg': _v0PerKg,
      'pmaxPerKg': _pmaxPerKg,
      'sfvPerKg': _sfvPerKg,
      'sfvOptPerKg': _sfvOptPerKg,
      'sfvOpt30PerKg': _sfvOpt30PerKg,
      'fvimb': _fvimb,
      'rSquared': _rSquared,
      
      // Ham veriler
      'jumpHeights': _jumpHeights,
      'additionalMasses': _additionalMasses,
      'forces': _forces,
      'velocities': _velocities,
      
      // İstatistikler
      'mean': _jumpHeights.isNotEmpty ? _jumpHeights.reduce((a, b) => a + b) / _jumpHeights.length : 0.0,
      'standardDeviation': _calculateStandardDeviation(_jumpHeights),
      'coefficientOfVariation': _calculateCV(_jumpHeights),
      'minimum': _jumpHeights.isNotEmpty ? _jumpHeights.reduce(math.min) : 0.0,
      'maximum': _jumpHeights.isNotEmpty ? _jumpHeights.reduce(math.max) : 0.0,
      'median': _calculateMedian(_jumpHeights),
      'sampleCount': _jumpHeights.length,
      
      // Ölçüm verileri
      'selectedMeasurements': _hesaplamayaGirecekOlcumler.map((olcum) => {
        'type': olcum.olcumTuru,
        'order': olcum.olcumSirasi,
        'testId': olcum.testId,
        'date': olcum.olcumTarihi,
        'height': _getHeightFromOlcum(olcum),
      }).toList(),
      
      // Profil yorumlama
      'interpretation': _getProfileInterpretation(),
      'profileType': _getProfileType(),
      'recommendations': _getRecommendations(),
      'performanceClass': _getPerformanceClass(),
      
      // Grafik verileri
      'chartData': {
        'actualProfile': _forces.asMap().entries.map((entry) => {
          'x': _velocities[entry.key],
          'y': entry.value,
        }).toList(),
        'optimalProfile90': _getOptimalProfile90Data(),
        'optimalProfile30': _getOptimalProfile30Data(),
      },
      
      // Metadata
      'calculationDate': DateTime.now().toIso8601String(),
      'measurementCount': _hesaplamayaGirecekOlcumler.length,
      'analysisType': 'Dikey Kuvvet-Hız Profili',
      'savedAnalysisId': _savedAnalysis?.id,
    };
  }

  PDFReportConfig? get _pdfConfig {
    if (_secilenSporcu == null || _hesaplamayaGirecekOlcumler.isEmpty) {
      return null;
    }
    
    return PDFReportConfig.performance(
      sporcu: _secilenSporcu!,
      olcumTuru: 'DikeyProfil',
      degerTuru: 'KuvvetHizAnalizi',
      analysisData: _pdfAnalysisData,
      additionalNotes: 'Dikey Kuvvet-Hız Profili analizi raporu.\n\n'
          'Analiz Detayları:\n'
          '• ${_hesaplamayaGirecekOlcumler.length} adet ölçüm kullanıldı\n'
          '• Profil Tipi: ${_getProfileType()}\n'
          '• FVimb (Profil Dengesizliği): ${_fvimb.toStringAsFixed(1)}%\n'
          '• R² (Güvenilirlik): ${_rSquared.toStringAsFixed(3)}\n'
          '• Maksimal Güç: ${_pmaxPerKg.toStringAsFixed(1)} W/kg\n'
          '• Performans Sınıfı: ${_getPerformanceClass()}\n\n'
          'Bu rapor ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} tarihinde oluşturulmuştur.',
      includeCharts: true,
      showPrintButton: true,
    );
  }

  // ========== HELPER METODLAR ==========
  
  double _getHeightFromOlcum(Olcum olcum) {
    try {
      return olcum.degerler
          .firstWhere((d) => d.degerTuru == 'yukseklik')
          .deger;
    } catch (e) {
      return 0.0;
    }
  }
  
  String _getProfileType() {
    if (_fvimb.isNaN) return "Hesaplanamadı";
    
    if (_fvimb < -15) {
      return "Kuvvet Yönelimli";
    } else if (_fvimb > 15) {
      return "Hız Yönelimli"; 
    } else {
      return "Dengeli Profil";
    }
  }
  
  List<String> _getRecommendations() {
    List<String> recommendations = [];
    
    if (_fvimb.isNaN) {
      recommendations.add("Yeterli veri bulunamadı. Daha fazla ölçüm yapın.");
      return recommendations;
    }
    
    if (_fvimb < -15) {
      recommendations.addAll([
        "Pliometrik sıçrama antrenmanlarına odaklanın",
        "Hızlı tekrarlı egzersizler yapın", 
        "Sprint antrenmanları ekleyin",
        "Reaktif kuvvet geliştirici çalışmalar yapın"
      ]);
    } else if (_fvimb > 15) {
      recommendations.addAll([
        "Maksimal kuvvet antrenmanlarına ağırlık verin",
        "Squat, deadlift gibi temel egzersizleri arttırın",
        "Ağır yüklerle yavaş hareketler yapın",
        "İzometrik kuvvet çalışmaları ekleyin"
      ]);
    } else {
      recommendations.addAll([
        "Mevcut dengeli profilinizi koruyun",
        "Hem kuvvet hem hız antrenmanlarını eşit oranda yapın",
        "Periyodizasyon uygulayarak varyasyon sağlayın",
        "Spor dalınıza özel antrenman ağırlığı verin"
      ]);
    }
    
    if (_rSquared < 0.7) {
      recommendations.add("Ölçüm tutarlılığını artırmak için standart protokol kullanın");
    }
    
    return recommendations;
  }
  
  List<Map<String, double>> _getOptimalProfile90Data() {
    double f0Opt90 = 0;
    double v0Opt90 = 0;
    
    if (_sfvOptPerKg.isFinite && _pmaxPerKg.isFinite && 
        !_sfvOptPerKg.isNaN && !_pmaxPerKg.isNaN && 
        _pmaxPerKg > 0 && _sfvOptPerKg != 0) {
      double value = -_sfvOptPerKg * _pmaxPerKg;
      if (value > 0) {
        f0Opt90 = 2 * math.sqrt(value);
        if (f0Opt90 > 0) {
          v0Opt90 = (4 * _pmaxPerKg) / f0Opt90;
        }
      }
    }
    
    return [
      {'x': 0.0, 'y': f0Opt90},
      {'x': v0Opt90, 'y': 0.0},
    ];
  }
  
  List<Map<String, double>> _getOptimalProfile30Data() {
    double f0Opt30 = 0;
    double v0Opt30 = 0;
    
    if (_sfvOpt30PerKg.isFinite && _pmaxPerKg.isFinite && 
        !_sfvOpt30PerKg.isNaN && !_pmaxPerKg.isNaN && 
        _pmaxPerKg > 0 && _sfvOpt30PerKg != 0) {
      double value = -_sfvOpt30PerKg * _pmaxPerKg;
      if (value > 0) {
        f0Opt30 = 2 * math.sqrt(value);
        if (f0Opt30 > 0) {
          v0Opt30 = (4 * _pmaxPerKg) / f0Opt30;
        }
      }
    }
    
    return [
      {'x': 0.0, 'y': f0Opt30},
      {'x': v0Opt30, 'y': 0.0},
    ];
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: Duration(seconds: isError ? 4 : 3),
        ),
      );
    }
  }

  // ========== MEVCUT METODLAR (AYNI KALIYOR) ==========

  Future<void> _loadSporcular() async {
    try {
      _sporcular = await _databaseService.getAllSporcular();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sporcular yüklenirken hata: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadSporcuOlcumleri(int sporcuId) async {
    setState(() => _isLoading = true);
    try {
      _secilenSporcu = await _databaseService.getSporcu(sporcuId);
      if (_secilenSporcu == null) {
        throw Exception('Sporcu bulunamadı');
      }

      if (_secilenSporcu!.kilo != null && _secilenSporcu!.kilo!.isNotEmpty) {
        _bodyMass = double.parse(_secilenSporcu!.kilo!);
      } else {
        _bodyMass = 0.0;
        throw Exception('Vücut ağırlığı bilgisi bulunamadı');
      }

      if (_secilenSporcu!.bacakBoyu != null && _secilenSporcu!.bacakBoyu!.isNotEmpty) {
        _legLength = double.parse(_secilenSporcu!.bacakBoyu!);
      } else {
        _legLength = 0.0;
        throw Exception('Bacak boyu bilgisi bulunamadı');
      }

      if (_secilenSporcu!.oturmaBoyu != null && _secilenSporcu!.oturmaBoyu!.isNotEmpty) {
        _sittingHeight = double.parse(_secilenSporcu!.oturmaBoyu!);
      } else {
        _sittingHeight = 0.0;
        throw Exception('Oturma boyu bilgisi bulunamadı');
      }

      _pushOffDistance = (_legLength - _sittingHeight) / 100.0;
      if (_pushOffDistance <= 0) {
        throw Exception(
            'İtme mesafesi hesaplanamadı: $_pushOffDistance (Bacak boyu: $_legLength cm, Oturma boyu: $_sittingHeight cm)');
      }

      _olcumler = await _databaseService.getOlcumlerBySporcuId(sporcuId);

      for (int i = 0; i < _olcumler.length; i++) {
        var olcum = _olcumler[i];
        if (olcum.degerler.isEmpty && olcum.id != null) {
          try {
            List<OlcumDeger> degerler = await _databaseService.getOlcumDegerlerByOlcumId(olcum.id!);
            olcum.degerler = degerler;
          } catch (e) {
            debugPrint('DikeyProfilScreen: Ölçüm ID ${olcum.id} için değerler yüklenirken hata: $e');
          }
        }
      }

      _tumOlcumler = _olcumler
          .where((olcum) => olcum.olcumTuru == 'CMJ' || olcum.olcumTuru == 'SJ')
          .toList();

      if (_tumOlcumler.isEmpty) {
        throw Exception('Sıçrama (CMJ veya SJ) ölçümü bulunamadı.');
      }

      _seciliOlcumler = List.filled(_tumOlcumler.length, true);
      _updateSelectedOlcumler();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _updateSelectedOlcumler() {
    _hesaplamayaGirecekOlcumler = [];

    for (int i = 0; i < _tumOlcumler.length; i++) {
      if (i < _seciliOlcumler.length && _seciliOlcumler[i]) {
        _hesaplamayaGirecekOlcumler.add(_tumOlcumler[i]);
      }
    }

    _jumpHeights = [];
    for (var olcum in _hesaplamayaGirecekOlcumler) {
      OlcumDeger? yukseklikDegeri;
      try {
        yukseklikDegeri = olcum.degerler.firstWhere(
          (d) => d.degerTuru == 'yukseklik',
        );
        
        if (yukseklikDegeri.deger > 0) {
          _jumpHeights.add(yukseklikDegeri.deger);
        }
      } catch (e) {
        for (String alternatif in ['Height', 'height', 'YUKSEKLIK', 'jump_height']) {
          try {
            yukseklikDegeri = olcum.degerler.firstWhere(
              (d) => d.degerTuru == alternatif,
            );
            
            if (yukseklikDegeri.deger > 0) {
              _jumpHeights.add(yukseklikDegeri.deger);
            }
            break;
          } catch (e2) {
            // Alternatif bulunamadı
          }
        }
      }
    }
    
    setState(() {});
  }

  void _calculateForceVelocityProfile() {
    try {
      if (_jumpHeights.length < 3) {
        throw Exception('En az 3 sıçrama ölçümü gereklidir.');
      }

      const double g = 9.81;

      List<double> vTakeoff = [];
      List<double> vMean = [];
      for (int i = 0; i < _jumpHeights.length; i++) {
        double h = _jumpHeights[i] / 100.0;
        double v = math.sqrt(2 * g * h);
        vTakeoff.add(v);
        vMean.add(v / 2);
      }

      _forces = [];
      _velocities = [];
      for (int i = 0; i < _jumpHeights.length; i++) {
        double additionalMass = i < _additionalMasses.length ? _additionalMasses[i] : 0;
        
        double totalMass = _bodyMass + additionalMass;
        double v = vTakeoff[i];
        double fMean = totalMass * ((v * v) / (2 * _pushOffDistance) + g);
        double fNorm = fMean / _bodyMass;
        _forces.add(fNorm);
        _velocities.add(vMean[i]);
      }

      double sumV = _velocities.reduce((a, b) => a + b);
      double sumF = _forces.reduce((a, b) => a + b);
      double sumVF = 0;
      for (int i = 0; i < _velocities.length; i++) {
        sumVF += _velocities[i] * _forces[i];
      }
      double sumV2 = _velocities.fold(0, (sum, v) => sum + v * v);
      int n = _velocities.length;

      double a, b;
      if (n * sumV2 - sumV * sumV != 0) {
        a = (n * sumVF - sumV * sumF) / (n * sumV2 - sumV * sumV);
        b = (sumF - a * sumV) / n;
      } else {
        a = 0;
        b = 0;
      }

      _f0PerKg = b;
      
      if (a != 0) {
        _v0PerKg = -b / a;
      } else {
        _v0PerKg = 0;
      }
      
      _sfvPerKg = a;
      _pmaxPerKg = (_f0PerKg * _v0PerKg) / 4;

      double penteOpt90 = _calculatePenteOpt(g, _pmaxPerKg, _pushOffDistance, 90.0);
      _sfvOptPerKg = _calculateSfvOpt(_pmaxPerKg, _pushOffDistance, g, penteOpt90, 90.0);

      double penteOpt30 = _calculatePenteOpt(g, _pmaxPerKg, _pushOffDistance, 30.0);
      _sfvOpt30PerKg = _calculateSfvOpt(_pmaxPerKg, _pushOffDistance, g, penteOpt30, 30.0);

      if (_sfvOptPerKg != 0) {
        _fvimb = 100 * (_sfvPerKg - _sfvOptPerKg) / _sfvOptPerKg.abs();
      } else {
        _fvimb = 0;
      }

      double meanF = _forces.reduce((a, b) => a + b) / _forces.length;
      double ssTot = _forces.fold(0, (sum, f) => sum + math.pow(f - meanF, 2));
      double ssRes = 0;
      for (int i = 0; i < _forces.length; i++) {
        double predictedF = a * _velocities[i] + b;
        ssRes += math.pow(_forces[i] - predictedF, 2);
      }
      
      if (ssTot != 0) {
        _rSquared = 1 - (ssRes / ssTot);
      } else {
        _rSquared = 0;
      }

      setState(() {});
    } catch (e) {
      debugPrint('Hesaplama hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hesaplama hatası: $e')),
        );
      }
    }
  }

  double _calculatePenteOpt(
      double g, double pmaxPerKg, double pushOffDistance, double alphaDegrees) {
    try {
      double alphaRadians = alphaDegrees * math.pi / 180.0;
      double gAdjusted = g * math.sin(alphaRadians);

      if (pmaxPerKg <= 0 || pushOffDistance <= 0) {
        return 0.0;
      }

      double g3 = math.pow(gAdjusted, 3).toDouble();
      double g6 = math.pow(gAdjusted, 6).toDouble();
      double hpo4 = math.pow(pushOffDistance, 4).toDouble();
      double hpo5 = math.pow(pushOffDistance, 5).toDouble();
      double hpo6 = math.pow(pushOffDistance, 6).toDouble();
      double hpo8 = math.pow(pushOffDistance, 8).toDouble();
      double hpo9 = math.pow(pushOffDistance, 9).toDouble();
      double pmax2 = math.pow(pmaxPerKg, 2).toDouble();
      double pmax4 = math.pow(pmaxPerKg, 4).toDouble();
      double pmax6 = math.pow(pmaxPerKg, 6).toDouble();
      double pmax8 = math.pow(pmaxPerKg, 8).toDouble();

      double term1 = g6 * hpo6;
      double term2 = 18 * g3 * hpo5 * pmax2;
      double term3 = 54 * hpo4 * pmax4;
      double term4Inner = 2 * g3 * hpo9 * pmax6 + 27 * hpo8 * pmax8;

      if (term4Inner < 0) {
        return 0.0;
      }

      double term4 = 6 * math.sqrt(3) * math.sqrt(term4Inner);
      double total = -term1 - term2 - term3 + term4;

      double penteOpt;
      if (total == 0) {
        penteOpt = 0;
      } else {
        double sign = total < 0 ? -1 : 1;
        double absTotal = total.abs();
        double cubeRootOfAbs = math.pow(absTotal, 1.0 / 3.0).toDouble();
        penteOpt = sign * cubeRootOfAbs;
      }

      return penteOpt;
    } catch (e) {
      debugPrint('pente OPT hesaplanırken bir hata oluştu: $e');
      return 0.0;
    }
  }

  double _calculateSfvOpt(double pmaxPerKg, double pushOffDistance, double g,
      double penteOpt, double alphaDegrees) {
    try {
      double alphaRadians = alphaDegrees * math.pi / 180.0;
      double gAdjusted = g * math.sin(alphaRadians);

      if (pmaxPerKg <= 0 || pushOffDistance <= 0 || penteOpt.isNaN || penteOpt.isInfinite) {
        return 0.0;
      }

      double g2 = math.pow(gAdjusted, 2).toDouble();
      double g4 = math.pow(gAdjusted, 4).toDouble();
      double hpo2 = math.pow(pushOffDistance, 2).toDouble();
      double hpo3 = math.pow(pushOffDistance, 3).toDouble();
      double hpo4 = math.pow(pushOffDistance, 4).toDouble();
      double pmax2 = math.pow(pmaxPerKg, 2).toDouble();

      double term1 = -(g2 / (3 * pmaxPerKg));

      double term2Numerator = -(g4 * hpo4) - (12 * gAdjusted * hpo3 * pmax2);
      double term2Denominator = 3 * hpo2 * pmaxPerKg * penteOpt;

      double term2Fraction;
      if (term2Denominator == 0) {
        term2Fraction = 0;
      } else {
        term2Fraction = term2Numerator / term2Denominator;
      }

      double term3Denominator = 3 * hpo2 * pmaxPerKg;

      double term3;
      if (term3Denominator == 0) {
        term3 = 0;
      } else {
        term3 = penteOpt / term3Denominator;
      }

      double sfvOpt = term1 - term2Fraction + term3;

      return sfvOpt;
    } catch (e) {
      debugPrint('Sfv opt hesaplanırken bir hata oluştu: $e');
      return 0.0;
    }
  }

  String _getProfileInterpretation() {
    if (_fvimb.isNaN) return "";

    if (_fvimb < -15) {
      return "Kuvvet yönelimli bir dengesizlik:\n\n"
          "Sporcu yüksek kuvvet kapasitesine sahip, ancak bu kuvveti "
          "hızlı hareketlere dönüştürme kapasitesi düşük. Antrenmanlarda hız "
          "geliştirici çalışmalara (plyometrik sıçramalar, hızlı tekrarlı egzersizler) "
          "ağırlık verilmesi önerilir.";
    } else if (_fvimb > 15) {
      return "Hız yönelimli bir dengesizlik:\n\n"
          "Sporcu yüksek hız kapasitesine sahip, ancak yeterli kuvvet üretemiyor. "
          "Antrenmanlarda kuvvet geliştirici çalışmalara (squat, power clean gibi "
          "ağırlık çalışmaları) odaklanılması önerilir.";
    } else {
      return "Dengeli Profil:\n\n"
          "Sporcu kuvvet ve hız arasında optimal bir dengeye sahip. "
          "Performansı optimize etmek için dengeli bir güç antrenman programı "
          "(hem kuvvet hem hız antrenmanları içeren) uygulanabilir.";
    }
  }

  String _formatTarih(String tarih) {
    try {
      if (tarih.contains('T')) {
        final date = DateTime.parse(tarih);
        return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
      }
      return tarih;
    } catch (e) {
      return tarih;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dikey Kuvvet-Hız Profili'),
        backgroundColor: const Color(0xFF0288D1),
        actions: [
          // VERİTABANI KAYIT BUTONU
          if (_secilenSporcu != null && _hesaplamayaGirecekOlcumler.isNotEmpty)
            IconButton(
              onPressed: _isSaving ? null : _saveAnalysisToDatabase,
              icon: _isSaving 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save),
              tooltip: 'Analizi Veritabanına Kaydet',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSporcuSecimBolumu(),
                  const SizedBox(height: 16),
                  if (_secilenSporcu != null) ...[
                    _buildOlcumSecimBolumu(),
                    const SizedBox(height: 16),
                    _buildSporcuBilgileri(),
                    const SizedBox(height: 16),
                    _buildSicramaOlcumleri(),
                    const SizedBox(height: 16),
                    _buildKuvvetHizProfili(),
                    const SizedBox(height: 16),
                    _buildKuvvetHizGrafigi(),
                    const SizedBox(height: 16),
                    _buildProfileInterpretation(),
                    const SizedBox(height: 20),
                    
                    // BAŞARI DURUMU GÖSTERGESİ
                    if (_savedAnalysis != null) 
                      _buildSuccessIndicator(),
                    
                    // PDF WİDGET BÖLÜMÜ
                    if (_pdfConfig != null) ...[
                      const Divider(thickness: 2),
                      const SizedBox(height: 16),
                      _buildPDFSection(),
                    ],
                    
                    const SizedBox(height: 80),
                  ],
                ],
              ),
            ),
    );
  }

  // ========== YENİ UI WİDGETLARI ==========

  Widget _buildSuccessIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Analiz başarıyla veritabanına kaydedildi (ID: ${_savedAnalysis!.id})',
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPDFSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.picture_as_pdf, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text(
                'PDF Raporu',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0288D1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Dikey Kuvvet-Hız Profili analizinizi PDF olarak kaydedin veya paylaşın',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          if (_savedAnalysis != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Bu analiz veritabanına kaydedilmiştir (ID: ${_savedAnalysis!.id})',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          PDFActionWidget(
            config: _pdfConfig!,
            onSuccess: () {
              _showSnackBar('PDF işlemi başarılı!', isError: false);
            },
            onError: (error) {
              _showSnackBar('PDF hatası: $error', isError: true);
            },
          ),
        ],
      ),
    );
  }

  // ========== MEVCUT UI WİDGETLARI (AYNI KALIYOR) ==========

  Widget _buildSporcuSecimBolumu() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(76),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sporcu Seçin',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0288D1),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            hint: const Text('Sporcu Seçin'),
            value: _secilenSporcu?.id,
            onChanged: (sporcuId) {
              if (sporcuId != null) {
                setState(() {
                  _secilenSporcu =
                      _sporcular.firstWhere((sporcu) => sporcu.id == sporcuId);
                });
                _loadSporcuOlcumleri(sporcuId);
              }
            },
            items: _sporcular.map((sporcu) {
              return DropdownMenuItem<int>(
                value: sporcu.id,
                child: Text('${sporcu.ad} ${sporcu.soyad} (${sporcu.yas} yaş)'),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOlcumSecimBolumu() {
    if (_tumOlcumler.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(76),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hesaplamaya Girecek Ölçümleri Seçin',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0288D1),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'En az 3 ölçüm seçmelisiniz',
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _tumOlcumler.length,
            itemBuilder: (context, index) {
              Olcum olcum = _tumOlcumler[index];
              
              double yukseklik = 0;
              for (var deger in olcum.degerler) {
                if (deger.degerTuru == 'yukseklik') {
                  yukseklik = deger.deger;
                  break;
                }
              }
              
              String tarih = _formatTarih(olcum.olcumTarihi);
              
              return CheckboxListTile(
                title: Text('${olcum.olcumTuru} - ${olcum.olcumSirasi}. Ölçüm (Test #${olcum.testId})'),
                subtitle: Text('Yükseklik: ${yukseklik.toStringAsFixed(1)} cm - Tarih: $tarih'),
                value: index < _seciliOlcumler.length ? _seciliOlcumler[index] : false,
                activeColor: const Color(0xFF0288D1),
                onChanged: (bool? value) {
                  if (value != null) {
                    setState(() {
                      if (index < _seciliOlcumler.length) {
                        _seciliOlcumler[index] = value;
                        _updateSelectedOlcumler();
                      }
                    });
                  }
                },
              );
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              if (_hesaplamayaGirecekOlcumler.length < 3) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('En az 3 ölçüm seçmelisiniz')),
                );
                return;
              }
              _calculateForceVelocityProfile();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0288D1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Profil Hesapla'),
          ),
        ],
      ),
    );
  }

  Widget _buildSporcuBilgileri() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(76),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sporcu Bilgileri',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0288D1),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                    'Vücut Ağırlığı', '${_bodyMass.toStringAsFixed(1)} kg', Icons.monitor_weight),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInfoCard(
                    'Bacak Boyu', '${_legLength.toStringAsFixed(1)} cm', Icons.height),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInfoCard('Oturma Boyu', '${_sittingHeight.toStringAsFixed(1)} cm',
                    Icons.airline_seat_recline_normal),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInfoCard(
              'İtme Mesafesi', '${_pushOffDistance.toStringAsFixed(2)} m', Icons.straighten),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF0288D1)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSicramaOlcumleri() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(76),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sıçrama Ölçümleri',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0288D1),
            ),
          ),
          const SizedBox(height: 16),
          if (_hesaplamayaGirecekOlcumler.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Önce hesaplamaya girecek sıçrama ölçümlerini seçiniz',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Ölçüm No')),
                  DataColumn(label: Text('Ölçüm Türü')),
                  DataColumn(label: Text('Yükseklik (cm)')),
                  DataColumn(label: Text('Ek Ağırlık (kg)')),
                ],
                rows: List<DataRow>.generate(
                  _jumpHeights.length,
                  (index) {
                    Olcum? olcum;
                    if (index < _hesaplamayaGirecekOlcumler.length) {
                      olcum = _hesaplamayaGirecekOlcumler[index];
                    }
                    
                    return DataRow(
                      cells: [
                        DataCell(Text('${index + 1}')),
                        DataCell(Text(olcum?.olcumTuru ?? '-')),
                        DataCell(Text(_jumpHeights[index].toStringAsFixed(1))),
                        DataCell(Text(index < _additionalMasses.length
                            ? _additionalMasses[index].toStringAsFixed(1)
                            : '0.0')),
                      ],
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKuvvetHizProfili() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(76),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kuvvet-Hız Profili',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0288D1),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildResultCard(
                    'F0 (N/kg)', _f0PerKg.toStringAsFixed(1), _getCardColor(_f0PerKg, 15, 25)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildResultCard(
                    'V0 (m/s)', _v0PerKg.toStringAsFixed(2), _getCardColor(_v0PerKg, 1.5, 2.2)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildResultCard('Pmax (W/kg)', _pmaxPerKg.toStringAsFixed(1),
                    _getCardColor(_pmaxPerKg, 40, 55)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildResultCard(
                    'Sfv (N.s/m/kg)', _sfvPerKg.toStringAsFixed(2), Colors.lightBlue[100]!),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildResultCard(
                    'Sfv Opt', _sfvOptPerKg.toStringAsFixed(2), Colors.lightBlue[100]!),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildResultCard(
                    'FVimb (%)', '${_fvimb.toStringAsFixed(0)}%', _getFvimbColor(_fvimb)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildResultCard('R²', _rSquared.toStringAsFixed(4), _getR2Color(_rSquared)),
        ],
      ),
    );
  }

  Widget _buildProfileInterpretation() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(76),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profil Yorumlama',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0288D1),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _getProfileInterpretation(),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Color _getCardColor(double value, double lowThreshold, double highThreshold) {
    if (value.isNaN || value <= 0) return Colors.grey[300]!;

    if (value < lowThreshold) {
      return Colors.red[100]!;
    } else if (value < highThreshold) {
      return Colors.yellow[100]!;
    } else {
      return Colors.green[100]!;
    }
  }

  Color _getFvimbColor(double value) {
    if (value.isNaN) return Colors.grey[300]!;

    if (value < -15) {
      return Colors.lightBlue[100]!; // Kuvvet yönelimli
    } else if (value > 15) {
      return Colors.red[100]!; // Hız yönelimli
    } else {
      return Colors.green[100]!; // Optimal
    }
  }

  Color _getR2Color(double value) {
    if (value.isNaN) return Colors.grey[300]!;

    if (value < 0.70) {
      return Colors.red[100]!;
    } else if (value < 0.85) {
      return Colors.yellow[100]!;
    } else {
      return Colors.green[100]!;
    }
  }

  Widget _buildResultCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(128)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildKuvvetHizGrafigi() {
    if (_forces.isEmpty || _velocities.isEmpty) {
      return Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withAlpha(76),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Center(
          child: Text('Grafik çizilecek yeterli veri yok'),
        ),
      );
    }

    double f0Opt90 = 0;
    double v0Opt90 = 0;
    double f0Opt30 = 0;
    double v0Opt30 = 0;
    double fvProfile90 = 0;
    double fvProfile30 = 0;

    if (_sfvOptPerKg.isFinite && _pmaxPerKg.isFinite && 
        !_sfvOptPerKg.isNaN && !_pmaxPerKg.isNaN && 
        _pmaxPerKg > 0 && _sfvOptPerKg != 0) {
      double value = -_sfvOptPerKg * _pmaxPerKg;
      if (value > 0) {
        f0Opt90 = 2 * math.sqrt(value);
        if (f0Opt90 > 0) {
          v0Opt90 = (4 * _pmaxPerKg) / f0Opt90;
        }
      }
      if (_sfvOptPerKg != 0) {
        fvProfile90 = (_sfvPerKg / _sfvOptPerKg) * 100;
      }
    }

    if (_sfvOpt30PerKg.isFinite && _pmaxPerKg.isFinite && 
        !_sfvOpt30PerKg.isNaN && !_pmaxPerKg.isNaN && 
        _pmaxPerKg > 0 && _sfvOpt30PerKg != 0) {
      double value = -_sfvOpt30PerKg * _pmaxPerKg;
      if (value > 0) {
        f0Opt30 = 2 * math.sqrt(value);
        if (f0Opt30 > 0) {
          v0Opt30 = (4 * _pmaxPerKg) / f0Opt30;
        }
      }
      if (_sfvOpt30PerKg != 0) {
        fvProfile30 = (_sfvPerKg / _sfvOpt30PerKg) * 100;
      }
    }

    double maxF0 = 0;
    double maxV0 = 0;
    
    List<double> validF0Values = [];
    if (_f0PerKg.isFinite && !_f0PerKg.isNaN && _f0PerKg > 0) validF0Values.add(_f0PerKg);
    if (f0Opt90.isFinite && !f0Opt90.isNaN && f0Opt90 > 0) validF0Values.add(f0Opt90);
    if (f0Opt30.isFinite && !f0Opt30.isNaN && f0Opt30 > 0) validF0Values.add(f0Opt30);
    
    if (validF0Values.isNotEmpty) {
      maxF0 = validF0Values.reduce(math.max);
    } else {
      maxF0 = 40.0;
    }
    
    List<double> validV0Values = [];
    if (_v0PerKg.isFinite && !_v0PerKg.isNaN && _v0PerKg > 0) validV0Values.add(_v0PerKg);
    if (v0Opt90.isFinite && !v0Opt90.isNaN && v0Opt90 > 0) validV0Values.add(v0Opt90);
    if (v0Opt30.isFinite && !v0Opt30.isNaN && v0Opt30 > 0) validV0Values.add(v0Opt30);
    
    if (validV0Values.isNotEmpty) {
      maxV0 = validV0Values.reduce(math.max);
    } else {
      maxV0 = 3.0;
    }

    double xInterval;
    double maxSpeed = maxV0 * 1.2;
    
    if (!maxSpeed.isFinite || maxSpeed.isNaN || maxSpeed <= 0) {
      maxSpeed = 3.0;
    }
    
    if (maxSpeed > 10) {
      xInterval = 2.0;
    } else if (maxSpeed > 5) {
      xInterval = 1.0;
    } else {
      xInterval = 0.5;
    }

    int ceiledValue = 6;
    try {
      ceiledValue = (maxSpeed / xInterval).ceil();
      maxSpeed = ceiledValue * xInterval;
    } catch (e) {
      maxSpeed = 3.0;
    }

    return Container(
      height: 400,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(76),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kuvvet-Hız Grafiği',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0288D1),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildLegendItem(Colors.red, 'Mevcut F-V Profili'),
              _buildLegendItem(Colors.orange, 'F-V 30° (${fvProfile30.isFinite ? fvProfile30.toStringAsFixed(0) : "0"}% optimal)'),
              _buildLegendItem(Colors.blue, 'F-V 90° (${fvProfile90.isFinite ? fvProfile90.toStringAsFixed(0) : "0"}% optimal)'),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 5,
                  verticalInterval: xInterval,
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: xInterval,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value > maxSpeed) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: ClipRect(
                            clipBehavior: Clip.hardEdge,
                            child: Text(
                              value.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Color(0xff68737d),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.clip,
                            ),
                          ),
                        );
                      },
                    ),
                    axisNameWidget: const Text(
                      'Hız (m/s)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 5,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: Color(0xff68737d),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                    axisNameWidget: const Text(
                      'Kuvvet (N/kg)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: const Color(0xff37434d)),
                ),
                minX: 0,
                maxX: maxSpeed,
                minY: 0,
                maxY: maxF0 * 1.2,
                lineBarsData: [
                  // Mevcut F-V Profili (Kırmızı Çizgi)
                  LineChartBarData(
                    spots: [
                      FlSpot(0, _f0PerKg.isFinite && !_f0PerKg.isNaN ? _f0PerKg : 0),
                      FlSpot(math.min(_v0PerKg.isFinite && !_v0PerKg.isNaN ? _v0PerKg : 0, maxSpeed), 0),
                    ],
                    isCurved: false,
                    color: Colors.red,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: false),
                  ),
                  // Optimal F-V Profili 30° (Turuncu Kesikli Çizgi)
                  LineChartBarData(
                    spots: [
                      FlSpot(0, f0Opt30.isFinite && !f0Opt30.isNaN ? f0Opt30 : 0),
                      FlSpot(math.min(v0Opt30.isFinite && !v0Opt30.isNaN ? v0Opt30 : 0, maxSpeed), 0),
                    ],
                    isCurved: false,
                    color: Colors.orange,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: false),
                    dashArray: [5, 5],
                  ),
                  // Optimal F-V Profili 90° (Mavi Kesikli Çizgi)
                  LineChartBarData(
                    spots: [
                      FlSpot(0, f0Opt90.isFinite && !f0Opt90.isNaN ? f0Opt90 : 0),
                      FlSpot(math.min(v0Opt90.isFinite && !v0Opt90.isNaN ? v0Opt90 : 0, maxSpeed), 0),
                    ],
                    isCurved: false,
                    color: Colors.blue,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: false),
                    dashArray: [5, 5],
                  ),
                  // Veri noktaları (Sarı Noktalar)
                  LineChartBarData(
                    spots: List.generate(
                      _forces.length,
                      (i) {
                        try {
                          if (i < _forces.length && i < _velocities.length) {
                            double vMean = _velocities[i];
                            double fNorm = _forces[i];
                            if (vMean.isFinite && fNorm.isFinite && 
                                !vMean.isNaN && !fNorm.isNaN) {
                              vMean = math.min(vMean, maxSpeed);
                              fNorm = math.min(fNorm, maxF0 * 1.2);
                              return FlSpot(vMean, fNorm);
                            }
                          }
                          return FlSpot(0, 0);
                        } catch (e) {
                          return FlSpot(0, 0);
                        }
                      },
                    ),
                    isCurved: false,
                    color: Colors.amber,
                    barWidth: 0,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 6,
                        color: Colors.amber,
                        strokeWidth: 1,
                        strokeColor: Colors.amber.shade800,
                      ),
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}