import 'package:flutter/material.dart';
import 'package:izLab/utils/statistics_helper.dart';
import 'dart:math' as math;
import '../models/sporcu_model.dart';
import '../models/olcum_model.dart';
import '../services/database_service.dart';
import 'dikey_profil_screen.dart';
import 'yatay_profil_screen.dart';
import 'load_velocity_profile_screen.dart';
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
  return olcumler;
}

class AnalizScreen extends StatefulWidget {
  final int? initialSporcuId;
  
  const AnalizScreen({Key? key, this.initialSporcuId}) : super(key: key);

  @override
  _AnalizScreenState createState() => _AnalizScreenState();
}

class _AnalizScreenState extends State<AnalizScreen> with TickerProviderStateMixin {


  final DatabaseService _databaseService = DatabaseService();
  List<Sporcu> _sporcular = [];
  Sporcu? _secilenSporcu;
  List<Olcum> _olcumler = [];
  Map<String, List<Olcum>> _olcumGruplari = {};
  bool _isLoading = true;
  String _selectedTestType = 'Tümü';
  
  // Animasyon kontrolcüleri
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Filtreleme seçenekleri
  final List<String> _testTypes = ['Tümü', 'Sprint', 'CMJ', 'SJ', 'DJ', 'RJ'];
  String _selectedDateFilter = 'Tümü';
  final List<String> _dateFilters = ['Tümü', 'Son 7 Gün', 'Son 30 Gün', 'Son 3 Ay', 'Son 6 Ay', 'Son 1 Yıl'];

  final Map<String, dynamic> _performanceCache = {};
  
  // İstatistik değerleri
  int _toplamTest = 0;
  int _sprintTestSayisi = 0;
  int _sicramaTestSayisi = 0;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
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
  
 @override
void dispose() {
  _animationController.dispose();
  _performanceCache.clear(); // Cache'i temizle
  super.dispose();
}
  
  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  Future<void> _loadSporcular() async {
    try {
      setState(() => _isLoading = true);
      
      final sporcuList = await _databaseService.getAllSporcular();
      final filteredList = sporcuList.where((s) => s.id != null).toList();
      
      if (mounted) {
        setState(() {
          _sporcular = filteredList;
          _isLoading = false;
        });
        _animationController.forward();
      }
      
    } catch (e) {
      if (mounted) {
        _showSnackBar('Sporcular yüklenirken hata: $e', isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

Future<void> _loadOlcumler(int sporcuId) async {
  // Cache kontrolü
  final cacheKey = 'olcumler_$sporcuId';
  final now = DateTime.now();
  
  if (_performanceCache.containsKey(cacheKey)) {
    final cachedData = _performanceCache[cacheKey];
    final cacheTime = cachedData['timestamp'] as DateTime;
    
    // Cache 5 dakikadan yeni ise kullan
    if (now.difference(cacheTime).inMinutes < 5) {
      _olcumler = List<Olcum>.from(cachedData['olcumler']);
      _secilenSporcu = cachedData['sporcu'] as Sporcu;
      
      _olcumler.sort((a, b) => b.olcumTarihi.compareTo(a.olcumTarihi));
      _applyDateFilter();
      _groupTestsByType();
      _calculateStats();
      
      setState(() => _isLoading = false);
      return;
    }
  }
  
  try {
    setState(() => _isLoading = true);
    
    final sporcuFuture = _databaseService.getSporcu(sporcuId);
    final olcumlerFuture = _databaseService.getOlcumlerBySporcuId(sporcuId);
    
    final results = await Future.wait([sporcuFuture, olcumlerFuture]);
    
    _secilenSporcu = results[0] as Sporcu;
    _olcumler = results[1] as List<Olcum>;
    
    // Cache'e kaydet
    _performanceCache[cacheKey] = {
      'olcumler': List<Olcum>.from(_olcumler),
      'sporcu': _secilenSporcu,
      'timestamp': now,
    };
    
    // Cache boyutu kontrolü - 10 sporcu üzerinde ise eski cache'leri temizle
    if (_performanceCache.length > 10) {
      final oldestKey = _performanceCache.entries
          .reduce((a, b) => (a.value['timestamp'] as DateTime)
              .isBefore(b.value['timestamp'] as DateTime) ? a : b)
          .key;
      _performanceCache.remove(oldestKey);
    }
    
    _olcumler.sort((a, b) => b.olcumTarihi.compareTo(a.olcumTarihi));
    
    _applyDateFilter();
    _groupTestsByType();
    _calculateStats();
    
  } catch (e) {
    if (mounted) {
      _showSnackBar('Ölçümler yüklenirken hata: $e', isError: true);
    }
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}
  
  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
  
  void _applyDateFilter() {
    if (_selectedDateFilter == 'Tümü') {
      return;
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
        return true;
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
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildModernHeader(),
            Expanded(
              child: _isLoading
                  ? _buildLoadingIndicator()
                  : FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: RefreshIndicator(
                          onRefresh: () async {
                            if (_secilenSporcu != null && _secilenSporcu!.id != null) {
                              await _loadOlcumler(_secilenSporcu!.id!);
                            } else {
                              await _loadSporcular();
                            }
                          },
                          child: CustomScrollView(
                            slivers: [
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    children: [
                                      _buildSporcuSecimBolumu(),
                                      const SizedBox(height: 16),
                                      if (_secilenSporcu != null) ...[
                                        _buildFiltreler(),
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
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildModernHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.analytics,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Performans Analizi',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Sporcu Değerlendirme',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                  onPressed: () async {
                    if (_secilenSporcu != null && _secilenSporcu!.id != null) {
                      await _loadOlcumler(_secilenSporcu!.id!);
                    } else {
                      await _loadSporcular();
                    }
                  },
                  tooltip: 'Yenile',
                ),
              ),
            ],
          ),
          if (_secilenSporcu != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_secilenSporcu!.ad} ${_secilenSporcu!.soyad} (${_secilenSporcu!.yas} yaş)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_selectedTestType != 'Tümü')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _selectedTestType,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1565C0)),
          ),
          SizedBox(height: 16),
          Text(
            'Veriler yükleniyor...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSporcuSecimBolumu() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF8F9FA)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Sporcu Seçin',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  hintText: 'Sporcu Seç',
                  hintStyle: TextStyle(color: Colors.grey),
                ),
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
                dropdownColor: Colors.white,
                style: const TextStyle(color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltreler() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.filter_list, color: Color(0xFF1565C0), size: 16),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Test Filtreleri',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _testTypes.length,
                itemBuilder: (context, index) {
                  final testType = _testTypes[index];
                  final isSelected = _selectedTestType == testType;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(testType),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedTestType = testType);
                        }
                      },
                      selectedColor: const Color(0xFF1565C0),
                      backgroundColor: Colors.grey[100],
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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

  Widget _buildOzet() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.assessment, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Test Özeti',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildModernStatCard(
                    'Toplam Test',
                    _toplamTest.toString(),
                    Icons.assessment,
                    const Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildModernStatCard(
                    'Sprint',
                    _sprintTestSayisi.toString(),
                    Icons.directions_run,
                    const Color(0xFFE57373),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildModernStatCard(
                    'Sıçrama',
                    _sicramaTestSayisi.toString(),
                    Icons.height,
                    const Color(0xFF64B5F6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetayliAnalizMenusu() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.analytics, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Detaylı Analizler',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // İlk sıra
            Row(
              children: [
                Expanded(
                  child: _buildAdvancedAnalysisCard(
                    'Dikey Kuvvet-Hız',
                    'Sıçrama performans profili',
                    Icons.show_chart,
                    const LinearGradient(colors: [Color(0xFF66BB6A), Color(0xFF4CAF50)]),
                    'Sıçrama Profili',
                    _sicramaTestSayisi == 0,
                    () {
                      if (_sicramaTestSayisi > 0 && _secilenSporcu != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const DikeyProfilScreen()),
                        );
                      } else {
                        _showSnackBar('Sporcu için sıçrama ölçümü bulunamadı', isError: true);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAdvancedAnalysisCard(
                    'Yatay Kuvvet-Hız',
                    'Sprint performans profili',
                    Icons.swap_horiz,
                    const LinearGradient(colors: [Color(0xFFFF7043), Color(0xFFFF5722)]),
                    'Sprint Profili',
                    _sprintTestSayisi == 0,
                    () {
                      if (_sprintTestSayisi > 0 && _secilenSporcu != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const YatayProfilScreen()),
                        );
                      } else {
                        _showSnackBar('Sporcu için sprint ölçümü bulunamadı', isError: true);
                      }
                    },
                  ),
                ),
              ],
            ),
             const SizedBox(height: 12),
            
            // İkinci sıra
            Row(
              children: [
                Expanded(
                  child: _buildAdvancedAnalysisCard(
                    'Yatay Yük-Hız',
                    'Load-velocity profil analizi',
                    Icons.fitness_center,
                    const LinearGradient(colors: [Color(0xFFAB47BC), Color(0xFF9C27B0)]),
                    'Load-Velocity',
                    _sprintTestSayisi == 0,
                    () {
                      if (_sprintTestSayisi > 0 && _secilenSporcu != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LoadVelocityProfileScreen()),
                        );
                      } else {
                        _showSnackBar('Sporcu için sprint ölçümü bulunamadı', isError: true);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAdvancedAnalysisCard(
                    'Test Karşılaştırma',
                    'Farklı testleri karşılaştırın',
                    Icons.compare_arrows,
                    const LinearGradient(colors: [Color(0xFF9575CD), Color(0xFF7E57C2)]),
                    'Veri Karşılaştırması',
                    _toplamTest < 2,
                    () {
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
                          _showTestTuruSecimDialogu();
                        }
                      } else {
                        _showSnackBar('Karşılaştırma için en az 2 test gerekli', isError: true);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Üçüncü sıra
            Row(
              children: [
                Expanded(
                  child: _buildAdvancedAnalysisCard(
                    'İlerleme Raporu',
                    'Zaman içindeki gelişim',
                    Icons.trending_up,
                    const LinearGradient(colors: [Color(0xFF4DB6AC), Color(0xFF26A69A)]),
                    'Performans Geçmişi',
                    _toplamTest == 0,
                    () {
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
                        _showSnackBar('Rapor için ölçüm bulunamadı', isError: true);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAdvancedAnalysisCard(
                    'Performans Analizi',
                    'İstatistiksel değerlendirme',
                    Icons.analytics,
                    const LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF2196F3)]),
                    'İstatistiksel',
                    _toplamTest < 3,
                    () {
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
                        _showSnackBar('İstatistiksel analiz için en az 3 test gerekli', isError: true);
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

  Widget _buildAdvancedAnalysisCard(
    String title,
    String subtitle,
    IconData icon,
    Gradient gradient,
    String category,
    bool isDisabled,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          gradient: isDisabled ? null : gradient,
          color: isDisabled ? Colors.grey[200] : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDisabled 
                  ? Colors.grey.withOpacity(0.1)
                  : gradient.colors.first.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background pattern
            if (!isDisabled) ...[
              Positioned(
                top: -15,
                right: -15,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                bottom: -20,
                left: -20,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
            ],
            
            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDisabled 
                          ? Colors.grey[300]
                          : Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon, 
                      color: isDisabled ? Colors.grey : Colors.white, 
                      size: 18
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDisabled 
                          ? Colors.grey[300]
                          : Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        color: isDisabled ? Colors.grey : Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: TextStyle(
                      color: isDisabled ? Colors.grey : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDisabled 
                          ? Colors.grey 
                          : Colors.white.withOpacity(0.9),
                      fontSize: 10,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTestTuruSecimDialogu() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.compare_arrows, color: Color(0xFF1565C0)),
            ),
            const SizedBox(width: 12),
            const Text('Test Türü Seçin'),
          ],
        ),
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
              
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: testColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: testColor.withOpacity(0.3)),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: testColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(testIcon, color: Colors.white, size: 20),
                  ),
                  title: Text(
                    type,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: testColor,
                    ),
                  ),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16, color: testColor),
                  onTap: () {
                    Navigator.pop(context);
                    
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
                ),
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

  Widget _buildTestListesi() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.list_alt, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Test Sonuçları',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedDateFilter,
                    underline: Container(),
                    icon: const Icon(Icons.filter_list, size: 16),
                    style: const TextStyle(color: Color(0xFF1565C0), fontSize: 12),
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
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            if (_filteredOlcumler.isEmpty)
              _buildEmptyTestsState()
            else
              Column(
                children: _filteredOlcumler.map((olcum) => _buildModernOlcumCard(olcum)).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTestsState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.analytics_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Test Bulunamadı',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedTestType == 'Tümü'
                  ? 'Bu sporcu için henüz ölçüm yapılmamış'
                  : '$_selectedTestType testi için ölçüm bulunamadı',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernOlcumCard(Olcum olcum) {
    final testColor = _getTestTypeColor(olcum.olcumTuru);
    final testIcon = _getTestTypeIcon(olcum.olcumTuru);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: testColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: testColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showOlcumDetails(olcum),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [testColor, testColor.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(testIcon, color: Colors.white, size: 24),
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
                            style: const TextStyle(
                              fontSize: 16, 
                              fontWeight: FontWeight.bold
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: testColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Test #${olcum.testId}',
                            style: TextStyle(
                              fontSize: 12, 
                              color: testColor, 
                              fontWeight: FontWeight.bold
                            ),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: testColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.chevron_right, color: testColor, size: 20),
              ),
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
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Süre: ${kapi7.deger.toStringAsFixed(2)} s',
            style: const TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.w600, 
              color: Color(0xFF4CAF50)
            ),
          ),
        );
      }
    } else {
      final yukseklik = olcum.degerler.firstWhere(
        (d) => d.degerTuru.toLowerCase() == 'yukseklik',
        orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
      );
      
      if (yukseklik.deger != 0) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Yükseklik: ${yukseklik.deger.toStringAsFixed(1)} cm',
            style: const TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.w600, 
              color: Color(0xFF4CAF50)
            ),
          ),
        );
      }
    }
    
    return const SizedBox.shrink();
  }

  void _showOlcumDetails(Olcum olcum) {
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
              Container(
                width: 40, 
                height: 4, 
                decoration: BoxDecoration(
                  color: Colors.grey[300], 
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _getTestTypeColor(olcum.olcumTuru),
                            _getTestTypeColor(olcum.olcumTuru).withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getTestTypeIcon(olcum.olcumTuru), 
                        color: Colors.white, 
                        size: 24
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${olcum.olcumTuru} - ${olcum.olcumSirasi}. Ölçüm', 
                            style: const TextStyle(
                              fontSize: 20, 
                              fontWeight: FontWeight.bold
                            ),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionButton(
                          icon: Icons.analytics,
                          label: 'Detaylı Analiz',
                          color: const Color(0xFF1565C0),
                          onPressed: () {
                            Navigator.pop(context);
                            _navigateToDetailedAnalysis(olcum);
                          },
                        ),
                        _buildActionButton(
                          icon: Icons.share,
                          label: 'Paylaş',
                          color: const Color(0xFF4CAF50),
                          onPressed: () {
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
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showShareModal(Olcum olcum) async {
    final GlobalKey repaintKey = GlobalKey();
    final sporcu = await _databaseService.getSporcu(_secilenSporcu!.id!);
    
    if (!mounted) return;
    
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
              
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withAlpha(76)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue, size: 20),
                            SizedBox(width: 8),
                            Expanded(
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
              
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('Paylaş'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    try {
                      await OlcumPaylasimHelper.shareOlcum(
                        context: context,
                        repaintKey: repaintKey,
                        sporcu: sporcu,
                        olcum: olcum,
                      );
                      
                      if (mounted) {
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      if (mounted) {
                        _showSnackBar('Paylaşım sırasında hata: $e', isError: true);
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

 void _showDeleteConfirmationDialog(Olcum olcum) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_outline, color: Colors.red),
              ),
              const SizedBox(width: 12),
              const Text('Ölçümü Sil'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bu ölçümü silmek istediğinize emin misiniz?',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bu işlem geri alınamaz!',
                        style: TextStyle(color: Colors.orange, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Diyalog kapat
                Navigator.of(context).pop(); // Bottom sheet kapat
                
                try {
                  await _databaseService.deleteOlcum(olcum.id!);
                  _showSnackBar('Ölçüm başarıyla silindi');
                  
                  if (_secilenSporcu != null && _secilenSporcu!.id != null) {
                    _loadOlcumler(_secilenSporcu!.id!);
                  }
                } catch (e) {
                  _showSnackBar('Ölçüm silinirken hata: $e', isError: true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
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
            builder: (context) => const YatayProfilScreen(),
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
            builder: (context) => const DikeyProfilScreen(),
          ),
        );
        break;
      default:
        _showSnackBar('Bu test türü için detaylı analiz bulunmuyor', isError: true);
    }
  }
  Widget _buildSprintDetails(Olcum olcum) {
    // Kapı değerlerini topla
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
    
    if (kapiDegerler.length < 3) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Sprint analizi için yeterli kapı verisi bulunmuyor.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    
    // Gelişmiş sprint analizi kullan
    final kinematics = StatisticsHelper.calculateSprintKinematics(kapiDegerler);
    final times = kinematics['times'] as List<double>;
    final distances = kinematics['distances'] as List<double>;
    final velocities = kinematics['velocities'] as List<double>;
    final accelerations = kinematics['accelerations'] as List<double>;
    final splitTimes = kinematics['split_times'] as Map<String, double>;
    final splitVelocities = kinematics['split_velocities'] as Map<String, double>;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFE57373).withOpacity(0.1),
                const Color(0xFFE57373).withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.timer, color: Color(0xFFE57373)),
                  SizedBox(width: 8),
                  Text(
                    'Sprint Performans Özeti',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE57373),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Ana performans metrikleri
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSprintMetricCard(
                    title: 'Maks Hız',
                    value: velocities.isNotEmpty 
                        ? '${velocities.reduce(math.max).toStringAsFixed(2)} m/s' 
                        : '-',
                    icon: Icons.speed,
                    color: const Color(0xFF64B5F6),
                  ),
                  _buildSprintMetricCard(
                    title: 'Maks İvme',
                    value: accelerations.isNotEmpty 
                        ? '${accelerations.reduce(math.max).toStringAsFixed(2)} m/s²' 
                        : '-',
                    icon: Icons.trending_up,
                    color: const Color(0xFF81C784),
                  ),
                  _buildSprintMetricCard(
                    title: 'Toplam Süre',
                    value: times.isNotEmpty 
                        ? '${times.last.toStringAsFixed(3)} s' 
                        : '-',
                    icon: Icons.timer,
                    color: const Color(0xFFFFB74D),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              _buildImprovedSprintGraph(times, distances, velocities),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Kapı zamanları
        _buildMetricSection(
          title: 'Kapı Zamanları',
          icon: Icons.flag,
          color: const Color(0xFFE57373),
          children: kapiDegerler.entries.map((entry) {
            final kapiNo = entry.key;
            final kapiSure = entry.value;
            final mesafe = [0, 5, 10, 15, 20, 30, 40][kapiNo - 1];
            
            return _buildMetricTile(
              leadingWidget: CircleAvatar(
                backgroundColor: const Color(0xFFE57373).withOpacity(0.2),
                child: Text(
                  '$kapiNo',
                  style: const TextStyle(
                    color: Color(0xFFE57373),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: '$kapiNo. Kapı (${mesafe}m)',
              value: '${kapiSure.toStringAsFixed(3)} s',
            );
          }).toList(),
        ),
        
        // Split hızları
        if (splitVelocities.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildMetricSection(
            title: 'Bölüm Hızları',
            icon: Icons.speed,
            color: const Color(0xFF64B5F6),
            children: splitVelocities.entries.map((entry) {
              return _buildMetricTile(
                leadingWidget: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF64B5F6).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.speed, color: Color(0xFF64B5F6), size: 20),
                ),
                title: entry.key,
                value: '${entry.value.toStringAsFixed(2)} m/s',
              );
            }).toList(),
          ),
        ],
        
        // Split süreleri
        if (splitTimes.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildMetricSection(
            title: 'Bölüm Süreleri',
            icon: Icons.timer,
            color: const Color(0xFF81C784),
            children: splitTimes.entries.map((entry) {
              return _buildMetricTile(
                leadingWidget: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF81C784).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.timer, color: Color(0xFF81C784), size: 20),
                ),
                title: entry.key,
                value: '${entry.value.toStringAsFixed(3)} s',
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
Widget _buildSprintMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildImprovedSprintGraph(List<double> times, List<double> distances, List<double> velocities) {
    if (times.length < 2 || distances.length < 2) {
      return const Center(
        child: Text(
          'Grafik için yeterli veri yok',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Zaman-mesafe ve hız grafikleri için spots oluştur
    final timeDistanceSpots = <FlSpot>[];
    final velocitySpots = <FlSpot>[];
    
    for (int i = 0; i < times.length && i < distances.length; i++) {
      timeDistanceSpots.add(FlSpot(distances[i], times[i]));
    }
    
    for (int i = 0; i < times.length && i < velocities.length; i++) {
      velocitySpots.add(FlSpot(times[i], velocities[i]));
    }

    return Container(
      height: 280,
      padding: const EdgeInsets.only(right: 16, top: 8),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: TabBar(
                labelColor: const Color(0xFF1565C0),
                unselectedLabelColor: Colors.grey,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                tabs: const [
                  Tab(text: 'Zaman-Mesafe'),
                  Tab(text: 'Hız-Zaman'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                children: [
                  // Zaman-Mesafe grafiği
                  LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        horizontalInterval: 1,
                        verticalInterval: 10,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey.withOpacity(0.2),
                            strokeWidth: 1,
                          );
                        },
                        getDrawingVerticalLine: (value) {
                          return FlLine(
                            color: Colors.grey.withOpacity(0.2),
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
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text(
                                  '${value.toInt()}m',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            },
                            reservedSize: 30,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text(
                                  '${value.toStringAsFixed(1)}s',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            },
                            reservedSize: 40,
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: timeDistanceSpots,
                          isCurved: true,
                          color: const Color(0xFFE57373),
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) =>
                                FlDotCirclePainter(
                              radius: 5,
                              color: const Color(0xFFE57373),
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFE57373).withOpacity(0.3),
                                const Color(0xFFE57373).withOpacity(0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Hız-Zaman grafiği
                  LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        horizontalInterval: 2,
                        verticalInterval: 0.5,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey.withOpacity(0.2),
                            strokeWidth: 1,
                          );
                        },
                        getDrawingVerticalLine: (value) {
                          return FlLine(
                            color: Colors.grey.withOpacity(0.2),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text(
                                  '${value.toStringAsFixed(1)}s',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            },
                            reservedSize: 30,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 2,
                            getTitlesWidget: (value, meta) {
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text(
                                  '${value.toStringAsFixed(1)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            },
                            reservedSize: 40,
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: velocitySpots,
                          isCurved: true,
                          color: const Color(0xFF64B5F6),
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) =>
                                FlDotCirclePainter(
                              radius: 5,
                              color: const Color(0xFF64B5F6),
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF64B5F6).withOpacity(0.3),
                                const Color(0xFF64B5F6).withOpacity(0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildMetricSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required Widget leadingWidget,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          leadingWidget,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildJumpDetails(Olcum olcum) {
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
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _getTestTypeColor(olcum.olcumTuru).withOpacity(0.1),
                _getTestTypeColor(olcum.olcumTuru).withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getTestTypeIcon(olcum.olcumTuru),
                    color: _getTestTypeColor(olcum.olcumTuru),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${olcum.olcumTuru} Performans Özeti',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _getTestTypeColor(olcum.olcumTuru),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildJumpMetricCard(
                    title: 'Yükseklik',
                    value: yukseklik.deger != 0 
                        ? '${yukseklik.deger.toStringAsFixed(1)} cm' 
                        : '-',
                    icon: Icons.height,
                    color: const Color(0xFF64B5F6),
                  ),
                  _buildJumpMetricCard(
                    title: 'Uçuş Süresi',
                    value: ucusSuresi.deger != 0 
                        ? '${ucusSuresi.deger.toStringAsFixed(3)} s' 
                        : '-',
                    icon: Icons.timer,
                    color: const Color(0xFF81C784),
                  ),
                  _buildJumpMetricCard(
                    title: 'Güç',
                    value: guc.deger != 0 
                        ? '${guc.deger.toStringAsFixed(0)} W' 
                        : '-',
                    icon: Icons.bolt,
                    color: const Color(0xFFFFB74D),
                  ),
                ],
              ),
              
              if (olcum.olcumTuru.toUpperCase() == 'DJ' || 
                  olcum.olcumTuru.toUpperCase() == 'RJ') ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildJumpMetricCard(
                      title: 'Temas Süresi',
                      value: temasSuresi.deger != 0 
                          ? '${temasSuresi.deger.toStringAsFixed(3)} s' 
                          : '-',
                      icon: Icons.touch_app,
                      color: const Color(0xFF9575CD),
                    ),
                    _buildJumpMetricCard(
                      title: 'RSI',
                      value: rsi.deger != 0 
                          ? rsi.deger.toStringAsFixed(2) 
                          : '-',
                      icon: Icons.speed,
                      color: const Color(0xFFE57373),
                    ),
                    if (olcum.olcumTuru.toUpperCase() == 'RJ')
                      _buildJumpMetricCard(
                        title: 'Ritim',
                        value: ritim.deger != 0 
                            ? '${ritim.deger.toStringAsFixed(2)}/s' 
                            : '-',
                        icon: Icons.loop,
                        color: const Color(0xFF4DB6AC),
                      )
                    else
                      const SizedBox(width: 110),
                  ],
                ),
              ],
            ],
          ),
        ),
        
        if (olcum.olcumTuru.toUpperCase() == 'RJ' && flightSeries.isNotEmpty) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sıçrama Serisi Analizi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4DB6AC).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${flightSeries.length} sıçrama',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4DB6AC),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildRJGraph(flightSeries, heightSeries, contactSeries),
              ],
            ),
          ),
        ],
        
        const SizedBox(height: 24),
        _buildAllValuesSection(olcum),
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
      width: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAllValuesSection(Olcum olcum) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.list_alt, color: Colors.grey, size: 20),
                SizedBox(width: 8),
                Text(
                  'Tüm Ölçüm Değerleri',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          ...olcum.degerler.where((deger) {
            return !deger.degerTuru.startsWith('Flight') &&
                !deger.degerTuru.startsWith('Contact') &&
                !deger.degerTuru.startsWith('Height');
          }).map((deger) {
            String title = '';
            String unit = '';
            IconData icon = Icons.analytics;
            Color color = Colors.grey;
            
            switch (deger.degerTuru.toLowerCase()) {
              case 'yukseklik':
                title = 'Yükseklik';
                unit = 'cm';
                icon = Icons.height;
                color = const Color(0xFF64B5F6);
                break;
              case 'ucussuresi':
                title = 'Uçuş Süresi';
                unit = 's';
                icon = Icons.timer;
                color = const Color(0xFF81C784);
                break;
              case 'temassuresi':
                title = 'Temas Süresi';
                unit = 's';
                icon = Icons.touch_app;
                color = const Color(0xFF9575CD);
                break;
              case 'guc':
                title = 'Güç';
                unit = 'W';
                icon = Icons.bolt;
                color = const Color(0xFFFFB74D);
                break;
              case 'rsi':
                title = 'RSI';
                unit = '';
                icon = Icons.speed;
                color = const Color(0xFFE57373);
                break;
              case 'ritim':
                title = 'Ritim';
                unit = 'sıçrama/s';
                icon = Icons.repeat;
                color = const Color(0xFF4DB6AC);
                break;
              default:
                title = deger.degerTuru;
            }
            
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.withOpacity(0.1)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Text(
                    '${deger.deger.toStringAsFixed(2)} $unit',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildRJGraph(
    List<double> flightTimes,
    List<double> jumpHeights,
    List<double> contactTimes,
  ) {
    return SizedBox(
      height: 250,
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: TabBar(
                labelColor: const Color(0xFF1565C0),
                unselectedLabelColor: Colors.grey,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                tabs: const [
                  Tab(text: 'Yükseklik'),
                  Tab(text: 'Uçuş'),
                  Tab(text: 'Temas'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                children: [
                  jumpHeights.isNotEmpty
                      ? _buildBarChart(
                          data: jumpHeights,
                          barColor: const Color(0xFF64B5F6),
                          title: 'cm',
                          maxY: jumpHeights.reduce(math.max) * 1.2,
                        )
                      : const Center(child: Text('Veri yok')),
                  flightTimes.isNotEmpty
                      ? _buildBarChart(
                          data: flightTimes,
                          barColor: const Color(0xFF81C784),
                          title: 's',
                          maxY: flightTimes.reduce(math.max) * 1.2,
                        )
                      : const Center(child: Text('Veri yok')),
                  contactTimes.isNotEmpty
                      ? _buildBarChart(
                          data: contactTimes,
                          barColor: const Color(0xFFFFB74D),
                          title: 's',
                          maxY: contactTimes.reduce(math.max) * 1.2,
                        )
                      : const Center(child: Text('Veri yok')),
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
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blueGrey.withOpacity(0.9),
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${(groupIndex + 1)}. sıçrama\n${data[groupIndex].toStringAsFixed(2)} $title',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() % 5 == 0 || value.toInt() == 0) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      '${(value + 1).toInt()}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const SizedBox.shrink();
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
                  child: Text(
                    value.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(color: Colors.grey.withOpacity(0.3)),
            bottom: BorderSide(color: Colors.grey.withOpacity(0.3)),
          ),
        ),
        barGroups: List.generate(
          data.length,
          (index) => BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: data[index],
                gradient: LinearGradient(
                  colors: [
                    barColor,
                    barColor.withOpacity(0.7),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                width: data.length > 20 ? 8 : 16,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget buildKontrolluPerformansGrafik(
  List<double> data, {
  String title = 'Performans Zaman Serisi',
  String unit = '',
  Color mainColor = Colors.blue,
}) {
  if (data.isEmpty) {
    return const Center(child: Text('Veri yok'));
  }
  final mean = data.reduce((a, b) => a + b) / data.length;
  final stdDev = math.sqrt(data.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) / data.length);

  final spots = List.generate(data.length, (i) => FlSpot(i.toDouble(), data[i]));
  final meanLine = List.generate(data.length, (i) => FlSpot(i.toDouble(), mean));
  final upperLimit = List.generate(data.length, (i) => FlSpot(i.toDouble(), mean + 2 * stdDev));
  final lowerLimit = List.generate(data.length, (i) => FlSpot(i.toDouble(), mean - 2 * stdDev));

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 8),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      SizedBox(
        height: 230,
        child: LineChart(
          LineChartData(
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: mainColor,
                barWidth: 3,
                dotData: FlDotData(show: true),
              ),
              LineChartBarData(
                spots: meanLine,
                isCurved: false,
                color: Colors.green,
                barWidth: 2,
                dashArray: [8, 4],
                dotData: FlDotData(show: false),
              ),
              LineChartBarData(
                spots: upperLimit,
                isCurved: false,
                color: Colors.red,
                barWidth: 1,
                dashArray: [4, 4],
                dotData: FlDotData(show: false),
              ),
              LineChartBarData(
                spots: lowerLimit,
                isCurved: false,
                color: Colors.red,
                barWidth: 1,
                dashArray: [4, 4],
                dotData: FlDotData(show: false),
              ),
            ],
            minY: (lowerLimit.map((e) => e.y).reduce(math.min) * 0.98),
            maxY: (upperLimit.map((e) => e.y).reduce(math.max) * 1.02),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) => Text('${value.toInt() + 1}'),
                  reservedSize: 24,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) => Text('${value.toStringAsFixed(1)}$unit'),
                  reservedSize: 40,
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: stdDev,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey.withOpacity(0.15),
                  strokeWidth: 1,
                );
              },
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
          ),
        ),
      ),
    ],
  );
}