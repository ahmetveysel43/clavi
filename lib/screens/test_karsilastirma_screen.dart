import 'package:flutter/material.dart';
import '../models/sporcu_model.dart';
import '../models/olcum_model.dart';
import '../services/database_service.dart';
import 'package:fl_chart/fl_chart.dart';

class TestKarsilastirmaScreen extends StatefulWidget {
  final int sporcuId;
  final String testType;

  const TestKarsilastirmaScreen({
    super.key, // super parameter kullanımı
    required this.sporcuId,
    required this.testType,
  });

  @override
  TestKarsilastirmaScreenState createState() => TestKarsilastirmaScreenState(); // private type düzeltildi
}

class TestKarsilastirmaScreenState extends State<TestKarsilastirmaScreen> with TickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  List<Olcum> _olcumler = [];
  Olcum? _secilenOlcum1;
  Olcum? _secilenOlcum2;
  bool _isLoading = true;
  Sporcu? _sporcu;
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      
      final sporcuFuture = _databaseService.getSporcu(widget.sporcuId);
      final olcumlerFuture = _databaseService.getOlcumlerBySporcuId(widget.sporcuId);
      
      final results = await Future.wait([sporcuFuture, olcumlerFuture]);
      
      _sporcu = results[0] as Sporcu;
      final tumOlcumler = results[1] as List<Olcum>;
      
      _olcumler = tumOlcumler
          .where((o) => o.olcumTuru.toUpperCase() == widget.testType.toUpperCase())
          .toList();
      
      _olcumler.sort((a, b) => b.olcumTarihi.compareTo(a.olcumTarihi));
      
      if (_olcumler.length >= 2) {
        _secilenOlcum1 = _olcumler[0];
        _secilenOlcum2 = _olcumler[1];
      } else if (_olcumler.length == 1) {
        _secilenOlcum1 = _olcumler[0];
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veriler yüklenirken hata: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  String _formatDate(String dateString) {
    try {
      DateTime date;
      if (dateString.contains('T')) {
        date = DateTime.parse(dateString);
      } else {
        final parts = dateString.split('.');
        if (parts.length >= 3) {
          date = DateTime(
            int.parse(parts[2].split(' ')[0]), 
            int.parse(parts[1]), 
            int.parse(parts[0])
          );
        } else {
          date = DateTime.now();
        }
      }
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    } catch (e) {
      debugPrint("Tarih biçimlendirme hatası: $e, input: $dateString");
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Test Karşılaştırma - ${widget.testType}'),
        backgroundColor: _getTestTypeColor(widget.testType),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart), text: 'Görsel'),
            Tab(icon: Icon(Icons.table_chart), text: 'Detay'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _olcumler.length < 2
              ? _buildYetersizOlcumMesaji()
              : _buildKarsilastirmaEkrani(),
    );
  }
  
  Widget _buildYetersizOlcumMesaji() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.compare_arrows, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Karşılaştırma için en az 2 test gerekli',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Geri Dön'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildKarsilastirmaEkrani() {
    return Column(
      children: [
        _buildSporcuVeSecimBolumu(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildGorselKarsilastirma(),
              _buildDetayliKarsilastirma(),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildSporcuVeSecimBolumu() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1), // withValues kullanıldı
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSporcuBilgisi(),
          const Divider(height: 1),
          _buildTestSecimAlani(),
        ],
      ),
    );
  }
  
  Widget _buildSporcuBilgisi() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _getTestTypeColor(widget.testType).withValues(alpha: 0.2),
            radius: 24,
            child: Icon(_getTestTypeIcon(widget.testType), color: _getTestTypeColor(widget.testType)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_sporcu?.ad ?? ''} ${_sporcu?.soyad ?? ''}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_sporcu?.yas ?? ''} yaş • ${_sporcu?.brans ?? 'Bilinmeyen'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getTestTypeColor(widget.testType).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_olcumler.length} Test',
              style: TextStyle(
                color: _getTestTypeColor(widget.testType),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTestSecimAlani() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildTestDropdown(
              label: '1. Test (Mavi)',
              value: _secilenOlcum1?.id,
              color: Colors.blue,
              onChanged: (olcumId) {
                if (olcumId != null) {
                  setState(() {
                    _secilenOlcum1 = _olcumler.firstWhere((o) => o.id == olcumId);
                    if (_secilenOlcum2?.id == olcumId) {
                      final otherTests = _olcumler.where((o) => o.id != olcumId).toList();
                      _secilenOlcum2 = otherTests.isNotEmpty ? otherTests.first : null;
                    }
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildTestDropdown(
              label: '2. Test (Turuncu)',
              value: _secilenOlcum2?.id,
              color: Colors.orange,
              onChanged: (olcumId) {
                if (olcumId != null) {
                  setState(() {
                    _secilenOlcum2 = _olcumler.firstWhere((o) => o.id == olcumId);
                    if (_secilenOlcum1?.id == olcumId) {
                      final otherTests = _olcumler.where((o) => o.id != olcumId).toList();
                      _secilenOlcum1 = otherTests.isNotEmpty ? otherTests.first : null;
                    }
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTestDropdown({
    required String label,
    required int? value,
    required Color color,
    required void Function(int?)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: DropdownButton<int>(
            value: value,
            isExpanded: true,
            underline: Container(),
            hint: const Text('Test Seçin'),
            items: _olcumler.map((olcum) {
              return DropdownMenuItem<int>(
                value: olcum.id,
                child: Text('${_formatDate(olcum.olcumTarihi)} - ${olcum.olcumSirasi}. Ölçüm'),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
  
  Widget _buildGorselKarsilastirma() {
    if (_secilenOlcum1 == null || _secilenOlcum2 == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Görsel karşılaştırma için iki test seçin',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildKarsilastirmaBaslik(),
          const SizedBox(height: 20),
          if (widget.testType.toUpperCase() == 'SPRINT')
            _buildModernSprintGrafik()
          else
            _buildModernJumpGrafik(),
          const SizedBox(height: 20),
          _buildPerformansOzeti(),
        ],
      ),
    );
  }

  Widget _buildModernSprintGrafik() {
    final kapiDegerler1 = <int, double>{};
    final kapiDegerler2 = <int, double>{};
    
    for (int i = 1; i <= 7; i++) {
      final kapi1 = _secilenOlcum1!.degerler.firstWhere(
        (d) => d.degerTuru.toUpperCase() == 'KAPI$i',
        orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
      );
      
      final kapi2 = _secilenOlcum2!.degerler.firstWhere(
        (d) => d.degerTuru.toUpperCase() == 'KAPI$i',
        orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
      );
      
      if (kapi1.deger != 0) kapiDegerler1[i] = kapi1.deger;
      if (kapi2.deger != 0) kapiDegerler2[i] = kapi2.deger;
    }
    
    final kapiMesafeleri = [0, 5, 10, 15, 20, 30, 40];
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: _getTestTypeColor(widget.testType)),
                const SizedBox(width: 8),
                const Text(
                  'Sprint Zaman Profili',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Mesafe-zaman ilişkisi karşılaştırması',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 300,
              child: _buildSprintLineChart(kapiDegerler1, kapiDegerler2, kapiMesafeleri),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSprintLineChart(
    Map<int, double> kapiDegerler1,
    Map<int, double> kapiDegerler2,
    List<int> kapiMesafeleri,
  ) {
    final spots1 = <FlSpot>[];
    final spots2 = <FlSpot>[];
    
    for (int i = 1; i <= 7; i++) {
      if (kapiDegerler1.containsKey(i)) {
        spots1.add(FlSpot(kapiMesafeleri[i - 1].toDouble(), kapiDegerler1[i]!));
      }
      if (kapiDegerler2.containsKey(i)) {
        spots2.add(FlSpot(kapiMesafeleri[i - 1].toDouble(), kapiDegerler2[i]!));
      }
    }
    
    spots1.sort((a, b) => a.x.compareTo(b.x));
    spots2.sort((a, b) => a.x.compareTo(b.x));
    
    // Y ekseni için akıllı aralık hesaplama
    final allYValues = [...spots1.map((s) => s.y), ...spots2.map((s) => s.y)];
    final minY = allYValues.isNotEmpty ? allYValues.reduce((a, b) => a < b ? a : b) : 0;
    final maxY = allYValues.isNotEmpty ? allYValues.reduce((a, b) => a > b ? a : b) : 10;
    final yRange = maxY - minY;
    final adjustedMaxY = maxY + yRange * 0.1;
    final yInterval = (adjustedMaxY - (minY - yRange * 0.1).clamp(0, double.infinity)) / 5;
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          drawHorizontalLine: true,
          verticalInterval: 10,
          horizontalInterval: yInterval,
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Colors.grey.withValues(alpha: 0.2),
              strokeWidth: 1,
            );
          },
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withValues(alpha: 0.2),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 10,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${value.toInt()}m',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '${value.toStringAsFixed(1)}s',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
              reservedSize: 45,
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
            bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
          ),
        ),
        minX: 0,
        maxX: 40,
        minY: (minY - yRange * 0.1).clamp(0, double.infinity),
        maxY: adjustedMaxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots1,
            isCurved: true,
            curveSmoothness: 0.3,
            color: Colors.blue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 5,
                color: Colors.blue,
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withValues(alpha: 0.1),
            ),
          ),
          LineChartBarData(
            spots: spots2,
            isCurved: true,
            curveSmoothness: 0.3,
            color: Colors.orange,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 5,
                color: Colors.orange,
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.orange.withValues(alpha: 0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: Colors.black87,
            tooltipRoundedRadius: 8,
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((LineBarSpot touchedSpot) {
                final testName = touchedSpot.barIndex == 0 ? '1. Test' : '2. Test';
                return LineTooltipItem(
                  '$testName\n${touchedSpot.x.toInt()}m: ${touchedSpot.y.toStringAsFixed(2)}s',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildModernJumpGrafik() {
    final metrikler = _getJumpMetrics();
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, color: _getTestTypeColor(widget.testType)),
                const SizedBox(width: 8),
                const Text(
                  'Performans Metrikleri',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Ana performans göstergelerinin karşılaştırması',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 300,
              child: _buildJumpBarChart(metrikler),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, Map<String, double>> _getJumpMetrics() {
    final metrikler = <String, Map<String, double>>{};
    
    // Yükseklik
    final yukseklik1 = _secilenOlcum1!.degerler.firstWhere(
      (d) => d.degerTuru.toLowerCase() == 'yukseklik',
      orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
    );
    final yukseklik2 = _secilenOlcum2!.degerler.firstWhere(
      (d) => d.degerTuru.toLowerCase() == 'yukseklik',
      orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
    );
    
    // Uçuş Süresi
    final ucusSuresi1 = _secilenOlcum1!.degerler.firstWhere(
      (d) => d.degerTuru.toLowerCase() == 'ucussuresi',
      orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
    );
    final ucusSuresi2 = _secilenOlcum2!.degerler.firstWhere(
      (d) => d.degerTuru.toLowerCase() == 'ucussuresi',
      orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
    );
    
    // Güç
    final guc1 = _secilenOlcum1!.degerler.firstWhere(
      (d) => d.degerTuru.toLowerCase() == 'guc',
      orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
    );
    final guc2 = _secilenOlcum2!.degerler.firstWhere(
      (d) => d.degerTuru.toLowerCase() == 'guc',
      orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
    );
    
    // .toDouble() eklenerek explicit dönüşüm yapıldı
    metrikler['Yükseklik (cm)'] = {
      'test1': yukseklik1.deger.toDouble(), 
      'test2': yukseklik2.deger.toDouble()
    };
    metrikler['Uçuş Süresi (s)'] = {
      'test1': (ucusSuresi1.deger * 1000).toDouble(), 
      'test2': (ucusSuresi2.deger * 1000).toDouble()
    };
    metrikler['Güç (W)'] = {
      'test1': (guc1.deger / 100).toDouble(), 
      'test2': (guc2.deger / 100).toDouble()
    };
    
    // DJ ve RJ için ek metrikler
    if (widget.testType.toUpperCase() == 'DJ' || widget.testType.toUpperCase() == 'RJ') {
      final temasSuresi1 = _secilenOlcum1!.degerler.firstWhere(
        (d) => d.degerTuru.toLowerCase() == 'temassuresi',
        orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
      );
      final temasSuresi2 = _secilenOlcum2!.degerler.firstWhere(
        (d) => d.degerTuru.toLowerCase() == 'temassuresi',
        orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
      );
      
      final rsi1 = _secilenOlcum1!.degerler.firstWhere(
        (d) => d.degerTuru.toLowerCase() == 'rsi',
        orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
      );
      final rsi2 = _secilenOlcum2!.degerler.firstWhere(
        (d) => d.degerTuru.toLowerCase() == 'rsi',
        orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
      );
      
      metrikler['Temas Süresi (ms)'] = {
        'test1': (temasSuresi1.deger * 1000).toDouble(), 
        'test2': (temasSuresi2.deger * 1000).toDouble()
      };
      metrikler['RSI'] = {
        'test1': (rsi1.deger * 10).toDouble(), 
        'test2': (rsi2.deger * 10).toDouble()
      };
    }
    
    return metrikler;
  }

  Widget _buildJumpBarChart(Map<String, Map<String, double>> metrikler) {
    final metrikListesi = metrikler.keys.toList();
    
    // Y ekseni için akıllı aralık hesaplama
    final allValues = metrikler.values.expand((m) => m.values).toList();
    final maxValue = allValues.isNotEmpty ? allValues.reduce((a, b) => a > b ? a : b) : 100;
    final adjustedMaxY = maxValue * 1.2;
    final yInterval = adjustedMaxY / 5;
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: adjustedMaxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.black87,
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final metrikAdi = metrikListesi[groupIndex];
              final testAdi = rodIndex == 0 ? '1. Test' : '2. Test';
              String deger = rod.toY.toStringAsFixed(1);
              
              // Orijinal değerleri göster
              if (metrikAdi.contains('Uçuş Süresi')) {
                deger = (rod.toY / 1000).toStringAsFixed(3);
              } else if (metrikAdi.contains('Güç')) {
                deger = (rod.toY * 100).toStringAsFixed(0);
              } else if (metrikAdi.contains('Temas Süresi')) {
                deger = (rod.toY / 1000).toStringAsFixed(3);
              } else if (metrikAdi.contains('RSI')) {
                deger = (rod.toY / 10).toStringAsFixed(2);
              }
              
              return BarTooltipItem(
                '$testAdi\n$metrikAdi\n$deger',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < metrikListesi.length) {
                  final metrik = metrikListesi[value.toInt()];
                  final kisaMetrik = metrik.split(' ')[0]; // İlk kelimeyi al
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      kisaMetrik,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return const Text('');
              },
              reservedSize: 40,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    value.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
              reservedSize: 35,
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withValues(alpha: 0.2),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
            bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
          ),
        ),
        barGroups: List.generate(
          metrikListesi.length,
          (index) {
            final metrikAdi = metrikListesi[index];
            final degerler = metrikler[metrikAdi]!;
            
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: degerler['test1']!.toDouble(), // Hata düzeltildi
                  color: Colors.blue,
                  width: 16,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                BarChartRodData(
                  toY: degerler['test2']!.toDouble(), // Hata düzeltildi
                  color: Colors.orange,
                  width: 16,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ],
              barsSpace: 4,
            );
          },
        ),
      ),
    );
  }

  Widget _buildKarsilastirmaBaslik() {
    final tarih1 = _formatDate(_secilenOlcum1!.olcumTarihi);
    final tarih2 = _formatDate(_secilenOlcum2!.olcumTarihi);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.withValues(alpha: 0.1), Colors.orange.withValues(alpha: 0.1)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTestBaslikKarti(
              '1. Test',
              tarih1,
              _secilenOlcum1!.olcumSirasi.toString(),
              Colors.blue,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'VS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildTestBaslikKarti(
              '2. Test',
              tarih2,
              _secilenOlcum2!.olcumSirasi.toString(),
              Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestBaslikKarti(String testAdi, String tarih, String sira, Color renk) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: renk.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: renk,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                testAdi,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: renk,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            tarih,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
          Text(
            '$sira. Ölçüm',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformansOzeti() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: _getTestTypeColor(widget.testType)),
                const SizedBox(width: 8),
                const Text(
                  'Performans Özeti',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.testType.toUpperCase() == 'SPRINT')
              _buildSprintOzeti()
            else
              _buildJumpOzeti(),
          ],
        ),
      ),
    );
  }

  Widget _buildSprintOzeti() {
    final kapi7_1 = _secilenOlcum1!.degerler.firstWhere(
      (d) => d.degerTuru.toUpperCase() == 'KAPI7',
      orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
    );
    
    final kapi7_2 = _secilenOlcum2!.degerler.firstWhere(
      (d) => d.degerTuru.toUpperCase() == 'KAPI7',
      orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
    );
    
    final fark = kapi7_2.deger - kapi7_1.deger;
    final yuzde = kapi7_1.deger != 0 ? (fark / kapi7_1.deger) * 100 : 0;
    
    final iyilesti = fark < 0; // Sprint'te düşük süre iyidir
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildOzetKarti(
                '1. Test (40m)',
                '${kapi7_1.deger.toStringAsFixed(2)} s',
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildOzetKarti(
                '2. Test (40m)',
                '${kapi7_2.deger.toStringAsFixed(2)} s',
                Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: iyilesti ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: iyilesti ? Colors.green.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                iyilesti ? Icons.trending_up : Icons.trending_down,
                color: iyilesti ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      iyilesti ? 'Performans İyileşmesi' : 'Performans Değişimi',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: iyilesti ? Colors.green : Colors.orange,
                      ),
                    ),
                    Text(
                      '${fark.abs().toStringAsFixed(3)} saniye (${yuzde.abs().toStringAsFixed(1)}%) ${iyilesti ? 'iyileşme' : 'düşüş'}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildJumpOzeti() {
    final yukseklik1 = _secilenOlcum1!.degerler.firstWhere(
      (d) => d.degerTuru.toLowerCase() == 'yukseklik',
      orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
    );
    
    final yukseklik2 = _secilenOlcum2!.degerler.firstWhere(
      (d) => d.degerTuru.toLowerCase() == 'yukseklik',
      orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
    );
    
    final fark = yukseklik2.deger - yukseklik1.deger;
    final yuzde = yukseklik1.deger != 0 ? (fark / yukseklik1.deger) * 100 : 0;
    
    final iyilesti = fark > 0; // Sıçramada yüksek değer iyidir
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildOzetKarti(
                '1. Test',
                '${yukseklik1.deger.toStringAsFixed(1)} cm',
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildOzetKarti(
                '2. Test',
                '${yukseklik2.deger.toStringAsFixed(1)} cm',
                Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: iyilesti ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: iyilesti ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                iyilesti ? Icons.trending_up : Icons.trending_down,
                color: iyilesti ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      iyilesti ? 'Performans İyileşmesi' : 'Performans Düşüşü',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: iyilesti ? Colors.green : Colors.red,
                      ),
                    ),
                    Text(
                      '${fark.abs().toStringAsFixed(1)} cm (${yuzde.abs().toStringAsFixed(1)}%) ${iyilesti ? 'artış' : 'azalış'}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOzetKarti(String baslik, String deger, Color renk) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: renk.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            baslik,
            style: TextStyle(
              fontSize: 14,
              color: renk,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            deger,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: renk,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetayliKarsilastirma() {
    if (_secilenOlcum1 == null || _secilenOlcum2 == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.table_chart, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Detaylı karşılaştırma için iki test seçin',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (widget.testType.toUpperCase() == 'SPRINT')
            _buildSprintDetayTablo()
          else
            _buildJumpDetayTablo(),
        ],
      ),
    );
  }

  Widget _buildSprintDetayTablo() {
    final kapiDegerler1 = <int, double>{};
    final kapiDegerler2 = <int, double>{};
    
    for (int i = 1; i <= 7; i++) {
      final kapi1 = _secilenOlcum1!.degerler.firstWhere(
        (d) => d.degerTuru.toUpperCase() == 'KAPI$i',
        orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
      );
      
      final kapi2 = _secilenOlcum2!.degerler.firstWhere(
        (d) => d.degerTuru.toUpperCase() == 'KAPI$i',
        orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
      );
      
      if (kapi1.deger != 0) kapiDegerler1[i] = kapi1.deger;
      if (kapi2.deger != 0) kapiDegerler2[i] = kapi2.deger;
    }
    
    final kapiMesafeleri = [0, 5, 10, 15, 20, 30, 40];
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kapı Zamanları',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Table(
              border: TableBorder.all(color: Colors.grey.withValues(alpha: 0.3)),
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1)),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Kapı', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('1. Test', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('2. Test', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Fark', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                ...List.generate(7, (index) {
                  final kapiNo = index + 1;
                  final deger1 = kapiDegerler1[kapiNo] ?? 0;
                  final deger2 = kapiDegerler2[kapiNo] ?? 0;
                  final fark = deger2 - deger1;
                  final farkColor = fark < 0 ? Colors.green : Colors.red;
                  
                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('${kapiMesafeleri[index]}m'),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          deger1 != 0 ? '${deger1.toStringAsFixed(3)}s' : '-',
                          style: const TextStyle(color: Colors.blue),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          deger2 != 0 ? '${deger2.toStringAsFixed(3)}s' : '-',
                          style: const TextStyle(color: Colors.orange),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          deger1 != 0 && deger2 != 0 ? '${fark.toStringAsFixed(3)}s' : '-',
                          style: TextStyle(
                            color: farkColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJumpDetayTablo() {
    final metrikler = [
      {'ad': 'Yükseklik', 'turu': 'yukseklik', 'birim': 'cm'},
      {'ad': 'Uçuş Süresi', 'turu': 'ucussuresi', 'birim': 's'},
      {'ad': 'Güç', 'turu': 'guc', 'birim': 'W'},
      if (widget.testType.toUpperCase() == 'DJ' || widget.testType.toUpperCase() == 'RJ') 
        ...[ // spread operator düzeltildi
          {'ad': 'Temas Süresi', 'turu': 'temassuresi', 'birim': 's'},
          {'ad': 'RSI', 'turu': 'rsi', 'birim': ''},
        ],
    ];
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Performans Metrikleri',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Table(
              border: TableBorder.all(color: Colors.grey.withValues(alpha: 0.3)),
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1)),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Metrik', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('1. Test', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('2. Test', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Değişim', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                ...metrikler.map((metrik) {
                  final deger1Obj = _secilenOlcum1!.degerler.firstWhere(
                    (d) => d.degerTuru.toLowerCase() == metrik['turu'],
                    orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
                  );
                  
                  final deger2Obj = _secilenOlcum2!.degerler.firstWhere(
                    (d) => d.degerTuru.toLowerCase() == metrik['turu'],
                    orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
                  );
                  
                  final deger1 = deger1Obj.deger;
                  final deger2 = deger2Obj.deger;
                  final fark = deger2 - deger1;
                  final yuzde = deger1 != 0 ? (fark / deger1) * 100 : 0;
                  
                  // İyileşme durumunu belirle
                  bool iyilesti = false;
                  if (metrik['turu'] == 'temassuresi') {
                    iyilesti = fark < 0; // Temas süresi düşük olması iyidir
                  } else {
                    iyilesti = fark > 0; // Diğerleri yüksek olması iyidir
                  }
                  
                  final degisimColor = iyilesti ? Colors.green : Colors.red;
                  
                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('${metrik['ad']} (${metrik['birim']})'),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          deger1 != 0 ? deger1.toStringAsFixed(metrik['birim'] == 's' ? 3 : metrik['birim'] == 'W' ? 0 : 1) : '-',
                          style: const TextStyle(color: Colors.blue),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          deger2 != 0 ? deger2.toStringAsFixed(metrik['birim'] == 's' ? 3 : metrik['birim'] == 'W' ? 0 : 1) : '-',
                          style: const TextStyle(color: Colors.orange),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          deger1 != 0 && deger2 != 0 ? '${yuzde.toStringAsFixed(1)}%' : '-',
                          style: TextStyle(
                            color: degisimColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getTestTypeColor(String testType) {
    switch (testType.toUpperCase()) {
      case 'SPRINT': return const Color(0xFFE57373);
      case 'CMJ': return const Color(0xFF64B5F6);
      case 'SJ': return const Color(0xFF81C784);
      case 'DJ': return const Color(0xFFFFB74D);
      case 'RJ': return const Color(0xFFA1887F);
      default: return Colors.grey;
    }
  }

  IconData _getTestTypeIcon(String testType) {
    switch (testType.toUpperCase()) {
      case 'SPRINT': return Icons.directions_run;
      case 'CMJ': return Icons.height;
      case 'SJ': return Icons.height;
      case 'DJ': return Icons.height;
      case 'RJ': return Icons.height;
      default: return Icons.analytics;
    }
  }
}