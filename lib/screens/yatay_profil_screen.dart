import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/sporcu_model.dart';
import '../models/olcum_model.dart';
import '../models/performance_analysis_model.dart'; // YENİ EKLENEN
import '../services/database_service.dart';
import '../widgets/pdf_action_widget.dart'; // YENİ EKLENEN

class YatayProfilScreen extends StatefulWidget {
  const YatayProfilScreen({super.key});

  @override
  State<YatayProfilScreen> createState() => _YatayProfilScreenState();
}

class _YatayProfilScreenState extends State<YatayProfilScreen> {
  final _databaseService = DatabaseService();
  Sporcu? _secilenSporcu;
  List<Sporcu> _sporcular = [];
  List<Olcum> _olcumler = [];
  Map<int, List<Olcum>> _testGruplari = {};
  int? _secilenTestId;
  bool _isSaving = false; // YENİ EKLENEN - Kayıt durumu
  PerformanceAnalysis? _savedAnalysis; // YENİ EKLENEN - Kaydedilen analiz
  
  // Form controller'ları
  final _basincController = TextEditingController(text: "1000.0"); // hPa
  final _sicaklikController = TextEditingController(text: "20.0"); // °C
  final _kuruAgirlikController = TextEditingController();
  final _boyController = TextEditingController();
  
  // Yatay profil parametreleri
  double _bodyMass = 0.0;
  double _stature = 0.0;
  double _f0 = 0.0;
  double _v0 = 0.0;
  double _pmax = 0.0;
  double _sfv = 0.0; 
  double _sfvOpt = 0.0;
  double _fvimb = 0.0;
  double _rfmax = 0.0;
  double _drf = 0.0;
  double _vmax = 0.0;
  double _tau = 0.0;
  double _rSquared = 0.0;
  
  List<double> _sprintTimes = [];
  List<double> _sprintDistances = [];
  
  // Hesaplanan kuvvet ve hız değerleri
  List<double> _velocities = [];
  List<double> _forces = [];
  List<double> _powerValues = [];
  
  bool _isLoading = true;
  
  // Kapı mesafeleri - varsayılan değerler
  final List<double> _defaultDistances = [0, 5, 10, 15, 20, 30, 40];

  @override
  void initState() {
    super.initState();
    _loadSporcular();
  }
  
  @override
  void dispose() {
    _basincController.dispose();
    _sicaklikController.dispose();
    _kuruAgirlikController.dispose();
    _boyController.dispose();
    super.dispose();
  }

  // ========== VERİTABANI KAYIT İŞLEMLERİ ==========
  
  /// Yatay profil analizini veritabanına kaydet
  Future<void> _saveAnalysisToDatabase() async {
    if (_secilenSporcu == null || _sprintTimes.isEmpty || _forces.isEmpty) {
      _showSnackBar('Kaydedilecek geçerli analiz verisi yok');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Performans analizi objesi oluştur
      final analysis = PerformanceAnalysis(
        sporcuId: _secilenSporcu!.id!,
        olcumTuru: 'YatayProfil',
        degerTuru: 'HizIvmeAnalizi',
        timeRange: 'Test ID: $_secilenTestId',
        calculationDate: DateTime.now(),
        
        // Temel istatistikler (sprint sürelerinden)
        mean: _sprintTimes.isNotEmpty ? _sprintTimes.reduce((a, b) => a + b) / _sprintTimes.length : 0.0,
        standardDeviation: _calculateStandardDeviation(_sprintTimes),
        coefficientOfVariation: _calculateCV(_sprintTimes),
        minimum: _sprintTimes.isNotEmpty ? _sprintTimes.reduce(math.min) : 0.0,
        maximum: _sprintTimes.isNotEmpty ? _sprintTimes.reduce(math.max) : 0.0,
        range: _sprintTimes.isNotEmpty ? (_sprintTimes.reduce(math.max) - _sprintTimes.reduce(math.min)) : 0.0,
        median: _calculateMedian(_sprintTimes),
        sampleCount: _sprintTimes.length,
        q25: _calculatePercentile(_sprintTimes, 25),
        q75: _calculatePercentile(_sprintTimes, 75),
        iqr: _calculatePercentile(_sprintTimes, 75) - _calculatePercentile(_sprintTimes, 25),
        
        // Yatay profil spesifik değerler
        typicalityIndex: _rSquared * 100, // R² değerini tipiklik indeksi olarak kullan
        momentum: _calculateMomentum(),
        trendSlope: _sfv,
        trendStability: _rSquared,
        trendRSquared: _rSquared,
        trendStrength: _calculateTrendStrength(),
        
        // Güvenilirlik metrikleri (yatay profil için adapte)
        swc: _calculateSWC(),
        mdc: _calculateMDC(),
        testRetestReliability: _rSquared,
        icc: _rSquared,
        cvPercent: _calculateCV(_sprintTimes),
        
        // Performans değerlendirme
        performanceClass: _getPerformanceClass(),
        performanceTrend: _getPerformanceTrend(),
        recentChange: _calculateRecentChange(),
        recentChangePercent: _calculateRecentChangePercent(),
        outliersCount: _calculateOutliersCount(),
        
        // JSON veriler
        performanceValuesJson: jsonEncode(_sprintTimes),
        datesJson: jsonEncode(_getSelectedMeasurementDates()),
        zScoresJson: jsonEncode(_calculateZScores(_sprintTimes)),
        outliersJson: jsonEncode(_identifyOutliers(_sprintTimes)),
        
        // Yatay profil spesifik ek veriler
        additionalData: {
          'yatayProfil': {
            'bodyMass': _bodyMass,
            'stature': _stature,
            'pressure': double.tryParse(_basincController.text) ?? 1000.0,
            'temperature': double.tryParse(_sicaklikController.text) ?? 20.0,
            'f0': _f0,
            'v0': _v0,
            'pmax': _pmax,
            'sfv': _sfv,
            'sfvOpt': _sfvOpt,
            'fvimb': _fvimb,
            'rfmax': _rfmax,
            'drf': _drf,
            'vmax': _vmax,
            'tau': _tau,
            'rSquared': _rSquared,
            'profileType': _getProfileType(),
            'interpretation': _getProfileInterpretation(),
            'recommendations': _getRecommendations(),
            'forces': _forces,
            'velocities': _velocities,
            'powerValues': _powerValues,
            'sprintDistances': _sprintDistances,
            'defaultDistances': _defaultDistances,
            'selectedTestId': _secilenTestId,
            'selectedMeasurements': _getSelectedMeasurementDetails(),
          }
        },
      );

      // Veritabanına kaydet
      final analysisId = await _databaseService.savePerformanceAnalysis(analysis);
      _savedAnalysis = analysis.copyWith(id: analysisId);
      
      _showSnackBar('Yatay profil analizi başarıyla veritabanına kaydedildi (ID: $analysisId)');

      debugPrint('YatayProfil analizi kaydedildi: ID=$analysisId, Sporcu=${_secilenSporcu!.ad}');
      
    } catch (e) {
      debugPrint('YatayProfil analizi kaydetme hatası: $e');
      _showSnackBar('Analiz kaydetme hatası: $e');
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
    // Sprint sürelerinde azalma = pozitif momentum (hız artışı)
    if (_sprintTimes.length < 3) return 0.0;
    
    List<double> recent = _sprintTimes.take(3).toList();
    double firstHalf = recent.take(recent.length ~/ 2).reduce((a, b) => a + b) / (recent.length ~/ 2);
    double secondHalf = recent.skip(recent.length ~/ 2).reduce((a, b) => a + b) / (recent.length - recent.length ~/ 2);
    
    // Sprint'te süre azalması iyi, bu yüzden ters işaret
    return -((secondHalf - firstHalf) / firstHalf) * 100;
  }
  
  double _calculateTrendStrength() {
    return _rSquared > 0.8 ? 1.0 : _rSquared > 0.6 ? 0.5 : 0.0;
  }
  
  double _calculateSWC() {
    // Smallest Worthwhile Change - 0.2 x SD olarak hesapla
    return _calculateStandardDeviation(_sprintTimes) * 0.2;
  }
  
  double _calculateMDC() {
    // Minimal Detectable Change - 1.96 x SEM olarak hesapla
    double sem = _calculateStandardDeviation(_sprintTimes) / math.sqrt(_sprintTimes.length);
    return 1.96 * sem;
  }
  
  String _getPerformanceClass() {
    if (_pmax.isNaN || _pmax <= 0) return 'Hesaplanamadı';
    
    if (_pmax > 18) return 'Mükemmel';
    if (_pmax > 14) return 'İyi';
    if (_pmax > 10) return 'Orta';
    return 'Düşük';
  }
  
  String _getPerformanceTrend() {
    if (_sprintTimes.length < 2) return 'Belirsiz';
    
    double firstValue = _sprintTimes.first;
    double lastValue = _sprintTimes.last;
    double change = ((lastValue - firstValue) / firstValue) * 100;
    
    // Sprint'te süre azalması iyi (negatif değişim = iyileşme)
    if (change < -5) return 'Yükseliş';
    if (change > 5) return 'Düşüş';
    return 'Stabil';
  }
  
  double _calculateRecentChange() {
    if (_sprintTimes.length < 2) return 0.0;
    return _sprintTimes.last - _sprintTimes.first;
  }
  
  double _calculateRecentChangePercent() {
    if (_sprintTimes.length < 2 || _sprintTimes.first == 0) return 0.0;
    return ((_sprintTimes.last - _sprintTimes.first) / _sprintTimes.first) * 100;
  }
  
  int _calculateOutliersCount() {
    List<double> outliers = _identifyOutliers(_sprintTimes);
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

  List<String> _getSelectedMeasurementDates() {
    if (_secilenTestId == null || !_testGruplari.containsKey(_secilenTestId)) {
      return [];
    }
    return _testGruplari[_secilenTestId]!.map((o) => o.olcumTarihi).toList();
  }

  List<Map<String, dynamic>> _getSelectedMeasurementDetails() {
    if (_secilenTestId == null || !_testGruplari.containsKey(_secilenTestId)) {
      return [];
    }
    
    return _testGruplari[_secilenTestId]!.map((olcum) => {
      'id': olcum.id,
      'olcumSirasi': olcum.olcumSirasi,
      'olcumTarihi': olcum.olcumTarihi,
      'testId': olcum.testId,
      'degerler': olcum.degerler.map((d) => {
        'degerTuru': d.degerTuru,
        'deger': d.deger,
      }).toList(),
    }).toList();
  }

  // ========== PDF VERİ HAZIRLAMA ==========
  
  Map<String, dynamic> get _pdfAnalysisData {
    return {
      // Temel bilgiler
      'bodyMass': _bodyMass,
      'stature': _stature,
      'pressure': double.tryParse(_basincController.text) ?? 1000.0,
      'temperature': double.tryParse(_sicaklikController.text) ?? 20.0,
      
      // Profil sonuçları
      'f0': _f0,
      'v0': _v0,
      'pmax': _pmax,
      'sfv': _sfv,
      'sfvOpt': _sfvOpt,
      'fvimb': _fvimb,
      'rfmax': _rfmax,
      'drf': _drf,
      'vmax': _vmax,
      'tau': _tau,
      'rSquared': _rSquared,
      
      // Ham veriler
      'sprintTimes': _sprintTimes,
      'sprintDistances': _sprintDistances,
      'defaultDistances': _defaultDistances,
      'forces': _forces,
      'velocities': _velocities,
      'powerValues': _powerValues,
      
      // İstatistikler
      'mean': _sprintTimes.isNotEmpty ? _sprintTimes.reduce((a, b) => a + b) / _sprintTimes.length : 0.0,
      'standardDeviation': _calculateStandardDeviation(_sprintTimes),
      'coefficientOfVariation': _calculateCV(_sprintTimes),
      'minimum': _sprintTimes.isNotEmpty ? _sprintTimes.reduce(math.min) : 0.0,
      'maximum': _sprintTimes.isNotEmpty ? _sprintTimes.reduce(math.max) : 0.0,
      'median': _calculateMedian(_sprintTimes),
      'sampleCount': _sprintTimes.length,
      
      // Ölçüm verileri
      'selectedTestId': _secilenTestId,
      'selectedMeasurements': _getSelectedMeasurementDetails(),
      
      // Profil yorumlama
      'interpretation': _getProfileInterpretation(),
      'profileType': _getProfileType(),
      'recommendations': _getRecommendations(),
      'performanceClass': _getPerformanceClass(),
      
      // Grafik verileri
      'chartData': {
        'forceVelocityProfile': _forces.asMap().entries.map((entry) => {
          'x': _velocities[entry.key],
          'y': entry.value,
        }).toList(),
        'powerProfile': _powerValues.asMap().entries.map((entry) => {
          'x': _velocities[entry.key],
          'y': entry.value,
        }).toList(),
        'optimalProfile': _getOptimalProfileData(),
      },
      
      // Metadata
      'calculationDate': DateTime.now().toIso8601String(),
      'measurementCount': _sprintTimes.length,
      'analysisType': 'Yatay Kuvvet-Hız Profili',
      'savedAnalysisId': _savedAnalysis?.id,
    };
  }

  PDFReportConfig? get _pdfConfig {
    if (_secilenSporcu == null || _sprintTimes.isEmpty) {
      return null;
    }
    
    return PDFReportConfig.performance(
      sporcu: _secilenSporcu!,
      olcumTuru: 'YatayProfil',
      degerTuru: 'HizIvmeAnalizi',
      analysisData: _pdfAnalysisData,
      additionalNotes: 'Yatay Kuvvet-Hız Profili analizi raporu.\n\n'
          'Analiz Detayları:\n'
          '• Test ID: $_secilenTestId\n'
          '• ${_sprintTimes.length} adet sprint verisi kullanıldı\n'
          '• Profil Tipi: ${_getProfileType()}\n'
          '• FVimb (Profil Dengesizliği): ${_fvimb.toStringAsFixed(1)}%\n'
          '• R² (Güvenilirlik): ${_rSquared.toStringAsFixed(3)}\n'
          '• Maksimal Güç: ${_pmax.toStringAsFixed(1)} W/kg\n'
          '• Performans Sınıfı: ${_getPerformanceClass()}\n'
          '• RFmax: ${_rfmax.toStringAsFixed(4)}\n'
          '• DRF: ${(_drf * 100).toStringAsFixed(2)}%\n\n'
          'Bu rapor ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} tarihinde oluşturulmuştur.',
      includeCharts: true,
      showPrintButton: true,
    );
  }

  // ========== HELPER METODLAR ==========
  
  String _getProfileType() {
    if (_fvimb.isNaN) return "Hesaplanamadı";
    
    if (_fvimb > 15) {
      if (_sfv < _sfvOpt) {
        return "Kuvvet Eksikliği";
      } else {
        return "Hız Eksikliği";
      }
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
    
    if (_fvimb > 15) {
      if (_sfv < _sfvOpt) {
        recommendations.addAll([
          "Kuvvet geliştirici egzersizlere odaklanın",
          "Ağır sled antrenmanı yapın",
          "Hafif yüklerle patlayıcı squat egzersizleri",
          "Power clean gibi olimpik kaldırış hareketleri"
        ]);
      } else {
        recommendations.addAll([
          "Hız geliştirici egzersizlere odaklanın",
          "Pliometrik sıçrama antrenmanları",
          "Hız odaklı sprint çalışmaları",
          "Reaktif sprint drilleri"
        ]);
      }
    } else {
      recommendations.addAll([
        "Mevcut dengeli profilinizi koruyun",
        "Hem kuvvet hem hız antrenmanlarını eşit oranda yapın",
        "Periyodizasyon uygulayarak varyasyon sağlayın",
        "Spor dalınıza özel sprint antrenmanları"
      ]);
    }
    
    if (_rSquared < 0.7) {
      recommendations.add("Ölçüm tutarlılığını artırmak için standart protokol kullanın");
    }
    
    return recommendations;
  }
  
  List<Map<String, double>> _getOptimalProfileData() {
    double optimalF0 = 0.0;
    double optimalV0 = 0.0;
    
    if (_sfvOpt.isFinite && _pmax.isFinite && 
        !_sfvOpt.isNaN && !_pmax.isNaN && 
        _pmax > 0 && _sfvOpt != 0) {
      try {
        optimalF0 = 2 * math.sqrt(-_pmax * _sfvOpt);
        optimalV0 = -optimalF0 / _sfvOpt;
      } catch (e) {
        optimalF0 = 0.0;
        optimalV0 = 0.0;
      }
    }
    
    return [
      {'x': 0.0, 'y': optimalF0},
      {'x': optimalV0, 'y': 0.0},
    ];
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: message.contains('hata') || message.contains('Hata') 
              ? Colors.red 
              : const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: Duration(seconds: message.contains('hata') ? 4 : 3),
        ),
      );
    }
  }

  // ========== MEVCUT METODLAR (AYNI KALIYOR) ==========

  // Sporcuları yükle
  Future<void> _loadSporcular() async {
    try {
      setState(() => _isLoading = true);
      _sporcular = await _databaseService.getAllSporcular();
    } catch (e) {
      _showSnackBar('Sporcular yüklenirken hata: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  // Ölçümleri yükle
  Future<void> _loadOlcumler(int sporcuId) async {
    try {
      setState(() => _isLoading = true);
      
      // Sporcu bilgilerini al
      _secilenSporcu = await _databaseService.getSporcu(sporcuId);
      if (_secilenSporcu == null) {
        throw Exception('Sporcu bulunamadı');
      }
      
      // Vücut ağırlığı ve boy bilgilerini ayarla
      if (_secilenSporcu!.kilo != null && _secilenSporcu!.kilo!.isNotEmpty) {
        _bodyMass = double.parse(_secilenSporcu!.kilo!);
        _kuruAgirlikController.text = _bodyMass.toString();
      } else {
        _bodyMass = 70.0; // Varsayılan değer
        _kuruAgirlikController.text = "70.0";
      }
      
      if (_secilenSporcu!.boy != null && _secilenSporcu!.boy!.isNotEmpty) {
        _stature = double.parse(_secilenSporcu!.boy!) / 100.0; // cm'den m'ye çevir
        _boyController.text = _stature.toString();
      } else {
        _stature = 1.75; // Varsayılan değer (m)
        _boyController.text = "1.75";
      }
      
      // Ölçümleri al
      _olcumler = await _databaseService.getOlcumlerBySporcuId(sporcuId);
      
      // Sadece Sprint ölçümlerini filtrele
      _olcumler = _olcumler.where((olcum) => 
        olcum.olcumTuru.toUpperCase() == 'SPRINT').toList();
      
      if (_olcumler.isEmpty) {
        throw Exception('Sprint ölçümü bulunamadı.');
      }
      
      // Ölçümleri test ID'lerine göre grupla
      _testGruplari = {};
      for (var olcum in _olcumler) {
        if (!_testGruplari.containsKey(olcum.testId)) {
          _testGruplari[olcum.testId] = [];
        }
        _testGruplari[olcum.testId]!.add(olcum);
      }
      
      // Tarihe göre sırala (yeniden eskiye)
      _testGruplari.forEach((testId, olcumler) {
        olcumler.sort((a, b) => b.olcumTarihi.compareTo(a.olcumTarihi));
      });
      
      // TestId'leri listeye çevir ve sırala
      List<int> testIdler = _testGruplari.keys.toList();
      testIdler.sort((a, b) => b.compareTo(a)); // En son test en üstte
      
      if (testIdler.isNotEmpty) {
        setState(() {
          _secilenTestId = testIdler.first;
        });
      }
    } catch (e) {
      _showSnackBar('Hata: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  // Yatay F-V profili hesaplama
  void _calculateHorizontalFVProfile() {
    if (_secilenTestId == null || !_testGruplari.containsKey(_secilenTestId)) {
      _showSnackBar('Lütfen bir test seçin');
      return;
    }
    
    try {
      // Form değerlerini kontrol et
      if (!_validateInputs()) return;
      
      // Sporcu ve test bilgilerini al
      List<Olcum> secilenOlcumler = _testGruplari[_secilenTestId]!;
      
      // Sprint mesafeleri ve zamanlarını al (varsayılan mesafeler)
      _sprintTimes = [];
      _sprintDistances = [];
      
      // Ölçüm verilerini hazırla
      for (int i = 0; i < secilenOlcumler.length; i++) {
        Olcum olcum = secilenOlcumler[i];
        
        for (int j = 1; j <= 7; j++) {
          var kapiDeger = olcum.degerler.firstWhere(
            (d) => d.degerTuru.toUpperCase() == 'KAPI$j',
               orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
          );
          
          if (kapiDeger.deger > 0 && j-1 < _defaultDistances.length) {
            _sprintTimes.add(kapiDeger.deger);
            _sprintDistances.add(_defaultDistances[j-1]);
          }
        }
      }
      
      // Verileri sırala
      var pairs = <MapEntry<double, double>>[];
      for (int i = 0; i < _sprintTimes.length && i < _sprintDistances.length; i++) {
        pairs.add(MapEntry(_sprintDistances[i], _sprintTimes[i]));
      }
      pairs.sort((a, b) => a.key.compareTo(b.key));
      
      _sprintDistances = pairs.map((e) => e.key).toList();
      _sprintTimes = pairs.map((e) => e.value).toList();
      
      // Minimum kapı sayısı kontrolü
      if (_sprintTimes.length < 3) {
        _showSnackBar('En az 3 kapı ölçümü gereklidir');
        return;
      }
      
      // Tau ve Vmax hesapla
      var result = _calculateTauAndVmax(_sprintDistances, _sprintTimes);
      _tau = result.$1;
      _vmax = result.$2;
      
      // Yatay F-V profilini hesapla
      _calculateForceVelocityProfile();
      
      // UI'ı güncelle
      setState(() {});
    } catch (e) {
      _showSnackBar('Hesaplama hatası: $e');
    }
  }
  
  // Girdi validasyonu
  bool _validateInputs() {
    // Vücut kütlesi ve boy kontrolü
    if (!_tryParseDouble(_kuruAgirlikController.text, 'Vücut ağırlığı', 30, 150)) return false;
    if (!_tryParseDouble(_boyController.text, 'Boy', 1.0, 2.5)) return false;
    
    // Basınç ve sıcaklık kontrolü  
    if (!_tryParseDouble(_basincController.text, 'Basınç', 800, 1100)) return false;
    if (!_tryParseDouble(_sicaklikController.text, 'Sıcaklık', -20, 50)) return false;
    
    return true;
  }
  
  // Double dönüşümü ve aralık kontrolü
  bool _tryParseDouble(String value, String fieldName, double min, double max) {
    try {
      double parsed = double.parse(value);
      if (parsed < min || parsed > max) {
        _showSnackBar('$fieldName $min - $max aralığında olmalıdır');
        return false;
      }
      return true;
    } catch (e) {
      _showSnackBar('$fieldName geçerli bir sayı olmalıdır');
      return false;
    }
  }
  
  // Tau ve Vmax hesaplama (Gradyan İniş algoritması ile)
  (double, double) _calculateTauAndVmax(List<double> distances, List<double> times) {
    double initialVmax = (distances.last - distances[distances.length - 2]) / 
                       (times.last - times[times.length - 2]);
    double initialTau = times[0] / math.log(distances[0] / (initialVmax * times[0]));
    
    if (initialTau.isNaN || initialTau <= 0) initialTau = 1.0; // Güvenli başlangıç
    
    double vmax = initialVmax;
    double tau = initialTau;
    double learningRate = 0.001;
    double tolerance = 1e-8;
    int maxIterations = 10000;
    int iteration = 0;
    
    while (iteration < maxIterations) {
      double gradTau = 0;
      double gradVmax = 0;
      
      for (int i = 0; i < distances.length; i++) {
        double t = times[i];
        double expTerm = math.exp(-t / tau);
        double modelPosition = vmax * (t + tau * expTerm - tau);
        double diff = distances[i] - modelPosition;
        
        double dModelDTau = vmax * (expTerm * (1 + t / tau) - 1);
        double dModelDVmax = t + tau * expTerm - tau;
        gradTau += -2 * diff * dModelDTau;
        gradVmax += -2 * diff * dModelDVmax;
      }
      
      double newTau = tau - learningRate * gradTau;
      double newVmax = vmax - learningRate * gradVmax;
      
      // Tau ve Vmax'in geçerli olduğundan emin ol
      if (newTau <= 0 || newTau.isNaN || newTau.isInfinite) {
        newTau = tau;
      }
      
      if (newVmax.isNaN || newVmax.isInfinite) {
        newVmax = vmax;
      }
      
      double tauChange = (newTau - tau).abs();
      double vmaxChange = (newVmax - vmax).abs();
      tau = newTau;
      vmax = newVmax;
      
      if (tauChange < tolerance && vmaxChange < tolerance) {
        break;
      }
      
      iteration++;
    }
    
    // Vmax ve Tau için kontrol ve düzeltme
    if (vmax < 5.0 || vmax > 10.0) {
      _showSnackBar('Uyarı: Hesaplanan Vmax (${vmax.toStringAsFixed(2)} m/s) beklenen aralıkta değil (5-10 m/s). Düzeltme yapılıyor.');
      vmax = math.max(5.0, math.min(vmax, 10.0));
    }
    
    if (tau < 0.5 || tau > 2.0) {
      _showSnackBar('Uyarı: Hesaplanan Tau (${tau.toStringAsFixed(2)} s) beklenen aralıkta değil (0.5-2 s). Düzeltme yapılıyor.');
      tau = math.max(0.5, math.min(tau, 2.0));
    }
    
    return (tau, vmax);
  }
  
  // Kuvvet-Hız profilini hesapla
  void _calculateForceVelocityProfile() {
    final g = 9.81; // Yerçekimi ivmesi (m/s²)
    _bodyMass = double.parse(_kuruAgirlikController.text);
    _stature = double.parse(_boyController.text);
    double pressure = double.parse(_basincController.text);
    double temperature = double.parse(_sicaklikController.text);
    
    _velocities = [];
    _forces = [];
    _powerValues = [];
    List<double> timePoints = [];
    List<double> positionPoints = [];
    List<double> rfValues = [];
    
    double position = 0;
    
    // Zaman noktaları üzerinden hesaplamalar
    for (double t = 0.01; t <= 8.22; t += 0.01) {
      double v = _vmax * (1 - math.exp(-t / _tau));
      double a = (_vmax / _tau) * math.exp(-t / _tau);
      
      timePoints.add(t);
      position = _vmax * (t + _tau * math.exp(-t / _tau) - _tau);
      positionPoints.add(position);
      
      // Hava direnci hesaplama
      double fAir = _calculateAirFriction(_bodyMass, _stature, pressure, temperature, v);
      double fHorizontal = _bodyMass * a + fAir;
      
      double fV = _bodyMass * g;
      double fRes = math.sqrt(fHorizontal * fHorizontal + fV * fV);
      double rf = fHorizontal / fRes;
      rfValues.add(rf);
      
      _velocities.add(v);
      _forces.add(fHorizontal / _bodyMass);
      _powerValues.add(fHorizontal / _bodyMass * v);
    }
    
    // RF max hesaplama (t=0.51'den itibaren)
    _rfmax = rfValues.skip(50).reduce(math.max);
    
    // Drf hesaplama (t=0.01'den t=6.00'a kadar, ilk 600 veri noktası)
    int n = 600;
    var subset = _velocities.take(n).toList();
    var rfSubset = rfValues.take(n).toList();
    
    double sumV = subset.reduce((a, b) => a + b);
    double sumRF = rfSubset.reduce((a, b) => a + b);
    double sumVRF = 0, sumV2 = 0;
    
    for (int i = 0; i < n; i++) {
      sumVRF += subset[i] * rfSubset[i];
      sumV2 += subset[i] * subset[i];
    }
    
    _drf = (n * sumVRF - sumV * sumRF) / (n * sumV2 - sumV * sumV);
    
    // Force-Velocity ilişkisi hesaplama (F-v slope, F0, v0, Pmax)
    n = _velocities.length;
    sumV = _velocities.reduce((a, b) => a + b);
    double sumF = _forces.reduce((a, b) => a + b);
    double sumVF = 0;
    sumV2 = 0;
    
    for (int i = 0; i < n; i++) {
      sumVF += _velocities[i] * _forces[i];
      sumV2 += _velocities[i] * _velocities[i];
    }
    
    _sfv = (n * sumVF - sumV * sumF) / (n * sumV2 - sumV * sumV);
    _f0 = (sumF - _sfv * sumV) / n;
    _v0 = -_f0 / _sfv;
    _pmax = (_f0 * _v0) / 4;
    
    // Optimal Sfv hesaplama
    double k = 0.0031; // Hava sürtünme katsayısı
    double targetDistance = _sprintDistances.last; // Hedef sprint mesafesi
    _sfvOpt = _calculateOptimalSfv(_pmax, targetDistance, k);
    
    // Fv_imb hesaplama
    _fvimb = _sfvOpt.isFinite && _sfvOpt != 0
        ? 100 * (1 - _sfv / _sfvOpt).abs()
        : double.nan;
        
    // R² hesaplama
    _rSquared = _calculateRSquared();
  }
  
  // Hava direnci hesaplama
  double _calculateAirFriction(double bodyMass, double height, double pressure, double temperature, double velocity) {
    const double cd = 0.9; // Sürükleme katsayısı
    const double rho0 = 1.293; // Standart hava yoğunluğu (kg/m³)
    
    // Hava yoğunluğu
    double rho = rho0 * (pressure / 760.0) * (273.0 / (273.0 + temperature));
    
    // Vücut yüzey alanı (Du Bois formülü)
    double af = 0.2025 * math.pow(height, 0.725) * math.pow(bodyMass, 0.425) * 0.266;
    
    // Hava direnci katsayısı
    double k = 0.5 * rho * af * cd;
    
    // Hava direnci hesaplama
    return k * velocity * velocity;
  }
  
  // Optimal Sfv değerini hesapla
  double _calculateOptimalSfv(double pmax, double targetDistance, double k) {
    // Sfv aralığı ve adım büyüklüğü
    double sfvMin = -1.9;  // Minimum Sfv değeri (N s/m kg)
    double sfvMax = -0.03; // Maksimum Sfv değeri (N s/m kg)
    double step = 0.01;    // Adım büyüklüğü
    double bestSfv = sfvMin;
    double minTx = double.maxFinite;
    
    // Grid search ile Tx'i minimize eden Sfv değerini bul
    for (double sfv = sfvMin; sfv <= sfvMax; sfv += step) {
      // Equation 15 ve 16'ya göre vHmax ve tau hesapla
      double sqrtTerm = math.sqrt(-pmax / sfv);
      double sigma2 = sfv - 2 * k * sqrtTerm;
      double vHmax = (2 * math.sqrt(-pmax * sfv)) / sigma2;
      double tau = 1 / sigma2;
      
      // Equation 17'ye göre Tx hesapla (Lambert W fonksiyonu yerine yaklaşık çözüm)
      double term = -(targetDistance + tau * vHmax) / (tau * vHmax);
      double tx = double.maxFinite;
      
      if (term < 0 && term > -math.exp(-1)) { // Lambert W fonksiyonunun geçerli aralığı
        tx = tau * (-math.log(-term)) + (targetDistance + tau * vHmax) / vHmax;
      }
      
      if (tx < minTx && !tx.isNaN && !tx.isInfinite) {
        minTx = tx;
        bestSfv = sfv;
      }
    }
    
    return bestSfv;
  }
  
  // R² hesaplama
  double _calculateRSquared() {
    double meanForce = _forces.reduce((a, b) => a + b) / _forces.length;
    double ssTotal = 0;
    double ssResidual = 0;
    
    for (int i = 0; i < _velocities.length; i++) {
      double actualF = _forces[i];
      double predictedF = _f0 + _sfv * _velocities[i];
      
      ssResidual += math.pow(actualF - predictedF, 2);
      ssTotal += math.pow(actualF - meanForce, 2);
    }
    
    return ssTotal == 0 ? 0 : 1 - (ssResidual / ssTotal);
  }
  
  // Profil değerlendirmesi
  String _getProfileInterpretation() {
    if (_fvimb.isNaN) return "";
    
    String interpretation = "Yatay Kuvvet-Hız Profili Değerlendirmesi (Morin & Samozino, 2015):\n\n";
    
    if (_fvimb > 15) {
      if (_sfv < _sfvOpt) {
        interpretation += "Kuvvet eksikliği: F-V profili optimalden daha az kuvvet odaklı. "
          "Sporcu yüksek hız kapasitesine sahip, ancak bu hızı destekleyecek yeterli yatay kuvvet üretemiyor.\n\n"
          "Öneri: Kuvvet geliştirici egzersizlere odaklanılmalı. Ağır sled antrenmanı, hafif yüklerle patlayıcı squat veya power clean gibi egzersizler önerilir.";
      } else {
        interpretation += "Hız eksikliği: F-V profili optimalden daha az hız odaklı. "
          "Sporcu yüksek yatay kuvvet kapasitesine sahip, ancak bu kuvveti yüksek hızlara dönüştürme yeteneği sınırlı.\n\n"
          "Öneri: Hız geliştirici egzersizlere odaklanılmalı. Plyometrik sıçramalar, hız odaklı sprint çalışmaları önerilir.";
      }
    } else {
      interpretation += "Dengeli Profil: F-V profili optimale yakın. "
        "Sporcu, yatay kuvvet ve hız arasında iyi bir dengeye sahip.\n\n"
        "Öneri: Performansı optimize etmek için dengeli bir antrenman programı uygulanabilir.";
    }
    
    // Daha detaylı analiz
    interpretation += "\n\nDetaylı Analiz:\n";
    interpretation += "• F0 (N/kg): ${_f0.toStringAsFixed(2)}\n";
    interpretation += "• V0 (m/s): ${_v0.toStringAsFixed(2)}\n";
    interpretation += "• Pmax (W/kg): ${_pmax.toStringAsFixed(2)}\n";
    interpretation += "• RFmax: ${_rfmax.toStringAsFixed(4)}\n";
    interpretation += "• DRF: ${(_drf * 100).toStringAsFixed(2)}%\n";
    interpretation += "• FVimb: ${_fvimb.toStringAsFixed(2)}%\n";
    
    return interpretation;
  }
  
  // Tarih formatını düzenle
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
        title: const Text('Yatay Kuvvet-Hız Profili'),
        backgroundColor: const Color(0xFF0288D1),
        actions: [
          // VERİTABANI KAYIT BUTONU
          if (_secilenSporcu != null && _sprintTimes.isNotEmpty && _forces.isNotEmpty)
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
                    if (_testGruplari.isNotEmpty) _buildTestSecimBolumu(),
                    const SizedBox(height: 16),
                    _buildParametrelerForm(),
                    const SizedBox(height: 16),
                    _buildSprintDataTable(),
                    const SizedBox(height: 16),
                    _buildHesaplaButton(),
                    const SizedBox(height: 16),
                    
                    if (_forces.isNotEmpty && _velocities.isNotEmpty) ...[
                      _buildSonuclar(),
                      const SizedBox(height: 16),
                      _buildForceVelocityChart(),
                      const SizedBox(height: 16),
                      _buildPowerCharts(),
                      const SizedBox(height: 16),
                      _buildYorum(),
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
            'Yatay Kuvvet-Hız Profili analizinizi PDF olarak kaydedin veya paylaşın',
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
              _showSnackBar('PDF işlemi başarılı!');
            },
            onError: (error) {
              _showSnackBar('PDF hatası: $error');
            },
          ),
        ],
      ),
    );
  }

  // ========== MEVCUT UI WİDGETLARI (AYNI KALIYOR) ==========
  
  // Sporcu seçim bölümü
  Widget _buildSporcuSecimBolumu() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    _secilenSporcu = _sporcular.firstWhere((sporcu) => sporcu.id == sporcuId);
                  });
                  _loadOlcumler(sporcuId);
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
      ),
    );
  }
  
  // Test seçim bölümü
  Widget _buildTestSecimBolumu() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Test Seçin',
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
             hint: const Text('Test Seçin'),
              value: _secilenTestId,
              onChanged: (testId) {
                if (testId != null) {
                  setState(() {
                    _secilenTestId = testId;
                  });
                }
              },
              items: _testGruplari.keys.map((testId) {
                final olcum = _testGruplari[testId]!.first;
                final tarih = _formatTarih(olcum.olcumTarihi);
                return DropdownMenuItem<int>(
                  value: testId,
                  child: Text('$tarih - Test #$testId'),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
  
  // Parametreler form bölümü
  Widget _buildParametrelerForm() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Parametreler',
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
                  child: TextFormField(
                    controller: _kuruAgirlikController,
                    decoration: const InputDecoration(
                      labelText: 'Vücut Ağırlığı (kg)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _boyController,
                    decoration: const InputDecoration(
                      labelText: 'Boy (m)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _basincController,
                    decoration: const InputDecoration(
                      labelText: 'Basınç (hPa)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _sicaklikController,
                    decoration: const InputDecoration(
                      labelText: 'Sıcaklık (°C)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // YatayProfilScreen için eksik metodlar - dosyanızın sonuna ekleyin

  // Hesapla butonu
  Widget _buildHesaplaButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _calculateHorizontalFVProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0288D1),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Profil Hesapla',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
  
  // Sonuç kartları
  Widget _buildSonuclar() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kuvvet-Hız Profili Sonuçları',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0288D1),
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                _buildResultCard('F0 (N/kg)', _f0, _getF0Color(_f0)),
                _buildResultCard('V0 (m/s)', _v0, _getV0Color(_v0)),
                _buildResultCard('Pmax (W/kg)', _pmax, _getPmaxColor(_pmax)),
                _buildResultCard('Sfv (N.s/m/kg)', _sfv, Colors.blue.withAlpha(70)),
                _buildResultCard('FVimb (%)', _fvimb, _getFvimbColor(_fvimb, _sfv, _sfvOpt)),
                _buildResultCard('RFmax', _rfmax, _getRfmaxColor(_rfmax)),
                _buildResultCard('DRF (%)', _drf * 100, _getDrfColor(_drf)),
                _buildResultCard('R²', _rSquared, _getR2Color(_rSquared)),
                _buildResultCard('Tau (s)', _tau, Colors.lightBlue.withAlpha(70)),
                _buildResultCard('Vmax (m/s)', _vmax, _getVmaxColor(_vmax)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Sonuç kartı bileşeni
  Widget _buildResultCard(String title, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(180)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value.isFinite ? value.toStringAsFixed(2) : '-',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // Kuvvet-Hız profil grafiği
  Widget _buildForceVelocityChart() {
    if (_forces.isEmpty || _velocities.isEmpty) {
      return const SizedBox.shrink();
    }

    double safeMaxV0 = _v0.isFinite && _v0 > 0 ? _v0 * 1.2 : 10.0;
    double safeMaxF0 = _f0.isFinite && _f0 > 0 ? _f0 * 1.2 : 10.0;

    // Optimal değerler hesapla
    double optimalF0 = 0.0;
    double optimalV0 = 0.0;
    if (_sfvOpt.isFinite && !_sfvOpt.isNaN && _pmax.isFinite && !_pmax.isNaN && _pmax > 0) {
      try {
        optimalF0 = 2 * math.sqrt(-_pmax * _sfvOpt);
        optimalV0 = -optimalF0 / _sfvOpt;
        if (optimalF0.isNaN || !optimalF0.isFinite || optimalF0 > safeMaxF0) {
          optimalF0 = safeMaxF0 * 0.8;
        }
        if (optimalV0.isNaN || !optimalV0.isFinite || optimalV0 > safeMaxV0) {
          optimalV0 = safeMaxV0 * 0.8;
        }
      } catch (e) {
        optimalF0 = safeMaxF0 * 0.5;
        optimalV0 = safeMaxV0 * 0.5;
      }
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kuvvet-Hız Profili Grafiği',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0288D1),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 400,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 1,
                    verticalInterval: 2,
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 2,
                        getTitlesWidget: (value, meta) {
                          if (value == value.roundToDouble()) {
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              space: 8,
                              child: Text(
                                value.toInt().toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      axisNameWidget: const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'Hız (m/s)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          if (value == value.roundToDouble()) {
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              space: 8,
                              child: Text(
                                value.toInt().toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      axisNameWidget: const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Kuvvet (N/kg)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
                  borderData: FlBorderData(show: true),
                  minX: 0,
                  maxX: safeMaxV0,
                  minY: 0,
                  maxY: safeMaxF0,
                  lineBarsData: [
                    // Gerçek F-V çizgisi
                    LineChartBarData(
                      spots: [
                        FlSpot(0, _f0.isFinite ? math.min(_f0, safeMaxF0) : 0),
                        FlSpot(_v0.isFinite ? math.min(_v0, safeMaxV0) : 0, 0),
                      ],
                      isCurved: false,
                      color: Colors.blue,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(show: false),
                    ),
                    // Optimal F-V çizgisi
                    LineChartBarData(
                      spots: [
                        FlSpot(0, math.min(optimalF0, safeMaxF0)),
                        FlSpot(math.min(optimalV0, safeMaxV0), 0),
                      ],
                      isCurved: false,
                      color: Colors.red,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(show: false),
                      dashArray: const [5, 5],
                    ),
                    // Veri noktaları
                    LineChartBarData(
                      spots: _sampleDataPoints(_velocities, _forces, 20, safeMaxV0, safeMaxF0),
                      isCurved: false,
                      color: Colors.transparent,
                      barWidth: 0,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 5,
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
      ),
    );
  }

  // Güç grafiği
  Widget _buildPowerCharts() {
    if (_powerValues.isEmpty || _velocities.isEmpty) {
      return const SizedBox.shrink();
    }
    
    double safeMaxVelocity = 0;
    double safeMaxPower = 0;
    
    try {
      double maxVel = _velocities.reduce((a, b) => math.max(a, b));
      double maxPower = _powerValues.reduce((a, b) => math.max(a, b));
      
      safeMaxVelocity = maxVel.isFinite && maxVel > 0 ? maxVel * 1.2 : 10.0;
      safeMaxPower = maxPower.isFinite && maxPower > 0 ? maxPower * 1.2 : 20.0;
    } catch (e) {
      safeMaxVelocity = 10.0;
      safeMaxPower = 20.0;
    }
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Güç Grafikleri',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0288D1),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 2,
                    verticalInterval: 2,
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 2,
                        getTitlesWidget: (value, meta) {
                          if (value == value.roundToDouble()) {
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              space: 8,
                              child: Text(
                                value.toInt().toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      axisNameWidget: const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'Hız (m/s)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 2, 
                        getTitlesWidget: (value, meta) {
                          if (value == value.roundToDouble()) {
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              space: 8,
                              child: Text(
                                value.toInt().toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      axisNameWidget: const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Güç (W/kg)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
                  borderData: FlBorderData(show: true),
                  minX: 0,
                  maxX: safeMaxVelocity,
                  minY: 0,
                  maxY: safeMaxPower,
                  lineBarsData: [
                    LineChartBarData(
                      spots: _sampleDataPoints(_velocities, _powerValues, 30, safeMaxVelocity, safeMaxPower),
                      isCurved: true,
                      color: Colors.red,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.red.withAlpha(25),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Veri noktalarını örnekleme
  List<FlSpot> _sampleDataPoints(List<double> xValues, List<double> yValues, int maxPoints, double maxX, double maxY) {
    if (xValues.isEmpty || yValues.isEmpty || xValues.length != yValues.length) {
      return [];
    }
    
    final spots = <FlSpot>[];
    final n = xValues.length;
    final step = n <= maxPoints ? 1 : n ~/ maxPoints;
    
    for (int i = 0; i < n; i += step) {
      if (xValues[i].isFinite && yValues[i].isFinite) {
        final x = math.min(xValues[i], maxX);
        final y = math.min(yValues[i], maxY);
        spots.add(FlSpot(x, y));
      }
    }
    
    if (n > 0 && (n - 1) % step != 0 && xValues.last.isFinite && yValues.last.isFinite) {
      final x = math.min(xValues.last, maxX);
      final y = math.min(yValues.last, maxY);
      spots.add(FlSpot(x, y));
    }
    
    return spots;
  }

  // Yorum bölümü
  Widget _buildYorum() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Yorum ve Değerlendirme',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0288D1),
              ),
            ),
            const SizedBox(height: 16),
            Text(_getProfileInterpretation()),
          ],
        ),
      ),
    );
  }

  // Renk yardımcı metodları
  Color _getF0Color(double value) {
    if (!value.isFinite) return Colors.grey.withAlpha(70);
    if (value < 6.0) return Colors.red.withAlpha(70);
    if (value < 8.0) return Colors.yellow.withAlpha(70);
    return Colors.green.withAlpha(70);
  }
  
  Color _getV0Color(double value) {
    if (!value.isFinite) return Colors.grey.withAlpha(70);
    if (value < 8.0) return Colors.red.withAlpha(70);
    if (value < 10.0) return Colors.yellow.withAlpha(70);
    return Colors.green.withAlpha(70);
  }
  
  Color _getPmaxColor(double value) {
    if (!value.isFinite) return Colors.grey.withAlpha(70);
    if (value < 14.0) return Colors.red.withAlpha(70);
    if (value < 18.0) return Colors.yellow.withAlpha(70);
    return Colors.green.withAlpha(70);
  }
  
  Color _getFvimbColor(double value, double sfv, double sfvOpt) {
    if (!value.isFinite) return Colors.grey.withAlpha(70);
    
    if (value > 15.0) {
      return sfv < sfvOpt 
          ? Colors.lightBlue.withAlpha(70) // Kuvvet eksikliği
          : Colors.red.withAlpha(70);     // Hız eksikliği
    }
    
    return Colors.green.withAlpha(70); // Optimal
  }
  
  Color _getRfmaxColor(double value) {
    if (!value.isFinite) return Colors.grey.withAlpha(70);
    if (value < 0.40) return Colors.red.withAlpha(70);
    return Colors.green.withAlpha(70);
  }
  
  Color _getDrfColor(double value) {
    if (!value.isFinite) return Colors.grey.withAlpha(70);
    double drfPercent = value * 100;
    if (drfPercent < -6.0) return Colors.red.withAlpha(70);
    if (drfPercent < -3.5) return Colors.yellow.withAlpha(70);
    return Colors.green.withAlpha(70);
  }
  
  Color _getR2Color(double value) {
    if (!value.isFinite) return Colors.grey.withAlpha(70);
    if (value < 0.70) return Colors.red.withAlpha(70);
    if (value < 0.85) return Colors.yellow.withAlpha(70);
    return Colors.green.withAlpha(70);
  }
  
  Color _getVmaxColor(double value) {
    if (!value.isFinite) return Colors.grey.withAlpha(70);
    if (value < 7.5) return Colors.red.withAlpha(70);
    if (value < 9.0) return Colors.yellow.withAlpha(70);
    return Colors.green.withAlpha(70);
  }

  Widget _buildSprintDataTable() {
    if (_secilenTestId == null || !_testGruplari.containsKey(_secilenTestId)) {
      return const SizedBox.shrink();
    }
    
    List<Olcum> secilenOlcumler = _testGruplari[_secilenTestId]!;
    
    // Sprint zamanlarını al
   // Sprint zamanlarını al
List<Map<String, dynamic>> sprintData = [];

for (int i = 0; i < secilenOlcumler.length; i++) {
  Olcum olcum = secilenOlcumler[i];
  Map<String, dynamic> olcumData = {
    'OlcumSirasi': olcum.olcumSirasi,
    'Tarih': _formatTarih(olcum.olcumTarihi),
  };
  
  for (int j = 1; j <= 7; j++) {
    var kapiDeger = olcum.degerler.firstWhere(
      (d) => d.degerTuru.toUpperCase() == 'KAPI$j',
      orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
    );
    
    if (kapiDeger.deger > 0) {
      olcumData['Kapi$j'] = kapiDeger.deger;
      if (j-1 < _defaultDistances.length) {
        olcumData['Mesafe$j'] = _defaultDistances[j-1];
      }
    }
  }
  
  sprintData.add(olcumData);
}

return Card(
  elevation: 4,
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sprint Ölçümleri',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0288D1),
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Ölçüm')),
              DataColumn(label: Text('Tarih')),
              DataColumn(label: Text('Kapı 1')),
              DataColumn(label: Text('Kapı 2')),
              DataColumn(label: Text('Kapı 3')),
              DataColumn(label: Text('Kapı 4')),
              DataColumn(label: Text('Kapı 5')),
              DataColumn(label: Text('Kapı 6')),
              DataColumn(label: Text('Kapı 7')),
            ],
            rows: sprintData.map((data) {
              return DataRow(
                cells: [
                  DataCell(Text('${data['OlcumSirasi']}')),
                  DataCell(Text('${data['Tarih']}')),
                  DataCell(Text(data['Kapi1'] != null ? '${data['Kapi1'].toStringAsFixed(3)}' : '-')),
                  DataCell(Text(data['Kapi2'] != null ? '${data['Kapi2'].toStringAsFixed(3)}' : '-')),
                  DataCell(Text(data['Kapi3'] != null ? '${data['Kapi3'].toStringAsFixed(3)}' : '-')),
                  DataCell(Text(data['Kapi4'] != null ? '${data['Kapi4'].toStringAsFixed(3)}' : '-')),
                  DataCell(Text(data['Kapi5'] != null ? '${data['Kapi5'].toStringAsFixed(3)}' : '-')),
                  DataCell(Text(data['Kapi6'] != null ? '${data['Kapi6'].toStringAsFixed(3)}' : '-')),
                  DataCell(Text(data['Kapi7'] != null ? '${data['Kapi7'].toStringAsFixed(3)}' : '-')),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    ),
  ),
);
}
}