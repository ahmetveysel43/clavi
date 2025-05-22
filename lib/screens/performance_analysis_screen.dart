import 'package:flutter/material.dart';
import '../models/sporcu_model.dart';
import '../models/olcum_model.dart';
import '../services/database_service.dart';
import '../services/performance_analysis_service.dart';
import '../utils/performance_visualization_helper.dart';

class PerformanceAnalysisScreen extends StatefulWidget {
  final int? sporcuId;
  final String? olcumTuru;
  
  const PerformanceAnalysisScreen({
    Key? key,
    this.sporcuId,
    this.olcumTuru,
  }) : super(key: key);

  @override
  _PerformanceAnalysisScreenState createState() => _PerformanceAnalysisScreenState();
}

class _PerformanceAnalysisScreenState extends State<PerformanceAnalysisScreen> {
  final _databaseService = DatabaseService();
  final _performanceService = PerformanceAnalysisService();
  
  bool _isLoading = true;
  Sporcu? _secilenSporcu;
  List<Sporcu> _sporcular = [];
  String _secilenOlcumTuru = '';
  String _secilenDegerTuru = '';
  
  // Analiz sonuçları
  Map<String, dynamic>? _analysis;
  
  // Filtre seçenekleri
  final List<String> _olcumTurleri = ['Sprint', 'CMJ', 'SJ', 'DJ', 'RJ'];
  Map<String, List<String>> _degerTurleri = {
    'Sprint': ['Kapi1', 'Kapi2', 'Kapi3', 'Kapi4', 'Kapi5', 'Kapi6', 'Kapi7'],
    'CMJ': ['Yukseklik', 'UcusSuresi', 'Guc'],
    'SJ': ['Yukseklik', 'UcusSuresi', 'Guc'],
    'DJ': ['Yukseklik', 'UcusSuresi', 'Guc', 'TemasSuresi', 'RSI'],
    'RJ': ['Yukseklik', 'UcusSuresi', 'Guc', 'TemasSuresi', 'RSI', 'Ritim'],
  };
  
  // Zaman aralığı filtresi
  String _selectedTimeRange = 'Son 90 Gün';
  final List<String> _timeRanges = ['Son 30 Gün', 'Son 90 Gün', 'Son 6 Ay', 'Son 1 Yıl', 'Tümü'];
  int _selectedDays = 90;
  
  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }
  
  Future<void> _loadInitialData() async {
    try {
      setState(() => _isLoading = true);
      
      // Tüm sporcuları yükle
      _sporcular = await _databaseService.getAllSporcular();
      
      // Başlangıçta bir sporcu ve ölçüm türü seçili mi kontrol et
      if (widget.sporcuId != null) {
        _secilenSporcu = await _databaseService.getSporcu(widget.sporcuId!);
      } else if (_sporcular.isNotEmpty) {
        _secilenSporcu = _sporcular.first;
      }
      
      if (widget.olcumTuru != null && _olcumTurleri.contains(widget.olcumTuru)) {
        _secilenOlcumTuru = widget.olcumTuru!;
      } else if (_olcumTurleri.isNotEmpty) {
        _secilenOlcumTuru = _olcumTurleri.first;
      }
      
      // Varsayılan değer türünü seç
      if (_secilenOlcumTuru.isNotEmpty && _degerTurleri.containsKey(_secilenOlcumTuru)) {
        _secilenDegerTuru = _degerTurleri[_secilenOlcumTuru]!.first;
      }
      
      // Eğer sporcu ve ölçüm türü seçiliyse, analizi başlat
      if (_secilenSporcu != null && _secilenOlcumTuru.isNotEmpty && _secilenDegerTuru.isNotEmpty) {
        await _loadAnalysis();
      }
    } catch (e) {
      _showSnackBar('Veriler yüklenirken hata: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _loadAnalysis() async {
    if (_secilenSporcu == null || _secilenOlcumTuru.isEmpty || _secilenDegerTuru.isEmpty) {
      return;
    }
    
    try {
      setState(() => _isLoading = true);
      
      // Performans analizini yükle
      _analysis = await _performanceService.getPerformanceSummary(
        sporcuId: _secilenSporcu!.id!,
        olcumTuru: _secilenOlcumTuru,
        degerTuru: _secilenDegerTuru,
        lastNDays: _selectedDays,
      );
      
    } catch (e) {
      _showSnackBar('Analiz yüklenirken hata: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }
  
  void _onTimeRangeChanged(String? value) {
    if (value == null) return;
    
    setState(() {
      _selectedTimeRange = value;
      
      // Gün sayısını güncelle
      switch (value) {
        case 'Son 30 Gün':
          _selectedDays = 30;
          break;
        case 'Son 90 Gün':
          _selectedDays = 90;
          break;
        case 'Son 6 Ay':
          _selectedDays = 180;
          break;
        case 'Son 1 Yıl':
          _selectedDays = 365;
          break;
        case 'Tümü':
          _selectedDays = 3650; // ~10 yıl (tümü için)
          break;
      }
      
      // Yeni zaman aralığına göre analizi yeniden yükle
      _loadAnalysis();
    });
  }
  
  void _onSporcuChanged(int? sporcuId) {
    if (sporcuId == null) return;
    
    setState(() {
      _secilenSporcu = _sporcular.firstWhere((s) => s.id == sporcuId);
      _analysis = null; // Analizleri temizle
    });
    
    _loadAnalysis();
  }
  
  void _onOlcumTuruChanged(String? olcumTuru) {
    if (olcumTuru == null || olcumTuru == _secilenOlcumTuru) return;
    
    setState(() {
      _secilenOlcumTuru = olcumTuru;
      
      // Ölçüm türü değiştiğinde, ilgili değer türlerini güncelle
      if (_degerTurleri.containsKey(_secilenOlcumTuru)) {
        _secilenDegerTuru = _degerTurleri[_secilenOlcumTuru]!.first;
      }
      
      _analysis = null; // Analizleri temizle
    });
    
    _loadAnalysis();
  }
  
  void _onDegerTuruChanged(String? degerTuru) {
    if (degerTuru == null || degerTuru == _secilenDegerTuru) return;
    
    setState(() {
      _secilenDegerTuru = degerTuru;
      _analysis = null; // Analizleri temizle
    });
    
    _loadAnalysis();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performans Analizi'),
        backgroundColor: const Color(0xFF0288D1),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalysis,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSelectionSection(),
                  const SizedBox(height: 16),
                  _buildTimeRangeFilter(),
                  const SizedBox(height: 16),
                  if (_analysis != null && !_analysis!.containsKey('error'))
                    _buildAnalysisResults()
                  else if (_analysis != null && _analysis!.containsKey('error'))
                    _buildErrorMessage(_analysis!['error'])
                  else
                    _buildEmptyState(),
                ],
              ),
            ),
    );
  }
  
  Widget _buildSelectionSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Analiz Parametreleri',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0288D1),
              ),
            ),
            const SizedBox(height: 16),
            
            // Sporcu seçimi
            DropdownButtonFormField<int>(
              decoration: InputDecoration(
                labelText: 'Sporcu',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.person),
              ),
              value: _secilenSporcu?.id,
              onChanged: _onSporcuChanged,
              items: _sporcular.map((s) {
                return DropdownMenuItem<int>(
                  value: s.id,
                  child: Text('${s.ad} ${s.soyad} (${s.yas} yaş)'),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 16),
            
            // Ölçüm ve değer türü seçimi
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Ölçüm Türü',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.category),
                    ),
                    value: _secilenOlcumTuru,
                    onChanged: _onOlcumTuruChanged,
                    items: _olcumTurleri.map((ot) {
                      return DropdownMenuItem<String>(
                        value: ot,
                        child: Text(ot),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Değer Türü',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.timeline),
                    ),
                    value: _secilenDegerTuru,
                    onChanged: _onDegerTuruChanged,
                    items: _degerTurleri[_secilenOlcumTuru]?.map((dt) {
                      return DropdownMenuItem<String>(
                        value: dt,
                        child: Text(dt),
                      );
                    }).toList() ?? [],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTimeRangeFilter() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.date_range, color: Color(0xFF0288D1)),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Zaman Aralığı',
                  border: InputBorder.none,
                ),
                value: _selectedTimeRange,
                onChanged: _onTimeRangeChanged,
                items: _timeRanges.map((tr) {
                  return DropdownMenuItem<String>(
                    value: tr,
                    child: Text(tr),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAnalysisResults() {
    // Birim belirle
    String unit = '';
    bool isHigherBetter = true;
    
    switch (_secilenDegerTuru) {
      case 'Yukseklik':
        unit = 'cm';
        isHigherBetter = true;
        break;
      case 'UcusSuresi':
        unit = 's';
        isHigherBetter = true;
        break;
      case 'Guc':
        unit = 'W';
        isHigherBetter = true;
        break;
      case 'TemasSuresi':
        unit = 's';
        isHigherBetter = false; // Düşük temas süresi daha iyidir
        break;
      case 'Kapi1':
      case 'Kapi2':
      case 'Kapi3':
      case 'Kapi4':
      case 'Kapi5':
      case 'Kapi6':
      case 'Kapi7':
        unit = 's';
        isHigherBetter = false; // Düşük sprint zamanı daha iyidir
        break;
      default:
        break;
    }
    
    // Analiz sonuçlarını ayıkla
    final performanceValues = _analysis!['performanceValues'] as List<double>;
    final dates = _analysis!['dates'] as List<String>;
    
    // Varsayılan değerler
    double? swc = _analysis!['swc'] as double?;
    double? mdc;
    
    // Güvenilirlik verilerini yükle
    _databaseService.getTestGuvenilirlik(
      olcumTuru: _secilenOlcumTuru,
      degerTuru: _secilenDegerTuru,
    ).then((value) {
      if (value != null) {
        setState(() {
          mdc = value['MDC95'] as double?;
          
          // SWC değerini güvenilirlik verisinden kullan
          if (value['SWC'] != null) {
            swc = value['SWC'] as double;
          }
        });
      }
    });
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Performans Özeti Kartı
        PerformanceVisualizationHelper.buildPerformanceSummaryCard(
          analysis: _analysis!,
          title: 'Performans Özeti',
          unit: unit,
          color: const Color(0xFF0288D1),
          isHigherBetter: isHigherBetter,
        ),
        
        const SizedBox(height: 24),
        
        // Performans Trendi Grafiği
        PerformanceVisualizationHelper.buildPerformanceTrendChart(
          performanceValues: performanceValues,
          dates: dates,
          swc: swc,
          mdc: mdc,
          isHigherBetter: isHigherBetter,
          title: 'Performans Trendi',
          yAxisLabel: '$_secilenDegerTuru ($unit)',
          lineColor: const Color(0xFF0288D1),
        ),
        
        const SizedBox(height: 24),
        
        // Değişim Analizi (ilk ve son ölçümler)
        if (performanceValues.length >= 2)
          PerformanceVisualizationHelper.buildPerformanceChangeCard(
            preValue: performanceValues.first,
            postValue: performanceValues.last,
            swc: swc,
            mdc: mdc,
            isHigherBetter: isHigherBetter,
            label: 'İlk-Son Değişim',
            unit: unit,
            color: const Color(0xFF0288D1),
          ),
          
        const SizedBox(height: 24),
        
        // Gelişim Yorumu
        _buildDevelopmentComment(
          performanceValues: performanceValues,
          swc: swc,
          mdc: mdc,
          isHigherBetter: isHigherBetter,
        ),
      ],
    );
  }
  
  Widget _buildDevelopmentComment({
    required List<double> performanceValues,
    double? swc,
    double? mdc,
    required bool isHigherBetter,
  }) {
    if (performanceValues.length < 2) {
      return const SizedBox.shrink();
    }
    
    final firstValue = performanceValues.first;
    final lastValue = performanceValues.last;
    final change = lastValue - firstValue;
    final percentChange = (change / firstValue) * 100;
    
    // Değişimin yönü
    final isPositiveChange = isHigherBetter ? change > 0 : change < 0;
    
    // Değişimin anlamlılığı
    bool isSignificantChange = false;
    if (mdc != null) {
      isSignificantChange = change.abs() > mdc;
    }
    
    // Değişimin pratik anlamlılığı
    bool isPracticallyMeaningful = false;
    if (swc != null) {
      isPracticallyMeaningful = change.abs() > swc;
    }
    
    // Yorum metni
    String comment = '';
    
    if (isPositiveChange) {
      if (isSignificantChange && isPracticallyMeaningful) {
        comment = 'Sporcu ${percentChange.abs().toStringAsFixed(1)}% oranında anlamlı ve pratik olarak değerli bir gelişim göstermiştir. Bu gelişim, hem ölçüm hatasının ötesinde (>MDC) hem de minimal değerli değişimin üzerindedir (>SWC).';
      } else if (isSignificantChange) {
        comment = 'Sporcu ${percentChange.abs().toStringAsFixed(1)}% oranında anlamlı bir gelişim göstermiştir. Bu gelişim ölçüm hatasının ötesindedir (>MDC), ancak minimal değerli değişimin altında kalabilir.';
      } else if (isPracticallyMeaningful) {
        comment = 'Sporcu ${percentChange.abs().toStringAsFixed(1)}% oranında pratik olarak değerli bir değişim göstermiştir (>SWC), ancak bu değişim ölçüm hatası sınırları içinde olabilir.';
      } else {
        comment = 'Sporcu ${percentChange.abs().toStringAsFixed(1)}% oranında bir değişim göstermiştir, ancak bu değişim ne ölçüm hatasının ötesinde ne de minimal değerli değişim eşiğinin üzerindedir.';
      }
    } else {
      if (isSignificantChange && isPracticallyMeaningful) {
        comment = 'Sporcu performansında ${percentChange.abs().toStringAsFixed(1)}% oranında anlamlı ve pratik olarak önemli bir düşüş gözlemlenmiştir. Bu düşüş, hem ölçüm hatasının ötesinde (>MDC) hem de minimal değerli değişimin üzerindedir (>SWC).';
      } else if (isSignificantChange) {
        comment = 'Sporcu performansında ${percentChange.abs().toStringAsFixed(1)}% oranında anlamlı bir düşüş gözlemlenmiştir. Bu düşüş ölçüm hatasının ötesindedir (>MDC).';
      } else if (isPracticallyMeaningful) {
        comment = 'Sporcu performansında ${percentChange.abs().toStringAsFixed(1)}% oranında praktik olarak önemli bir değişim gözlemlenmiştir (>SWC), ancak bu değişim ölçüm hatası sınırları içinde olabilir.';
      } else {
        comment = 'Sporcu performansında ${percentChange.abs().toStringAsFixed(1)}% oranında bir değişim gözlemlenmiştir, ancak bu değişim ne ölçüm hatasının ötesinde ne de minimal değerli değişim eşiğinin üzerindedir.';
      }
    }
    
    // Momentum yorum
    final momentum = _analysis!['momentum'] as double? ?? 0;
    if (momentum.abs() > 5) {
      final momentumDirection = momentum > 0 ? 'yükseliş' : 'düşüş';
      comment += '\n\nSon dönemde ${momentum.abs().toStringAsFixed(1)}% oranında bir $momentumDirection momentumu gözlemlenmektedir.';
    }
    
    // Tutarlılık yorum
    final typicalityIndex = _analysis!['typicalityIndex'] as double? ?? 0;
    if (typicalityIndex >= 70) {
      comment += '\n\nSporcu oldukça tutarlı bir performans sergilemektedir (Tutarlılık: ${typicalityIndex.toStringAsFixed(0)}/100).';
    } else if (typicalityIndex >= 40 && typicalityIndex < 70) {
      comment += '\n\nSporcu orta düzeyde tutarlı bir performans sergilemektedir (Tutarlılık: ${typicalityIndex.toStringAsFixed(0)}/100).';
    } else {
      comment += '\n\nSporcu performansında önemli dalgalanmalar görülmektedir (Tutarlılık: ${typicalityIndex.toStringAsFixed(0)}/100).';
    }
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Performans Değerlendirmesi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0288D1),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              comment,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildErrorMessage(String error) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              error,
              style: TextStyle(color: Colors.red[800]),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Lütfen analiz için bir sporcu ve ölçüm türü seçin',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}