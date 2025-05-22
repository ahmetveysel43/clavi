import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/sporcu_model.dart';
import '../models/olcum_model.dart';
import '../services/database_service.dart';
import 'dikey_profil_screen.dart';
import 'yatay_profil_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'ilerleme_raporu_screen.dart';
import 'test_karsilastirma_screen.dart';
import '../utils/olcum_paylasim_helper.dart';
import 'performance_analysis_screen.dart';



Future<List<Olcum>> computeOlcumler(List<Olcum> olcumler) async {
  return await compute(_processOlcumler, olcumler);
}

List<Olcum> _processOlcumler(List<Olcum> olcumler) {
  // Ölçüm verilerini işleme mantığı
  return olcumler;
}

class AnalizScreen extends StatefulWidget {
  final int? initialSporcuId;
  
  const AnalizScreen({Key? key, this.initialSporcuId}) : super(key: key);

  @override
  _AnalizScreenState createState() => _AnalizScreenState();
}

class _AnalizScreenState extends State<AnalizScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<Sporcu> _sporcular = [];
  Sporcu? _secilenSporcu;
  List<Olcum> _olcumler = [];
  Map<String, List<Olcum>> _olcumGruplari = {};
  bool _isLoading = true;
  String _selectedTestType = 'Tümü';
  
  // Filtreleme seçenekleri
  final List<String> _testTypes = ['Tümü', 'Sprint', 'CMJ', 'SJ', 'DJ', 'RJ'];
  String _selectedDateFilter = 'Tümü';
  final List<String> _dateFilters = ['Tümü', 'Son 7 Gün', 'Son 30 Gün', 'Son 3 Ay', 'Son 6 Ay', 'Son 1 Yıl'];
  
  // İstatistik değerleri
  int _toplamTest = 0;
  int _sprintTestSayisi = 0;
  int _sicramaTestSayisi = 0;
  
  // Seçilen test detayları
  
  @override
  void initState() {
    super.initState();
    _loadSporcular().then((_) {
      if (widget.initialSporcuId != null) {
        _secilenSporcu = _sporcular.firstWhere(
  (sporcu) => sporcu.id == widget.initialSporcuId,
  orElse: () => _sporcular.first,
);
        
        if (_secilenSporcu != null) {
          _loadOlcumler(_secilenSporcu!.id!);
        }
      }
    });
  }
Widget _buildFiltreler() {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Filtreler',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                // Test türü filtreleme
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _testTypes.length, // _testTypes değişkenini kullan
                    itemBuilder: (context, index) {
                      final testType = _testTypes[index];
                      final isSelected = _selectedTestType == testType;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8, left: 8),
                        child: ChoiceChip(
                          label: Text(testType),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedTestType = testType);
                            }
                          },
                          selectedColor: const Color(0xFF0288D1),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Future<void> _loadSporcular() async {
  try {
    setState(() => _isLoading = true);
    
    // Sporcuları yükle
    final sporcuList = await _databaseService.getAllSporcular();
    
    // Null olmayan sporcuları filtrele (iyi bir önlem)
    final filteredList = sporcuList.where((s) => s.id != null).toList();
    
    // Değişiklikleri state'e yansıt
    if (mounted) {
      setState(() {
        _sporcular = filteredList;
        _isLoading = false;
      });
    }
    
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sporcular yüklenirken hata: $e')),
      );
      setState(() => _isLoading = false);
    }
  }
}

     Future<void> _loadOlcumler(int sporcuId) async {
  try {
    setState(() => _isLoading = true);
    
    // Paralel veri çekme işlemleri
    final sporcuFuture = _databaseService.getSporcu(sporcuId);
    final olcumlerFuture = _databaseService.getOlcumlerBySporcuId(sporcuId);
    
    // Tüm Future'ları bekleyin
    final results = await Future.wait([sporcuFuture, olcumlerFuture]);
    
    _secilenSporcu = results[0] as Sporcu;
    _olcumler = results[1] as List<Olcum>;
    
    // Tarihe göre sıralama (en yeniler üstte)
    _olcumler.sort((a, b) => b.olcumTarihi.compareTo(a.olcumTarihi));
    
    // Diğer işlemler...
    _applyDateFilter();
    _groupTestsByType();
    _calculateStats();
    
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ölçümler yüklenirken hata: $e')),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}
  
  void _applyDateFilter() {
    if (_selectedDateFilter == 'Tümü') {
      return; // Filtreleme yapma
    }
    
    final now = DateTime.now();
    DateTime startDate;
    
    switch (_selectedDateFilter) {
      case 'Son 7 Gün':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'Son 30 Gün':
        startDate = now.subtract(const Duration(days: 30));
        break;
      case 'Son 3 Ay':
        startDate = DateTime(now.year, now.month - 3, now.day);
        break;
      case 'Son 6 Ay':
        startDate = DateTime(now.year, now.month - 6, now.day);
        break;
      case 'Son 1 Yıl':
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        return;
    }
    
    _olcumler = _olcumler.where((olcum) {
      try {
        final olcumDate = DateTime.parse(olcum.olcumTarihi);
        return olcumDate.isAfter(startDate);
      } catch (e) {
        return true; // Tarih ayrıştırılamazsa dahil et
      }
    }).toList();
  }
  
  void _groupTestsByType() {
    _olcumGruplari = {};
    
    for (var olcum in _olcumler) {
      final type = olcum.olcumTuru.toUpperCase();
      if (!_olcumGruplari.containsKey(type)) {
        _olcumGruplari[type] = [];
      }
      _olcumGruplari[type]!.add(olcum);
    }
  }
  
  void _calculateStats() {
    _toplamTest = _olcumler.length;
    _sprintTestSayisi = _olcumler.where((o) => o.olcumTuru.toUpperCase() == 'SPRINT').length;
    _sicramaTestSayisi = _olcumler.where((o) => o.olcumTuru.toUpperCase() != 'SPRINT').length;
  }

  List<Olcum> get _filteredOlcumler {
    if (_selectedTestType == 'Tümü') return _olcumler;
    return _olcumler.where((o) => o.olcumTuru.toUpperCase() == _selectedTestType.toUpperCase()).toList();
  }

  String _formatDate(String dateString) {
    try {
      DateTime date;
      if (dateString.contains('T')) {
        date = DateTime.parse(dateString);
      } else {
        // Tarih formatı uygun değilse mevcut tarih kullan
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
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      debugPrint("Tarih biçimlendirme hatası: $e, input: $dateString");
      return dateString;
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                _buildAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildSporcuSecimBolumu(),
                        const SizedBox(height: 16),
                        if (_secilenSporcu != null) ...[
                          _buildFiltreler(), // Bu satırda hata var, metod eklendiği için artık çalışacak
                          const SizedBox(height: 16),
                          if (_filteredOlcumler.isNotEmpty) _buildOzet(),
                          const SizedBox(height: 16),
                          _buildDetayliAnalizMenusu(),
                          const SizedBox(height: 16),
                          _buildTestListesi(),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Sporcu Performans Analizi',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                offset: const Offset(1, 1),
                blurRadius: 3.0,
                color: Colors.black.withOpacity(0.5),
              ),
            ],
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            if (_secilenSporcu != null && _secilenSporcu!.id != null) {
              _loadOlcumler(_secilenSporcu!.id!);
            } else {
              _loadSporcular();
            }
          },
          tooltip: 'Yenile',
        ),
      ],
    );
  }

  // analiz_screen.dart dosyasında _buildSporcuSecimBolumu metodundaki DropdownButtonFormField kısmını düzeltelim

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
          hint: const Text('Sporcu Seç'),
          value: _secilenSporcu?.id,
          onChanged: (sporcuId) {
            if (sporcuId != null) {
              setState(() {
                _secilenSporcu = _sporcular.firstWhere((sporcu) => sporcu.id == sporcuId);
              });
              _loadOlcumler(sporcuId);
            }
          },
          // Buradaki items kısmını düzeltiyoruz - sporcuların uniqueId'lerini kullanarak
          items: _sporcular.map((sporcu) {
            return DropdownMenuItem<int>(
              value: sporcu.id, // Sporcu ID'sini kullan (benzersiz olmalı)
              child: Text('${sporcu.ad} ${sporcu.soyad} (${sporcu.yas} yaş)'),
            );
          }).toList(),
        ),
      ],
    ),
  );
}

  Widget _buildOzet() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Özet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard(
                'Toplam Test',
                _toplamTest.toString(),
                Icons.assessment,
                const Color(0xFF0288D1),
              ),
              _buildStatCard(
                'Sprint',
                _sprintTestSayisi.toString(),
                Icons.directions_run,
                const Color(0xFFE57373),
              ),
              _buildStatCard(
                'Sıçrama',
                _sicramaTestSayisi.toString(),
                Icons.height,
                const Color(0xFF64B5F6),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  // analiz_screen.dart dosyasındaki _buildDetayliAnalizMenusu metoduna güncellemeleri ekleyelim
Widget _buildDetayliAnalizMenusu() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          'Detaylı Analizler',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      // İlk sırada yan yana iki kutucuk
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Dikey Profil Analizi
            Expanded(
              child: _buildAnalysisCard(
                title: 'Dikey Kuvvet-Hız',
                description: 'Sıçrama performansı analizi',
                icon: Icons.trending_up,
                color: const Color(0xFF64B5F6),
                isDisabled: _sicramaTestSayisi == 0,
                onTap: () {
                  if (_sicramaTestSayisi > 0 && _secilenSporcu != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DikeyProfilScreen(),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sporcu için sıçrama ölçümü bulunamadı')),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            // Yatay Profil Analizi
            Expanded(
              child: _buildAnalysisCard(
                title: 'Yatay Kuvvet-Hız',
                description: 'Sprint performansı analizi',
                icon: Icons.swap_horiz,
                color: const Color(0xFFE57373),
                isDisabled: _sprintTestSayisi == 0,
                onTap: () {
                  if (_sprintTestSayisi > 0 && _secilenSporcu != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => YatayProfilScreen(),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sporcu için sprint ölçümü bulunamadı')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      // İkinci sırada yan yana iki kutucuk
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Test Karşılaştırma
            Expanded(
              child: _buildAnalysisCard(
                title: 'Test Karşılaştırma',
                description: 'Farklı tarihlerdeki testleri karşılaştır',
                icon: Icons.compare_arrows,
                color: const Color(0xFF9575CD),
                isDisabled: _toplamTest < 2,
                onTap: () {
                  if (_toplamTest >= 2 && _secilenSporcu != null) {
                    if (_selectedTestType != 'Tümü') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TestKarsilastirmaScreen(
                            sporcuId: _secilenSporcu!.id!,
                            testType: _selectedTestType,
                          ),
                        ),
                      );
                    } else {
                      // Test türü seçili değilse kullanıcıdan seçmesini iste
                      _showTestTuruSecimDialogu();
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Karşılaştırma için en az 2 test gerekli')),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            // Sporcu İlerleme Raporu
            Expanded(
              child: _buildAnalysisCard(
                title: 'İlerleme Raporu',
                description: 'Zaman içindeki gelişimi görüntüle',
                icon: Icons.trending_up,
                color: const Color(0xFF4DB6AC),
                isDisabled: _toplamTest == 0,
                onTap: () {
                  if (_toplamTest > 0 && _secilenSporcu != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => IlerlemeRaporuScreen(
                          sporcuId: _secilenSporcu!.id!,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Rapor için ölçüm bulunamadı')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      // Üçüncü sırada performans analizi
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Performans Analizi
            Expanded(
              child: _buildAnalysisCard(
                title: 'Performans Analizi',
                description: 'İstatistiksel performans değerlendirmesi',
                icon: Icons.analytics,
                color: const Color(0xFF42A5F5),
                isDisabled: _toplamTest < 3,
                onTap: () {
                  if (_toplamTest >= 3 && _secilenSporcu != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PerformanceAnalysisScreen(
                          sporcuId: _secilenSporcu!.id!,
                          olcumTuru: _selectedTestType != 'Tümü' ? _selectedTestType : null,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('İstatistiksel analiz için en az 3 test gerekli')),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            // Boş alan
            const Expanded(child: SizedBox()),
          ],
        ),
      ),
    ],
  );
}
// Test türü seçim diyaloğu için yeni bir metod ekleyelim
void _showTestTuruSecimDialogu() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Test Türü Seçin'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Karşılaştırmak istediğiniz test türünü seçin',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          ...['Sprint', 'CMJ', 'SJ', 'DJ', 'RJ'].map((type) {
            final testColor = _getTestTypeColor(type);
            final testIcon = _getTestTypeIcon(type);
            
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: testColor.withOpacity(0.2),
                child: Icon(testIcon, color: testColor, size: 20),
              ),
              title: Text(type),
              onTap: () {
                Navigator.pop(context); // Diyaloğu kapat
                
                if (_secilenSporcu != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TestKarsilastirmaScreen(
                        sporcuId: _secilenSporcu!.id!,
                        testType: type,
                      ),
                    ),
                  );
                }
              },
            );
          }).toList(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
      ],
    ),
  );
}

  Widget _buildAnalysisCard({
  required String title,
  required String description,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
  bool isDisabled = false,
}) {
  return InkWell(
    onTap: isDisabled ? null : onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      decoration: BoxDecoration(
        color: isDisabled ? Colors.grey.shade200 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDisabled ? Colors.grey.withOpacity(0.1) : color.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
        border: Border.all(
          color: isDisabled ? Colors.grey.shade300 : color.withOpacity(0.3),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDisabled ? Colors.grey.shade300 : color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: isDisabled ? Colors.grey : color,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isDisabled ? Colors.grey : Colors.black87,
            ),
            // Taşma durumunda ...ile kesmek için
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: isDisabled ? Colors.grey : Colors.black54,
            ),
            // Taşma durumunda ... ile kesmek için
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );
}

 Widget _buildTestListesi() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Test Sonuçları',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            DropdownButton<String>(
              value: _selectedDateFilter,
              underline: Container(),
              icon: const Icon(Icons.filter_list),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedDateFilter = newValue;
                  });
                  if (_secilenSporcu != null && _secilenSporcu!.id != null) {
                    _loadOlcumler(_secilenSporcu!.id!);
                  }
                }
              },
              items: _dateFilters.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      if (_filteredOlcumler.isEmpty)
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                _selectedTestType == 'Tümü'
                    ? 'Bu sporcu için henüz ölçüm yapılmamış'
                    : '$_selectedTestType testi için ölçüm bulunamadı',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
          ),
        )
      else
        ListView.builder(
          // ListView içinde shrinkWrap ve physics parametreleri ekleyerek sarmaladık
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredOlcumler.length,
          itemBuilder: (context, index) => _buildOlcumCard(_filteredOlcumler[index]),
        ),
    ],
  );
}

  Widget _buildOlcumCard(Olcum olcum) {
  final testColor = _getTestTypeColor(olcum.olcumTuru);
  final testIcon = _getTestTypeIcon(olcum.olcumTuru);
  
  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: InkWell(
      onTap: () => _showOlcumDetails(olcum),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: testColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(testIcon, color: testColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${olcum.olcumTuru} - ${olcum.olcumSirasi}. Ölçüm',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis, // Taşma durumunda kesmek için
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: testColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Test #${olcum.testId}',
                          style: TextStyle(fontSize: 12, color: testColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(olcum.olcumTarihi),
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (olcum.degerler.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildQuickStats(olcum),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildQuickStats(Olcum olcum) {
    if (olcum.olcumTuru.toUpperCase() == 'SPRINT') {
      final kapi7 = olcum.degerler.firstWhere(
        (d) => d.degerTuru.toUpperCase() == 'KAPI7',
        orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
      );
      
      if (kapi7.deger != 0) {
        return Text(
          'Süre: ${kapi7.deger.toStringAsFixed(2)} s',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF4CAF50)),
        );
      }
    } else {
      final yukseklik = olcum.degerler.firstWhere(
        (d) => d.degerTuru.toLowerCase() == 'yukseklik',
        orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
      );
      
      if (yukseklik.deger != 0) {
        return Text(
          'Yükseklik: ${yukseklik.deger.toStringAsFixed(1)} cm',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF4CAF50)),
        );
      }
    }
    
    return const SizedBox.shrink();
 }

 // analiz_screen.dart dosyasındaki _showOlcumDetails metodunu güncelliyoruz

void _showOlcumDetails(Olcum olcum) {
  // GlobalKey tanımla - repaint için
  
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          children: [
            // Sürüklenebilir çubuk göstergesi
            Container(
              width: 40, 
              height: 4, 
              decoration: BoxDecoration(
                color: Colors.grey[300], 
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Başlık kısmı
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(_getTestTypeIcon(olcum.olcumTuru), color: _getTestTypeColor(olcum.olcumTuru), size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${olcum.olcumTuru} - ${olcum.olcumSirasi}. Ölçüm', 
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _formatDate(olcum.olcumTarihi), 
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            // İçerik kısmı - burada düzeltme yapıyoruz
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(16),
                children: [
                  if (olcum.degerler.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32), 
                        child: Text(
                          'Bu ölçüm için değer bulunamadı.', 
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ),
                    )
                  else if (olcum.olcumTuru.toUpperCase() == 'SPRINT')
                    _buildSprintDetails(olcum)
                  else
                    _buildJumpDetails(olcum),
                  
                  const SizedBox(height: 24),
                  // Aksiyon butonları
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(
                        icon: Icons.analytics,
                        label: 'Detaylı Analiz',
                        color: Colors.blue,
                        onPressed: () {
                          Navigator.pop(context);
                          _navigateToDetailedAnalysis(olcum);
                        },
                      ),
                      _buildActionButton(
                        icon: Icons.share,
                        label: 'Paylaş',
                        color: Colors.green,
                        onPressed: () {
                          // Paylaşım ekranını göster
                          _showShareModal(olcum);
                        },
                      ),
                      _buildActionButton(
                        icon: Icons.delete,
                        label: 'Sil',
                        color: Colors.red,
                        onPressed: () {
                          _showDeleteConfirmationDialog(olcum);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
void _showShareModal(Olcum olcum) async {
  // GlobalKey tanımla - repaint için
  final GlobalKey repaintKey = GlobalKey();
  
  // Önce sporcu bilgilerini al
  final sporcu = await _databaseService.getSporcu(_secilenSporcu!.id!);
  
  if (!mounted) return; // mounted kontrolü ekle
  
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            // Başlık kısmı
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Test Sonucunu Paylaş',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            
            // Paylaşım görünümü
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Uyarı mesajı
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withAlpha(25), // withOpacity(0.1) -> withAlpha(25)
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withAlpha(76)), // withOpacity(0.3) -> withAlpha(76)
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Test sonuçları panoya kopyalanacak, istediğiniz uygulamada paylaşabilirsiniz.',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Repaint Boundary ile paylaşım görünümünü sar
                    // Sporcu null kontrolü eklendi
                    RepaintBoundary(
                      key: repaintKey,
                      child: OlcumPaylasimHelper.buildPaylasimWidget(
                        sporcu: sporcu,
                        olcum: olcum,
                        appName: 'Athlete Speed & Power',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Paylaşım butonları
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Paylaş'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  try {
                    // Paylaşım işlemini gerçekleştir
                    await OlcumPaylasimHelper.shareOlcum(
                      context: context,
                      repaintKey: repaintKey,
                      sporcu: sporcu,
                      olcum: olcum,
                    );
                    
                    if (mounted) { // mounted kontrolü eklendi
                      Navigator.pop(context); // Paylaşım modalını kapat
                    }
                  } catch (e) {
                    if (mounted) { // mounted kontrolü eklendi
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Paylaşım sırasında hata: $e')),
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
 
 Widget _buildActionButton({
   required IconData icon,
   required String label,
   required Color color,
   required VoidCallback onPressed,
 }) {
   return ElevatedButton.icon(
     onPressed: onPressed,
     icon: Icon(icon, color: Colors.white, size: 20),
     label: Text(label),
     style: ElevatedButton.styleFrom(
       backgroundColor: color,
       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
     ),
   );
 }

 void _showDeleteConfirmationDialog(Olcum olcum) {
   showDialog(
     context: context,
     builder: (BuildContext context) {
       return AlertDialog(
         title: const Text('Ölçümü Sil'),
         content: const Text('Bu ölçümü silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
         actions: [
           TextButton(
             onPressed: () => Navigator.of(context).pop(),
             child: const Text('İptal'),
           ),
           ElevatedButton(
             onPressed: () async {
               Navigator.of(context).pop(); // Diyalog kapat
               Navigator.of(context).pop(); // Bottom sheet kapat
               
               // Ölçümü sil
               try {
                 await _databaseService.deleteOlcum(olcum.id!);
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Ölçüm başarıyla silindi')),
                 );
                 
                 // Verileri yeniden yükle
                 if (_secilenSporcu != null && _secilenSporcu!.id != null) {
                   _loadOlcumler(_secilenSporcu!.id!);
                 }
               } catch (e) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text('Ölçüm silinirken hata: $e')),
                 );
               }
             },
             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
             child: const Text('Sil'),
           ),
         ],
       );
     },
   );
 }

 void _navigateToDetailedAnalysis(Olcum olcum) {
   switch (olcum.olcumTuru.toUpperCase()) {
     case 'SPRINT':
       Navigator.push(
         context,
         MaterialPageRoute(
           builder: (context) => YatayProfilScreen(),
         ),
       );
       break;
     case 'CMJ':
     case 'SJ':
     case 'DJ':
     case 'RJ':
       Navigator.push(
         context,
         MaterialPageRoute(
           builder: (context) => DikeyProfilScreen(),
         ),
       );
       break;
     default:
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Bu test türü için detaylı analiz bulunmuyor')),
       );
   }
 }

 Widget _buildSprintDetails(Olcum olcum) {
   // Tüm kapı değerlerini bul
   final kapiDegerler = <int, double>{};
   
   for (int i = 1; i <= 7; i++) {
     final kapi = olcum.degerler.firstWhere(
       (d) => d.degerTuru.toUpperCase() == 'KAPI$i',
       orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
     );
     
     if (kapi.deger != 0) {
       kapiDegerler[i] = kapi.deger;
     }
   }
   
   // İvme ve hız hesaplamaları
   final hizlar = <int, double>{};
   final ivmeler = <int, double>{};
   
   // Varsayılan kapı mesafeleri (m)
   final kapiMesafeleri = [0, 5, 10, 15, 20, 30, 40];
   
   // Hız hesaplama
   for (int i = 2; i <= 7; i++) {
     if (kapiDegerler.containsKey(i) && kapiDegerler.containsKey(i-1)) {
       final mesafe = kapiMesafeleri[i] - kapiMesafeleri[i-1];
       final sure = kapiDegerler[i]! - kapiDegerler[i-1]!;
       
       if (sure > 0) {
         hizlar[i] = mesafe / sure;
       }
     }
   }
   
   // İvme hesaplama
   for (int i = 3; i <= 7; i++) {
     if (hizlar.containsKey(i) && hizlar.containsKey(i-1)) {
       final deltaHiz = hizlar[i]! - hizlar[i-1]!;
       final deltaSure = kapiDegerler[i]! - kapiDegerler[i-1]!;
       
       if (deltaSure > 0) {
         ivmeler[i] = deltaHiz / deltaSure;
       }
     }
   }
   
   return Column(
     crossAxisAlignment: CrossAxisAlignment.start,
     children: [
       const Text('Sprint Detayları', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
       const SizedBox(height: 16),
       _buildSprintGraph(kapiDegerler),
       const SizedBox(height: 24),
       
       // Kapı zamanları
       const Text('Kapı Zamanları', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
       const SizedBox(height: 12),
       ...List.generate(7, (index) {
         final kapiNo = index + 1;
         final kapiDeger = kapiDegerler[kapiNo] ?? 0;
         
         if (kapiDeger != 0) {
           return ListTile(
             leading: CircleAvatar(
               backgroundColor: const Color(0xFFE57373).withOpacity(0.2), 
               child: Text('$kapiNo', style: const TextStyle(color: Color(0xFFE57373), fontWeight: FontWeight.bold)),
             ),
             title: Text('$kapiNo. Kapı (${kapiMesafeleri[index]} m)'),
             trailing: Text(
               '${kapiDeger.toStringAsFixed(3)} s', 
               style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
             ),
           );
         }
         return const SizedBox.shrink();
       }),
       
       const SizedBox(height: 24),
       
       // Hız verileri
       const Text('Anlık Hızlar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
       const SizedBox(height: 12),
       ...hizlar.entries.map((entry) {
         return ListTile(
           leading: const Icon(Icons.speed, color: Color(0xFF64B5F6)),
           title: Text('${entry.key-1}-${entry.key}. Kapı Arası'),
           trailing: Text(
             '${entry.value.toStringAsFixed(2)} m/s', 
             style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
           ),
         );
       }).toList(),
       
       // İvme verileri (yeterli veri varsa)
       if (ivmeler.isNotEmpty) ...[
         const SizedBox(height: 24),
         const Text('İvme Değerleri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
         const SizedBox(height: 12),
         ...ivmeler.entries.map((entry) {
           return ListTile(
             leading: const Icon(Icons.trending_up, color: Color(0xFF81C784)),
             title: Text('${entry.key-1}-${entry.key}. Kapı Arası'),
             trailing: Text(
               '${entry.value.toStringAsFixed(2)} m/s²', 
               style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
             ),
           );
         }).toList(),
       ],
     ],
   );
 }

 Widget _buildSprintGraph(Map<int, double> kapiDegerler) {
   // Graf verilerini hazırla
   final spots = <FlSpot>[];
   final kapiMesafeleri = [0, 5, 10, 15, 20, 30, 40];
   
   kapiDegerler.forEach((kapi, sure) {
     if (kapi - 1 < kapiMesafeleri.length) {
       spots.add(FlSpot(kapiMesafeleri[kapi - 1].toDouble(), sure));
     }
   });
   
   // Noktaları sırala
   spots.sort((a, b) => a.x.compareTo(b.x));
   
   return SizedBox(
     height: 200,
     child: spots.length < 2 ? 
       const Center(child: Text('Grafik için yeterli veri yok')) :
       LineChart(
         LineChartData(
           gridData: FlGridData(
             show: true,
             drawVerticalLine: true,
             horizontalInterval: 1,
             verticalInterval: 5,
           ),
           titlesData: FlTitlesData(
             bottomTitles: AxisTitles(
               sideTitles: SideTitles(
                 showTitles: true,
                 interval: 5,
                 getTitlesWidget: (value, meta) {
                   return SideTitleWidget(
                     axisSide: meta.axisSide,
                     child: Text('${value.toInt()} m'),
                   );
                 },
                 reservedSize: 30,
               ),
               axisNameWidget: const Text('Mesafe (m)'),
             ),
             leftTitles: AxisTitles(
               sideTitles: SideTitles(
                 showTitles: true,
                 interval: 1,
                 getTitlesWidget: (value, meta) {
                   return SideTitleWidget(
                     axisSide: meta.axisSide,
                     child: Text('${value.toStringAsFixed(1)} s'),
                   );
                 },
                 reservedSize: 40,
               ),
               axisNameWidget: const Text('Zaman (s)'),
             ),
             topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
             rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
           ),
           borderData: FlBorderData(show: true),
           lineBarsData: [
             LineChartBarData(
               spots: spots,
               isCurved: true,
               color: const Color(0xFFE57373),
               barWidth: 3,
               isStrokeCapRound: true,
               dotData: FlDotData(
                 show: true,
                 getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                   radius: 4,
                   color: const Color(0xFFE57373),
                   strokeWidth: 2,
                   strokeColor: Colors.white,
                 ),
               ),
               belowBarData: BarAreaData(show: false),
             ),
           ],
         ),
       ),
   );
 }

 Widget _buildJumpDetails(Olcum olcum) {
   // Temel ölçüm değerlerini al
   final yukseklik = olcum.degerler.firstWhere(
     (d) => d.degerTuru.toLowerCase() == 'yukseklik',
     orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
   );
   
   final ucusSuresi = olcum.degerler.firstWhere(
     (d) => d.degerTuru.toLowerCase() == 'ucussuresi',
     orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
   );
   
   final temasSuresi = olcum.degerler.firstWhere(
     (d) => d.degerTuru.toLowerCase() == 'temassuresi',
     orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
   );
   
   final guc = olcum.degerler.firstWhere(
     (d) => d.degerTuru.toLowerCase() == 'guc',
     orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
   );
   
   final rsi = olcum.degerler.firstWhere(
     (d) => d.degerTuru.toLowerCase() == 'rsi',
     orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
   );
   
   final ritim = olcum.degerler.firstWhere(
     (d) => d.degerTuru.toLowerCase() == 'ritim',
     orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
   );
   
   // RJ için flight serisi değerleri
   List<double> flightSeries = [];
   List<double> contactSeries = [];
   List<double> heightSeries = [];
   
   if (olcum.olcumTuru.toUpperCase() == 'RJ') {
     for (int i = 1; i <= 30; i++) {
       final flight = olcum.degerler.firstWhere(
         (d) => d.degerTuru == 'Flight$i',
         orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
       );
       
       if (flight.deger > 0) {
         flightSeries.add(flight.deger);
         
         final contact = olcum.degerler.firstWhere(
           (d) => d.degerTuru == 'Contact$i',
           orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
         );
         
         if (contact.deger > 0) {
           contactSeries.add(contact.deger);
         }
         
         final height = olcum.degerler.firstWhere(
           (d) => d.degerTuru == 'Height$i',
           orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
         );
         
         if (height.deger > 0) {
           heightSeries.add(height.deger);
         }
       } else {
         break;
       }
     }
   }
   
   return Column(
     crossAxisAlignment: CrossAxisAlignment.start,
     children: [
       Text('${olcum.olcumTuru} Detayları', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
       const SizedBox(height: 20),
       
       // Ana sıçrama metrikleri
       Row(
         mainAxisAlignment: MainAxisAlignment.spaceBetween,
         children: [
           _buildJumpMetricCard(
             title: 'Yükseklik',
             value: yukseklik.deger != 0 ? '${yukseklik.deger.toStringAsFixed(1)} cm' : '-',
             icon: Icons.height,
             color: const Color(0xFF64B5F6),
           ),
           _buildJumpMetricCard(
             title: 'Uçuş Süresi',
value: ucusSuresi.deger != 0 ? ucusSuresi.deger.toStringAsFixed(3) + ' s' : '-',
             icon: Icons.timer,
             color: const Color(0xFF81C784),
           ),
           _buildJumpMetricCard(
             title: 'Güç',
             value: guc.deger != 0 ? '${guc.deger.toStringAsFixed(0)} W' : '-',
             icon: Icons.bolt,
             color: const Color(0xFFFFB74D),
           ),
         ],
       ),
       
       const SizedBox(height: 16),
       
       // Test türüne göre ek metrikler
       if (olcum.olcumTuru.toUpperCase() == 'DJ' || olcum.olcumTuru.toUpperCase() == 'RJ') ...[
         const Divider(height: 32),
         Row(
           mainAxisAlignment: MainAxisAlignment.spaceBetween,
           children: [
             _buildJumpMetricCard(
               title: 'Temas Süresi',
               value: temasSuresi.deger != 0 ? '${temasSuresi.deger.toStringAsFixed(3)} s' : '-',
               icon: Icons.touch_app,
               color: const Color(0xFF9575CD),
             ),
             _buildJumpMetricCard(
               title: 'RSI',
               value: rsi.deger != 0 ? '${rsi.deger.toStringAsFixed(2)}' : '-',
               icon: Icons.speed,
               color: const Color(0xFFE57373),
             ),
             if (olcum.olcumTuru.toUpperCase() == 'RJ')
               _buildJumpMetricCard(
                 title: 'Ritim',
                 value: ritim.deger != 0 ? '${ritim.deger.toStringAsFixed(2)}/s' : '-',
                 icon: Icons.loop,
                 color: const Color(0xFF4DB6AC),
               )
             else
               const SizedBox(width: 100),
           ],
         ),
       ],
       
       // RJ için seri grafikleri
       if (olcum.olcumTuru.toUpperCase() == 'RJ' && flightSeries.isNotEmpty) ...[
         const SizedBox(height: 24),
         const Text('Sıçrama Serisi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
         const SizedBox(height: 16),
         _buildRJGraph(flightSeries, heightSeries, contactSeries),
         const SizedBox(height: 16),
         Text('Toplam sıçrama sayısı: ${flightSeries.length}', 
           style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
       ],
       
       // Değer tablosu
       const SizedBox(height: 24),
       const Text('Tüm Ölçüm Değerleri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
       const SizedBox(height: 12),
       ...olcum.degerler.map((deger) {
         String title = '';
         String unit = '';
         IconData icon = Icons.analytics;
         
         switch (deger.degerTuru.toLowerCase()) {
           case 'yukseklik': 
             title = 'Yükseklik'; 
             unit = 'cm'; 
             icon = Icons.height; 
             break;
           case 'ucussuresi': 
             title = 'Uçuş Süresi'; 
             unit = 's'; 
             icon = Icons.timer; 
             break;
           case 'temassuresi': 
             title = 'Temas Süresi'; 
             unit = 's'; 
             icon = Icons.touch_app; 
             break;
           case 'guc': 
             title = 'Güç'; 
             unit = 'W'; 
             icon = Icons.bolt; 
             break;
           case 'rsi': 
             title = 'RSI'; 
             unit = ''; 
             icon = Icons.speed; 
             break;
           case 'ritim': 
             title = 'Ritim'; 
             unit = 'sıçrama/s'; 
             icon = Icons.repeat; 
             break;
           default: 
             if (deger.degerTuru.startsWith('Flight') || deger.degerTuru.startsWith('Contact') || deger.degerTuru.startsWith('Height')) {
               // RJ seri değerleri için özel gösterim yapma
               return const SizedBox.shrink();
             } else {
               title = deger.degerTuru;
             }
         }
         
         return ListTile(
           leading: Icon(icon, color: const Color(0xFF64B5F6)),
           title: Text(title),
           trailing: Text(
             '${deger.deger.toStringAsFixed(2)} $unit', 
             style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
           ),
         );
       }).toList(),
     ],
   );
 }

 Widget _buildJumpMetricCard({
   required String title,
   required String value,
   required IconData icon,
   required Color color,
 }) {
   return Container(
     width: MediaQuery.of(context).size.width * 0.28,
     padding: const EdgeInsets.all(12),
     decoration: BoxDecoration(
       color: color.withOpacity(0.1),
       borderRadius: BorderRadius.circular(12),
     ),
     child: Column(
       mainAxisAlignment: MainAxisAlignment.center,
       children: [
         Icon(icon, color: color),
         const SizedBox(height: 8),
         Text(
           value,
           style: TextStyle(
             fontWeight: FontWeight.bold,
             fontSize: 16,
             color: color,
           ),
         ),
         Text(
           title,
           style: TextStyle(
             fontSize: 12,
             color: color.withOpacity(0.8),
           ),
           textAlign: TextAlign.center,
         ),
       ],
     ),
   );
 }

 Widget _buildRJGraph(
   List<double> flightTimes, 
   List<double> jumpHeights, 
   List<double> contactTimes,
 ) {
   // Karşılaştırılabilir grafikler için
   return SizedBox(
     height: 220,
     child: DefaultTabController(
       length: 3,
       child: Column(
         children: [
           const TabBar(
             tabs: [
               Tab(text: 'Yükseklik'),
               Tab(text: 'Uçuş Süresi'),
               Tab(text: 'Temas Süresi'),
             ],
             labelColor: Color(0xFF0288D1),
             indicatorColor: Color(0xFF0288D1),
             unselectedLabelColor: Colors.grey,
           ),
           Expanded(
             child: TabBarView(
               children: [
                 // Yükseklik grafiği
                 jumpHeights.isNotEmpty ? _buildBarChart(
                   data: jumpHeights,
                   barColor: const Color(0xFF64B5F6),
                   title: 'Yükseklik (cm)',
                   maxY: jumpHeights.reduce((a, b) => math.max(a, b)) * 1.2,
                 ) : const Center(child: Text('Veri yok')),
                 
                 // Uçuş süresi grafiği
                 flightTimes.isNotEmpty ? _buildBarChart(
                   data: flightTimes,
                   barColor: const Color(0xFF81C784),
                   title: 'Uçuş Süresi (s)',
                   maxY: flightTimes.reduce((a, b) => math.max(a, b)) * 1.2,
                 ) : const Center(child: Text('Veri yok')),
                 
                 // Temas süresi grafiği
                 contactTimes.isNotEmpty ? _buildBarChart(
                   data: contactTimes,
                   barColor: const Color(0xFFFFB74D),
                   title: 'Temas Süresi (s)',
                   maxY: contactTimes.reduce((a, b) => math.max(a, b)) * 1.2,
                 ) : const Center(child: Text('Veri yok')),
               ],
             ),
           ),
         ],
       ),
     ),
   );
 }

 Widget _buildBarChart({
   required List<double> data,
   required Color barColor,
   required String title,
   required double maxY,
 }) {
   return Padding(
     padding: const EdgeInsets.symmetric(vertical: 16),
     child: BarChart(
       BarChartData(
         alignment: BarChartAlignment.spaceAround,
         maxY: maxY,
         barTouchData: BarTouchData(
           enabled: true,
           touchTooltipData: BarTouchTooltipData(
             tooltipBgColor: Colors.blueGrey,
             getTooltipItem: (group, groupIndex, rod, rodIndex) {
               return BarTooltipItem(
                 '${data[groupIndex].toStringAsFixed(2)}',
                 const TextStyle(color: Colors.white),
               );
             },
           ),
         ),
         titlesData: FlTitlesData(
           bottomTitles: AxisTitles(
             sideTitles: SideTitles(
               showTitles: true,
               getTitlesWidget: (value, meta) {
                 return SideTitleWidget(
                   axisSide: meta.axisSide,
                   child: Text('${(value + 1).toInt()}'),
                 );
               },
               reservedSize: 30,
             ),
           ),
           leftTitles: AxisTitles(
             sideTitles: SideTitles(
               showTitles: true,
               reservedSize: 40,
               interval: maxY / 5,
               getTitlesWidget: (value, meta) {
                 return SideTitleWidget(
                   axisSide: meta.axisSide,
                   child: Text(value.toStringAsFixed(1)),
                 );
               },
             ),
             axisNameWidget: Text(title),
           ),
           topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
           rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
         ),
         gridData: FlGridData(
           show: true,
           horizontalInterval: maxY / 5,
         ),
         borderData: FlBorderData(
           show: true,
           border: Border(
             left: BorderSide(color: Colors.grey.shade300),
             bottom: BorderSide(color: Colors.grey.shade300),
           ),
         ),
         barGroups: List.generate(
           data.length,
           (index) => BarChartGroupData(
             x: index,
             barRods: [
               BarChartRodData(
                 toY: data[index],
                 color: barColor,
                 width: 16,
                 borderRadius: const BorderRadius.only(
                   topLeft: Radius.circular(4),
                   topRight: Radius.circular(4),
                 ),
               ),
             ],
           ),
         ),
       ),
     ),
   );
 }


}

