import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/sporcu_model.dart';
import '../models/olcum_model.dart';
import '../services/database_service.dart';

class LoadVelocityProfileScreen extends StatefulWidget {
  const LoadVelocityProfileScreen({super.key});

  @override
  State<LoadVelocityProfileScreen> createState() => _LoadVelocityProfileScreenState();
}

class _LoadVelocityProfileScreenState extends State<LoadVelocityProfileScreen> {
  final _databaseService = DatabaseService();
  Sporcu? _secilenSporcu;
  List<Sporcu> _sporcular = [];
  List<Olcum> _tumOlcumler = [];
  
  // Çoklu seçim için
  final List<Olcum> _secilenOlcumler = [];
  final Set<int> _secilenOlcumIds = {};
  
  // Form controller'ları
  final _vucutAgirligiController = TextEditingController();
  final _maksimalHizController = TextEditingController();
  
  // Load-Velocity profil parametreleri
  double _bodyMass = 0.0;
  double _maxVelocity = 0.0;
  double _slope = 0.0; // Eğim (a)
  double _intercept = 0.0; // Y-kesim (b)
  double _l0 = 0.0; // Teorik sprint 1RM
  double _rSquared = 0.0;
  
  // Test verileri
  List<double> _testLoads = []; // Test yükleri (kg)
  List<double> _testVelocities = []; // Maksimal hızlar (m/s)
  
  // %vDec tablosu için hesaplanan değerler
  Map<double, Map<String, double>> _vDecTable = {};
  
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadSporcular();
  }
  
  @override
  void dispose() {
    _vucutAgirligiController.dispose();
    _maksimalHizController.dispose();
    super.dispose();
  }
  
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
      
      // Vücut ağırlığı bilgisini ayarla
      if (_secilenSporcu!.kilo != null && _secilenSporcu!.kilo!.isNotEmpty) {
        _bodyMass = double.parse(_secilenSporcu!.kilo!);
        _vucutAgirligiController.text = _bodyMass.toString();
      } else {
        _bodyMass = 70.0; // Varsayılan değer
        _vucutAgirligiController.text = "70.0";
      }
      
      // Tüm ölçümleri al
      _tumOlcumler = await _databaseService.getOlcumlerBySporcuId(sporcuId);
      
      // Sprint ölçümlerini filtrele
      _tumOlcumler = _tumOlcumler.where((olcum) => 
        olcum.olcumTuru.toUpperCase() == 'SPRINT' ||
        olcum.olcumTuru.toUpperCase().contains('RESISTED') || 
        olcum.olcumTuru.toUpperCase().contains('SLED') ||
        olcum.olcumTuru.toUpperCase().contains('LOAD')).toList();
      
      if (_tumOlcumler.isEmpty) {
        throw Exception('Sprint ölçümü bulunamadı.');
      }
      
      // Seçimleri sıfırla
      _secilenOlcumler.clear();
      _secilenOlcumIds.clear();
      
      // Tarihe göre sırala (yeniden eskiye)
      _tumOlcumler.sort((a, b) => b.olcumTarihi.compareTo(a.olcumTarihi));
      
    } catch (e) {
      _showSnackBar('Hata: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message))
      );
    }
  }
  
  // Ölçüm seçimi toggle
  void _toggleOlcumSelection(Olcum olcum) {
    setState(() {
      if (_secilenOlcumIds.contains(olcum.id)) {
        _secilenOlcumIds.remove(olcum.id);
        _secilenOlcumler.removeWhere((o) => o.id == olcum.id);
      } else {
        _secilenOlcumIds.add(olcum.id!); // Non-null assertion eklendi
        _secilenOlcumler.add(olcum);
      }
    });
  }
  
  // Tümünü seç/seçme
  void _toggleSelectAll() {
    setState(() {
      if (_secilenOlcumIds.length == _tumOlcumler.length) {
        // Tümünü kaldır
        _secilenOlcumIds.clear();
        _secilenOlcumler.clear();
      } else {
        // Tümünü seç
        _secilenOlcumIds.clear();
        _secilenOlcumler.clear();
        for (var olcum in _tumOlcumler) {
          _secilenOlcumIds.add(olcum.id!); // Non-null assertion eklendi
          _secilenOlcumler.add(olcum);
        }
      }
    });
  }
  
  // Load-Velocity profili hesaplama
  void _calculateLoadVelocityProfile() {
    if (_secilenOlcumler.length < 2) {
      _showSnackBar('En az 2 ölçüm seçmelisiniz');
      return;
    }
    
    try {
      // Form değerlerini kontrol et
      if (!_validateInputs()) return;
      
      // Test verilerini hazırla
      _prepareTestData();
      
      // Minimum veri kontrolü
      if (_testLoads.length < 2) {
        _showSnackBar('En az 2 farklı yük ölçümü gereklidir');
        return;
      }
      
      // Load-Velocity lineer regresyon hesapla
      _calculateLinearRegression();
      
      // %vDec tablosunu oluştur
      _calculateVDecTable();
      
      // UI'ı güncelle
      setState(() {});
    } catch (e) {
      _showSnackBar('Hesaplama hatası: $e');
    }
  }
  
  // Test verilerini hazırla
  void _prepareTestData() {
    _testLoads = [];
    _testVelocities = [];
    
    for (var olcum in _secilenOlcumler) {
      // Yük bilgisini al
      double yukDegeri = _getLoadValue(olcum);
      
      // Split zamanlarını al ve hızları hesapla
      List<double> splitTimes = [];
      for (int j = 1; j <= 6; j++) {
        var kapiDeger = olcum.degerler.firstWhere(
          (d) => d.degerTuru.toUpperCase() == 'KAPI$j',
          orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
        );
        
        if (kapiDeger.deger > 0) {
          splitTimes.add(kapiDeger.deger);
        }
      }
      
      if (splitTimes.isNotEmpty) {
        // Maksimal hızı hesapla
        double maxVel = _calculateMaxVelocity(splitTimes);
        if (maxVel > 0) {
          _testLoads.add(yukDegeri);
          _testVelocities.add(maxVel);
        }
      }
    }
    
    // Verileri yüke göre sırala
    var pairs = <MapEntry<double, double>>[];
    for (int i = 0; i < _testLoads.length; i++) {
      pairs.add(MapEntry(_testLoads[i], _testVelocities[i]));
    }
    pairs.sort((a, b) => a.key.compareTo(b.key));
    
    _testLoads = pairs.map((e) => e.key).toList();
    _testVelocities = pairs.map((e) => e.value).toList();
    
    // Maksimal hızı güncelle (yüksüz sprint)
    if (_testVelocities.isNotEmpty) {
      _maxVelocity = _testVelocities.first; // İlk değer yüksüz olmalı
      _maksimalHizController.text = _maxVelocity.toStringAsFixed(2);
    }
  }
  
  // Yük değerini al
  double _getLoadValue(Olcum olcum) {
    // Önce özel yük alanlarını kontrol et
    var yukDeger = olcum.degerler.firstWhere(
      (d) => d.degerTuru.toUpperCase().contains('LOAD') || 
             d.degerTuru.toUpperCase().contains('WEIGHT') ||
             d.degerTuru.toUpperCase().contains('YUK') ||
             d.degerTuru.toUpperCase().contains('SLED'),
      orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
    );
    
    if (yukDeger.deger > 0) {
      return yukDeger.deger;
    }
    
    // Eğer yük bilgisi yoksa ölçüm sırasına göre varsayılan yükler
    switch (olcum.olcumSirasi) {
      case 1: return 0; // Yüksüz
      case 2: return 25;
      case 3: return 50;
      case 4: return 75;
      case 5: return 100;
      default: return olcum.olcumSirasi * 25.0;
    }
  }
  
  // Maksimal hız hesapla
  double _calculateMaxVelocity(List<double> splitTimes) {
    List<double> splitVelocities = [];
    
    // İlk split (0-5m)
    if (splitTimes.isNotEmpty && splitTimes[0] > 0) {
      double velocity = 5.0 / splitTimes[0];
      if (velocity.isFinite && velocity > 0) {
        splitVelocities.add(velocity);
      }
    }
    
    // Diğer split'ler (5m increments)
    for (int i = 1; i < splitTimes.length; i++) {
      double splitTime = splitTimes[i] - splitTimes[i-1];
      if (splitTime > 0) {
        double velocity = 5.0 / splitTime;
        if (velocity.isFinite && velocity > 0) {
          splitVelocities.add(velocity);
        }
      }
    }
    
    return splitVelocities.isNotEmpty ? splitVelocities.reduce(math.max) : 0.0;
  }
  
  // Lineer regresyon hesapla
  void _calculateLinearRegression() {
    if (_testLoads.length < 2 || _testVelocities.length < 2) return;
    
    int n = _testLoads.length;
    double sumX = _testLoads.reduce((a, b) => a + b);
    double sumY = _testVelocities.reduce((a, b) => a + b);
    double sumXY = 0.0;
    double sumX2 = 0.0;
    
    for (int i = 0; i < n; i++) {
      sumXY += _testLoads[i] * _testVelocities[i];
      sumX2 += _testLoads[i] * _testLoads[i];
    }
    
    // Eğim ve Y-kesim hesapla
    _slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    _intercept = (sumY - _slope * sumX) / n;
    
    // Teorik sprint 1RM (L0) hesapla - hızın sıfır olduğu yük
    _l0 = -_intercept / _slope;
    
    // R² hesapla
    double meanY = sumY / n;
    double ssTotal = 0.0;
    double ssResidual = 0.0;
    
    for (int i = 0; i < n; i++) {
      double predictedY = _slope * _testLoads[i] + _intercept;
      ssResidual += math.pow(_testVelocities[i] - predictedY, 2);
      ssTotal += math.pow(_testVelocities[i] - meanY, 2);
    }
    
    _rSquared = ssTotal == 0 ? 0 : 1 - (ssResidual / ssTotal);
  }
  
  // %vDec tablosunu hesapla
  void _calculateVDecTable() {
    _vDecTable = {};
    
    // Maksimal hızı güncelle
    if (_maksimalHizController.text.isNotEmpty) {
      _maxVelocity = double.parse(_maksimalHizController.text);
    }
    
    // %vDec değerleri için hesaplamalar
    List<double> vDecPercentages = [10, 20, 25, 30, 40, 50, 60, 70, 75, 100];
    
    for (double vDecPercent in vDecPercentages) {
      // Hedef hız hesapla
      double targetVelocity = _maxVelocity - (_maxVelocity * vDecPercent / 100);
      
      // Gerekli yük hesapla: Load = (targetVelocity - intercept) / slope
      double requiredLoad = (targetVelocity - _intercept) / _slope;
      
      // Vücut ağırlığı oranı hesapla
      double bodyWeightRatio = _bodyMass > 0 ? requiredLoad / _bodyMass : 0;
      
      _vDecTable[vDecPercent] = {
        'targetVelocity': targetVelocity,
        'requiredLoad': requiredLoad,
        'bodyWeightRatio': bodyWeightRatio,
      };
    }
  }
  
  // Antrenman kategorisi belirleme
  String _getTrainingCategory(double vDecPercent) {
    if (vDecPercent <= 10) return 'Technical Competency';
    if (vDecPercent <= 30) return 'Speed-Strength';
    if (vDecPercent <= 60) return 'Power';
    return 'Strength-Speed';
  }
  
  // Girdi validasyonu
  bool _validateInputs() {
    if (!_tryParseDouble(_vucutAgirligiController.text, 'Vücut ağırlığı', 30, 150)) return false;
    if (_maksimalHizController.text.isNotEmpty) {
      if (!_tryParseDouble(_maksimalHizController.text, 'Maksimal hız', 5, 15)) return false;
    }
    return true;
  }
  
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
  
  // Profil değerlendirmesi
  String _getProfileInterpretation() {
    if (_testLoads.isEmpty || _testVelocities.isEmpty) return "";
    
    String interpretation = "Load-Velocity Profili Değerlendirmesi (Morin & Samozino):\n\n";
    
    interpretation += "Lineer Regresyon Analizi:\n";
    interpretation += "• Eğim (Slope): ${_slope.toStringAsFixed(4)} m/s/kg\n";
    interpretation += "• Y-kesim (Intercept): ${_intercept.toStringAsFixed(2)} m/s\n";
    interpretation += "• R²: ${_rSquared.toStringAsFixed(3)}\n";
    interpretation += "• Teorik Sprint 1RM (L0): ${_l0.toStringAsFixed(1)} kg\n";
    interpretation += "• Analiz edilen ölçüm sayısı: ${_secilenOlcumler.length}\n\n";
    
    // R² değerlendirmesi
    if (_rSquared >= 0.90) {
      interpretation += "Mükemmel lineer ilişki (R² ≥ 0.90)\n";
    } else if (_rSquared >= 0.80) {
      interpretation += "İyi lineer ilişki (R² ≥ 0.80)\n";
    } else if (_rSquared >= 0.70) {
      interpretation += "Kabul edilebilir lineer ilişki (R² ≥ 0.70)\n";
    } else {
      interpretation += "Zayıf lineer ilişki (R² < 0.70) - Ek ölçümler gerekebilir\n";
    }
    
    interpretation += "\nAntrenman Önerileri:\n";
    interpretation += "• Power (%50 vDec): ${_vDecTable[50]?['requiredLoad']?.toStringAsFixed(1) ?? 'N/A'} kg\n";
    interpretation += "• Speed-Strength (%20 vDec): ${_vDecTable[20]?['requiredLoad']?.toStringAsFixed(1) ?? 'N/A'} kg\n";
    interpretation += "• Strength-Speed (%70 vDec): ${_vDecTable[70]?['requiredLoad']?.toStringAsFixed(1) ?? 'N/A'} kg\n";
    
    return interpretation;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Load-Velocity Profili'),
        backgroundColor: const Color(0xFF0288D1),
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
                    if (_tumOlcumler.isNotEmpty) _buildOlcumSecimBolumu(),
                    const SizedBox(height: 16),
                    _buildParametrelerForm(),
                    const SizedBox(height: 16),
                    _buildHesaplaButton(),
                    const SizedBox(height: 16),
                    
                    if (_testLoads.isNotEmpty && _testVelocities.isNotEmpty) ...[
                      _buildSonuclar(),
                      const SizedBox(height: 16),
                      _buildLoadVelocityChart(),
                      const SizedBox(height: 16),
                      _buildVDecTable(),
                      const SizedBox(height: 16),
                      _buildYorum(),
                    ],
                  ],
                ],
              ),
            ),
    );
  }
  
  // UI Bileşenleri
  
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
  
  Widget _buildOlcumSecimBolumu() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ölçüm Seçimi (En az 2 adet)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0288D1),
                  ),
                ),
                TextButton(
                  onPressed: _toggleSelectAll,
                  child: Text(
                    _secilenOlcumIds.length == _tumOlcumler.length ? 'Hiçbirini Seçme' : 'Tümünü Seç',
                    style: const TextStyle(color: Color(0xFF0288D1)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Seçilen: ${_secilenOlcumler.length}/${_tumOlcumler.length}',
              style: TextStyle(
                color: _secilenOlcumler.length >= 2 ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: _tumOlcumler.length,
                itemBuilder: (context, index) {
                  final olcum = _tumOlcumler[index];
                  final isSelected = _secilenOlcumIds.contains(olcum.id);
                  final yukDegeri = _getLoadValue(olcum);
                  
                  return Card(
                    elevation: isSelected ? 4 : 1,
                    color: isSelected ? const Color(0xFF0288D1).withAlpha(20) : null,
                    child: CheckboxListTile(
                      value: isSelected,
                      onChanged: (bool? value) {
                        _toggleOlcumSelection(olcum);
                      },
                      title: Text(
                        'Test #${olcum.testId} - Ölçüm ${olcum.olcumSirasi}',
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tarih: ${_formatTarih(olcum.olcumTarihi)}'),
                          Text('Yük: ${yukDegeri.toStringAsFixed(0)} kg'),
                          Text('Tür: ${olcum.olcumTuru}'),
                        ],
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: const Color(0xFF0288D1),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
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
                    controller: _vucutAgirligiController,
                    decoration: const InputDecoration(
                      labelText: 'Vücut Ağırlığı (kg)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        _bodyMass = double.tryParse(value) ?? 0.0;
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _maksimalHizController,
                    decoration: const InputDecoration(
                      labelText: 'Maksimal Hız (m/s)',
                      border: OutlineInputBorder(),
                      hintText: 'Otomatik hesaplanır',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        _maxVelocity = double.tryParse(value) ?? 0.0;
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHesaplaButton() {
    final bool canCalculate = _secilenOlcumler.length >= 2;
    
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: canCalculate ? _calculateLoadVelocityProfile : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canCalculate ? const Color(0xFF0288D1) : Colors.grey,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          canCalculate 
              ? 'Load-Velocity Profili Hesapla (${_secilenOlcumler.length} ölçüm)'
              : 'En az 2 ölçüm seçin',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
  
  Widget _buildSonuclar() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Load-Velocity Profili Sonuçları',
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
                _buildResultCard('Eğim (m/s/kg)', _slope, _getSlopeColor(_slope)),
                _buildResultCard('Y-kesim (m/s)', _intercept, _getInterceptColor(_intercept)),
                _buildResultCard('Sprint 1RM (kg)', _l0, _getL0Color(_l0)),
                _buildResultCard('R²', _rSquared, _getR2Color(_rSquared)),
                _buildResultCard('Max Hız (m/s)', _maxVelocity, _getMaxVelColor(_maxVelocity)),
                _buildResultCard('Ölçüm Sayısı', _secilenOlcumler.length.toDouble(), Colors.blue.withAlpha(70)),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
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
  
  // Renk yardımcı metodları
  Color _getSlopeColor(double value) {
    if (!value.isFinite) return Colors.grey.withAlpha(70);
    // Negatif eğim beklenir (yük arttıkça hız azalır)
    if (value > -0.02) return Colors.red.withAlpha(70); // Çok az azalma
    if (value > -0.05) return Colors.yellow.withAlpha(70); // Orta azalma
    return Colors.green.withAlpha(70); // İyi azalma
  }
  
  Color _getInterceptColor(double value) {
    if (!value.isFinite) return Colors.grey.withAlpha(70);
    if (value < 7.0) return Colors.red.withAlpha(70);
    if (value < 9.0) return Colors.yellow.withAlpha(70);
    return Colors.green.withAlpha(70);
  }
  
  Color _getL0Color(double value) {
    if (!value.isFinite) return Colors.grey.withAlpha(70);
    if (value < 100) return Colors.red.withAlpha(70);
    if (value < 200) return Colors.yellow.withAlpha(70);
    return Colors.green.withAlpha(70);
  }
  
  Color _getR2Color(double value) {
    if (!value.isFinite) return Colors.grey.withAlpha(70);
    if (value < 0.70) return Colors.red.withAlpha(70);
    if (value < 0.85) return Colors.yellow.withAlpha(70);
    return Colors.green.withAlpha(70);
  }
  
  Color _getMaxVelColor(double value) {
    if (!value.isFinite) return Colors.grey.withAlpha(70);
    if (value < 7.0) return Colors.red.withAlpha(70);
    if (value < 9.0) return Colors.yellow.withAlpha(70);
    return Colors.green.withAlpha(70);
  }
  
  Widget _buildLoadVelocityChart() {
    if (_testLoads.isEmpty || _testVelocities.isEmpty) {
      return const SizedBox.shrink();
    }

    double maxLoad = _testLoads.reduce(math.max) * 1.2;
    double maxVel = _testVelocities.reduce(math.max) * 1.2;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Load-Velocity Profili Grafiği',
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
                    verticalInterval: 20,
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 20,
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
                          'Yük (kg)',
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
                          'Hız (m/s)',
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
                  maxX: maxLoad,
                  minY: 0,
                  maxY: maxVel,
                  lineBarsData: [
                    // Lineer regresyon çizgisi
                    LineChartBarData(
                      spots: [
                        FlSpot(0, _intercept.isFinite ? math.max(0, _intercept) : 0),
                        FlSpot(_l0.isFinite && _l0 > 0 ? math.min(_l0, maxLoad) : maxLoad, 0),
                      ],
                      isCurved: false,
                      color: Colors.red,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: false),
                    ),
                    // Veri noktaları
                    LineChartBarData(
                      spots: _testLoads.asMap().entries.map((entry) {
                        return FlSpot(entry.value, _testVelocities[entry.key]);
                      }).toList(),
                      isCurved: false,
                      color: Colors.transparent,
                      barWidth: 0,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 6,
                          color: Colors.blue,
                          strokeWidth: 2,
                          strokeColor: Colors.blue.shade800,
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
  
  Widget _buildVDecTable() {
    if (_vDecTable.isEmpty) return const SizedBox.shrink();
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '%vDec Tablosu - Antrenman Yükleri',
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
                  DataColumn(label: Text('%vDec')),
                  DataColumn(label: Text('Hedef Hız (m/s)')),
                  DataColumn(label: Text('Gerekli Yük (kg)')),
                  DataColumn(label: Text('Vücut Ağırlığı (%)')),
                  DataColumn(label: Text('Kategori')),
                ],
                rows: _vDecTable.entries.map((entry) {
                  double vDecPercent = entry.key;
                  Map<String, double> values = entry.value;
                  String category = _getTrainingCategory(vDecPercent);
                  
                  Color rowColor = _getCategoryColor(category);
                  
                  return DataRow(
                    color: MaterialStateProperty.all(rowColor),
                    cells: [
                      DataCell(Text('${vDecPercent.toStringAsFixed(0)}%')),
                      DataCell(Text(values['targetVelocity']?.toStringAsFixed(2) ?? '-')),
                      DataCell(Text(values['requiredLoad']?.toStringAsFixed(1) ?? '-')),
                      DataCell(Text('${(values['bodyWeightRatio']! * 100).toStringAsFixed(0)}%')),
                      DataCell(Text(category)),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            _buildCategoryLegend(),
          ],
        ),
      ),
    );
  }
  
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Technical Competency':
        return Colors.green.withAlpha(40);
      case 'Speed-Strength':
        return Colors.blue.withAlpha(40);
      case 'Power':
        return Colors.orange.withAlpha(40);
      case 'Strength-Speed':
        return Colors.red.withAlpha(40);
      default:
        return Colors.grey.withAlpha(40);
    }
  }
  
  Widget _buildCategoryLegend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Antrenman Kategorileri:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildLegendItem('Technical Competency (≤10% vDec)', 'Teknik yetkinlik, hareket kalitesi', Colors.green),
        _buildLegendItem('Speed-Strength (11-30% vDec)', 'Hız-kuvvet, explosive güç', Colors.blue),
        _buildLegendItem('Power (31-60% vDec)', 'Maksimal güç geliştirme', Colors.orange),
        _buildLegendItem('Strength-Speed (>60% vDec)', 'Kuvvet-hız, yüksek kuvvet', Colors.red),
      ],
    );
  }
  
  Widget _buildLegendItem(String title, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color.withAlpha(40),
              border: Border.all(color: color),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 12),
                children: [
                  TextSpan(
                    text: title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: ': $description'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
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
}