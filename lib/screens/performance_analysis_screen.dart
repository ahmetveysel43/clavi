import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Tarih formatlama için eklendi
import '../models/sporcu_model.dart';
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

class _PerformanceAnalysisScreenState extends State<PerformanceAnalysisScreen> with TickerProviderStateMixin {
  final _databaseService = DatabaseService();
  final _performanceService = PerformanceAnalysisService();
  
  bool _isLoading = true;
  Sporcu? _secilenSporcu;
  List<Sporcu> _sporcular = [];
  String _secilenOlcumTuru = '';
  String _secilenDegerTuru = '';
  
  // Animasyon kontrolcüleri
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Analiz sonuçları
  Map<String, dynamic>? _analysis;
  
  // Filtre seçenekleri
  final List<String> _olcumTurleri = ['Sprint', 'CMJ', 'SJ', 'DJ', 'RJ'];
  final Map<String, List<String>> _degerTurleri = {
    'Sprint': ['Kapi7', 'Kapi6', 'Kapi5', 'Kapi4', 'Kapi3', 'Kapi2', 'Kapi1'],
    'CMJ': ['Yukseklik', 'UcusSuresi', 'Guc'],
    'SJ': ['Yukseklik', 'UcusSuresi', 'Guc'],
    'DJ': ['Yukseklik', 'UcusSuresi', 'Guc', 'TemasSuresi', 'RSI'],
    'RJ': ['Yukseklik', 'UcusSuresi', 'Guc', 'TemasSuresi', 'RSI', 'Ritim'],
  };
  
  // Zaman aralığı filtresi
  String _selectedTimeRange = 'Son 90 Gün';
  final List<String> _timeRanges = [
    'Son 30 Gün',
    'Son 90 Gün',
    'Son 6 Ay',
    'Son 1 Yıl',
    'Tümü',
    'Özel Tarih Aralığı', // Yeni seçenek eklendi
  ];
  int _selectedDays = 90;
  DateTime? _startDate; // Özel tarih aralığı için eklendi
  DateTime? _endDate; // Özel tarih aralığı için eklendi

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadInitialData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() => _isLoading = true);
      
      _sporcular = await _databaseService.getAllSporcular();
      
      if (widget.sporcuId != null) {
        try {
          _secilenSporcu = await _databaseService.getSporcu(widget.sporcuId!);
        } catch (e) {
          debugPrint('Sporcu yüklenirken hata: $e');
          if (_sporcular.isNotEmpty) {
            _secilenSporcu = _sporcular.first;
          }
        }
      } else if (_sporcular.isNotEmpty) {
        _secilenSporcu = _sporcular.first;
      }
      
      if (widget.olcumTuru != null && _olcumTurleri.contains(widget.olcumTuru)) {
        _secilenOlcumTuru = widget.olcumTuru!;
      } else if (_olcumTurleri.isNotEmpty) {
        _secilenOlcumTuru = _olcumTurleri.first;
      }
      
      if (_secilenOlcumTuru.isNotEmpty && _degerTurleri.containsKey(_secilenOlcumTuru)) {
        _secilenDegerTuru = _degerTurleri[_secilenOlcumTuru]!.first;
      }
      
      if (_secilenSporcu != null && _secilenOlcumTuru.isNotEmpty && _secilenDegerTuru.isNotEmpty) {
        await _loadAnalysis();
      }
      
      _animationController.forward();
    } catch (e) {
      _showSnackBar('Veriler yüklenirken hata: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadAnalysis() async {
    if (_secilenSporcu == null || _secilenOlcumTuru.isEmpty || _secilenDegerTuru.isEmpty) {
      return;
    }
    
    try {
      setState(() => _isLoading = true);
      
      _analysis = await _performanceService.getPerformanceSummary(
        sporcuId: _secilenSporcu!.id!,
        olcumTuru: _secilenOlcumTuru,
        degerTuru: _secilenDegerTuru,
        lastNDays: _selectedTimeRange == 'Özel Tarih Aralığı' ? null : _selectedDays, // Özel aralıkta null
        startDate: _selectedTimeRange == 'Özel Tarih Aralığı' ? _startDate : null, // Özel tarih başlangıcı
        endDate: _selectedTimeRange == 'Özel Tarih Aralığı' ? _endDate : null, // Özel tarih bitişi
      );
      
    } catch (e) {
      _showSnackBar('Analiz yüklenirken hata: $e', isError: true);
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

  void _onTimeRangeChanged(String? value) {
    if (value == null) return;
    
    setState(() {
      _selectedTimeRange = value;
      
      switch (value) {
        case 'Son 30 Gün':
          _selectedDays = 30;
          _startDate = null; // Özel tarih sıfırlanır
          _endDate = null; // Özel tarih sıfırlanır
          break;
        case 'Son 90 Gün':
          _selectedDays = 90;
          _startDate = null;
          _endDate = null;
          break;
        case 'Son 6 Ay':
          _selectedDays = 180;
          _startDate = null;
          _endDate = null;
          break;
        case 'Son 1 Yıl':
          _selectedDays = 365;
          _startDate = null;
          _endDate = null;
          break;
        case 'Tümü':
          _selectedDays = 3650;
          _startDate = null;
          _endDate = null;
          break;
        case 'Özel Tarih Aralığı':
          // Tarih seçici zaten _showTimeRangeDialog içinde açılıyor
          _selectedDays = 0; // Gün sayısı kullanılmayacak
          break;
      }
      
      _loadAnalysis();
    });
  }

  void _onSporcuChanged(int? sporcuId) {
    if (sporcuId == null) return;
    
    final selectedSporcu = _sporcular.firstWhere(
      (s) => s.id == sporcuId,
      orElse: () => _sporcular.first,
    );
    
    setState(() {
      _secilenSporcu = selectedSporcu;
      _analysis = null;
    });
    
    _loadAnalysis();
  }

  void _onOlcumTuruChanged(String? olcumTuru) {
    if (olcumTuru == null || olcumTuru == _secilenOlcumTuru) return;
    
    setState(() {
      _secilenOlcumTuru = olcumTuru;
      
      if (_degerTurleri.containsKey(_secilenOlcumTuru)) {
        _secilenDegerTuru = _degerTurleri[_secilenOlcumTuru]!.first;
      }
      
      _analysis = null;
    });
    
    _loadAnalysis();
  }

  void _onDegerTuruChanged(String? degerTuru) {
    if (degerTuru == null || degerTuru == _secilenDegerTuru) return;
    
    setState(() {
      _secilenDegerTuru = degerTuru;
      _analysis = null;
    });
    
    _loadAnalysis();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadAnalysis,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        _buildQuickSelections(),
                        _buildAnalysisResults(),
                        const SizedBox(height: 80), // Bottom navigation için boşluk
                      ],
                    ),
                  ),
                ),
              ),
            ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF42A5F5), Color(0xFF2196F3)],
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
              Flexible(
                flex: 3,
                child: Row(
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
                    const SizedBox(width: 12),
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Performans Analizi',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          Text(
                            'İstatistiksel Değerlendirme',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 48,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                    onPressed: _loadAnalysis,
                    tooltip: 'Yenile',
                  ),
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
                      'Seçili Sporcu: ${_secilenSporcu!.ad} ${_secilenSporcu!.soyad}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_secilenOlcumTuru.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _secilenOlcumTuru,
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

  Widget _buildQuickSelections() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analiz Parametreleri',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          // Sporcu ve Ölçüm Türü Seçimi
          Row(
            children: [
              Expanded(
                child: _buildSelectionCard(
                  'Sporcu Seçimi',
                  'Analiz edilecek sporcu',
                  Icons.person,
                  const Color(0xFF2196F3),
                  () => _showSporcuSecimDialog(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSelectionCard(
                  'Test Türü',
                  'Analiz edilecek test',
                  Icons.category,
                  const Color(0xFF4CAF50),
                  () => _showTestTuruSecimDialog(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Değer Türü ve Zaman Aralığı
          Row(
            children: [
              Expanded(
                child: _buildSelectionCard(
                  'Değer Türü',
                  _secilenDegerTuru.isEmpty ? 'Değer seçin' : _secilenDegerTuru,
                  Icons.timeline,
                  const Color(0xFFFF9800),
                  () => _showDegerTuruSecimDialog(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSelectionCard(
                  'Zaman Aralığı',
                  _selectedTimeRange == 'Özel Tarih Aralığı' && _startDate != null && _endDate != null
                      ? '${DateFormat('dd.MM.yyyy').format(_startDate!)} - ${DateFormat('dd.MM.yyyy').format(_endDate!)}'
                      : _selectedTimeRange,
                  Icons.date_range,
                  const Color(0xFF9C27B0),
                  () => _showTimeRangeDialog(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisResults() {
    if (_analysis == null) {
      return _buildEmptyState();
    }
    
    if (_analysis!.containsKey('error')) {
      return _buildErrorMessage(_analysis!['error']);
    }

    // Birim belirle
    String unit = '';
    bool isHigherBetter = true;
    
    switch (_secilenDegerTuru.toLowerCase()) {
      case 'yukseklik':
        unit = 'cm';
        isHigherBetter = true;
        break;
      case 'ucussuresi':
        unit = 's';
        isHigherBetter = true;
        break;
      case 'guc':
        unit = 'W';
        isHigherBetter = true;
        break;
      case 'temassuresi':
        unit = 's';
        isHigherBetter = false;
        break;
      case 'kapi1':
      case 'kapi2':
      case 'kapi3':
      case 'kapi4':
      case 'kapi5':
      case 'kapi6':
      case 'kapi7':
        unit = 's';
        isHigherBetter = false;
        break;
      default:
        unit = '';
        break;
    }

    final performanceValues = List<double>.from(_analysis!['performanceValues'] ?? []);
    final dates = List<String>.from(_analysis!['dates'] ?? []);
    
    final summaryData = {
      'mean': _analysis!['mean'] ?? 0.0,
      'stdDev': _analysis!['standardDeviation'] ?? 0.0,
      'cvPercentage': _analysis!['coefficientOfVariation'] ?? 0.0,
      'typicalityIndex': _analysis!['typicalityIndex'] ?? 0.0,
      'trend': _analysis!['trendSlope'] ?? 0.0,
      'firstDate': dates.isNotEmpty ? dates.first : '',
      'lastDate': dates.isNotEmpty ? dates.last : '',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analiz Sonuçları',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Performans Özeti
          PerformanceVisualizationHelper.buildPerformanceSummaryCard(
            analysis: summaryData,
            title: 'Performans Özeti - $_secilenDegerTuru',
            unit: unit,
            color: const Color(0xFF42A5F5),
            isHigherBetter: isHigherBetter,
          ),

          const SizedBox(height: 20),

          // Performans Trendi
          Container(
            padding: const EdgeInsets.all(16),
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
            child: PerformanceVisualizationHelper.buildPerformanceTrendChart(
              performanceValues: performanceValues,
              dates: dates,
              swc: _analysis!['swc'] as double?,
              mdc: _analysis!['mdc'] as double?,
              isHigherBetter: isHigherBetter,
              title: 'Performans Trendi',
              yAxisLabel: '$_secilenDegerTuru ($unit)',
              lineColor: const Color(0xFF42A5F5),
            ),
          ),

          const SizedBox(height: 20),

          // İstatistikler
          _buildStatsSection(),

          const SizedBox(height: 20),

          // Güvenilirlik Metrikleri
          _buildReliabilitySection(),

          const SizedBox(height: 20),

          // Performans Değerlendirmesi
          if (performanceValues.length >= 2)
            _buildDevelopmentComment(
              performanceValues: performanceValues,
              swc: _analysis!['swc'] as double?,
              mdc: _analysis!['mdc'] as double?,
              isHigherBetter: isHigherBetter,
            ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'İstatistikler',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Ortalama',
                  (_analysis!['mean'] as double?)?.toStringAsFixed(2) ?? '-',
                  Icons.trending_up,
                  const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Medyan',
                  (_analysis!['median'] as double?)?.toStringAsFixed(2) ?? '-',
                  Icons.vertical_align_center,
                  const Color(0xFF2196F3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Std Sapma',
                  (_analysis!['standardDeviation'] as double?)?.toStringAsFixed(3) ?? '-',
                  Icons.show_chart,
                  const Color(0xFFFF9800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'CV (%)',
                  (_analysis!['coefficientOfVariation'] as double?)?.toStringAsFixed(1) ?? '-',
                  Icons.percent,
                  const Color(0xFF9C27B0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Minimum',
                  (_analysis!['minimum'] as double?)?.toStringAsFixed(2) ?? '-',
                  Icons.keyboard_arrow_down,
                  const Color(0xFFF44336),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Maksimum',
                  (_analysis!['maximum'] as double?)?.toStringAsFixed(2) ?? '-',
                  Icons.keyboard_arrow_up,
                  const Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReliabilitySection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Güvenilirlik Metrikleri',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'SWC',
                  (_analysis!['swc'] as double?)?.toStringAsFixed(3) ?? '-',
                  Icons.timeline,
                  const Color(0xFF2196F3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'MDC',
                  (_analysis!['mdc'] as double?)?.toStringAsFixed(3) ?? '-',
                  Icons.track_changes,
                  const Color(0xFF9C27B0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Tutarlılık',
                  '${(_analysis!['typicalityIndex'] as double?)?.toStringAsFixed(0) ?? '-'}/100',
                  Icons.approval,
                  const Color(0xFF4CAF50),
                ),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDevelopmentComment({
    required List<double> performanceValues,
    required double? swc,
    required double? mdc,
    required bool isHigherBetter,
  }) {
    if (performanceValues.isEmpty) {
      return const SizedBox.shrink();
    }

    String comment = "Değerlendirme:\n";
    final latestValue = performanceValues.last;
    final previousValue = performanceValues.length > 1 ? performanceValues[performanceValues.length - 2] : null;

    if (previousValue != null) {
      final change = latestValue - previousValue;
      comment += "Son Değişim: ${change.toStringAsFixed(2)}\n";

      if (mdc != null && change.abs() > mdc) {
        comment += "Bu değişim MDC (${mdc.toStringAsFixed(2)}) değerinden büyük ve anlamlı.\n";
      } else if (mdc != null) {
        comment += "Bu değişim MDC (${mdc.toStringAsFixed(2)}) sınırları içinde.\n";
      }

      if (swc != null && change.abs() > swc) {
        comment += "Bu değişim SWC (${swc.toStringAsFixed(2)}) değerinden büyük ve pratik olarak önemli.\n";
      } else if (swc != null) {
        comment += "Bu değişim SWC (${swc.toStringAsFixed(2)}) sınırları içinde, minimal bir değişim.\n";
      }
    } else {
      comment += "Karşılaştırma için yeterli veri yok.\n";
    }
    
    if (isHigherBetter) {
      comment += "Bu metrik için yüksek değerler daha iyidir.";
    } else {
      comment += "Bu metrik için düşük değerler daha iyidir.";
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF42A5F5).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF42A5F5).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: Color(0xFF42A5F5)),
              const SizedBox(width: 8),
              const Text(
                'Performans Değerlendirmesi',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF42A5F5),
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            comment,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(String error) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 16),
            const Text(
              'Analiz Hatası',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                color: Colors.red[800],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(20),
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
              'Analiz Başlatın',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Performans analizi için sporcu ve ölçüm türü seçin',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                if (_secilenSporcu != null && _secilenOlcumTuru.isNotEmpty && _secilenDegerTuru.isNotEmpty) {
                  _loadAnalysis();
                } else {
                  _showSnackBar('Lütfen önce tüm parametreleri seçin', isError: true);
                }
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Analizi Başlat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF42A5F5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dialog metodları
  void _showSporcuSecimDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.person, color: Color(0xFF2196F3)),
            SizedBox(width: 8),
            Text('Sporcu Seçin'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: _sporcular.length,
            itemBuilder: (context, index) {
              final sporcu = _sporcular[index];
              final isSelected = _secilenSporcu?.id == sporcu.id;
              
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: isSelected ? const Color(0xFF2196F3).withOpacity(0.1) : null,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSelected ? const Color(0xFF2196F3) : Colors.grey[300],
                    child: Text(
                      '${sporcu.ad[0]}${sporcu.soyad[0]}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text('${sporcu.ad} ${sporcu.soyad}'),
                  subtitle: Text('Yaş: ${sporcu.yas} • ${sporcu.cinsiyet}'),
                  trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF2196F3)) : null,
                  onTap: () {
                    Navigator.pop(context);
                    _onSporcuChanged(sporcu.id);
                  },
                ),
              );
            },
          ),
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

  void _showTestTuruSecimDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.category, color: Color(0xFF4CAF50)),
            SizedBox(width: 8),
            Text('Test Türü Seçin'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _olcumTurleri.map((tur) {
            final isSelected = _secilenOlcumTuru == tur;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: isSelected ? const Color(0xFF4CAF50).withOpacity(0.1) : null,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isSelected ? const Color(0xFF4CAF50) : Colors.grey[300],
                  child: Icon(
                    tur == 'Sprint' ? Icons.directions_run : Icons.height,
                    color: isSelected ? Colors.white : Colors.grey[600],
                  ),
                ),
                title: Text(tur),
                trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF4CAF50)) : null,
                onTap: () {
                  Navigator.pop(context);
                  _onOlcumTuruChanged(tur);
                },
              ),
            );
          }).toList(),
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

  void _showDegerTuruSecimDialog() {
    if (_secilenOlcumTuru.isEmpty || !_degerTurleri.containsKey(_secilenOlcumTuru)) {
      _showSnackBar('Önce test türünü seçin', isError: true);
      return;
    }

    final degerTurleri = _degerTurleri[_secilenOlcumTuru]!;
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.timeline, color: Color(0xFFFF9800)),
            SizedBox(width: 8),
            Text('Değer Türü Seçin'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: degerTurleri.map((tur) {
            final isSelected = _secilenDegerTuru == tur;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: isSelected ? const Color(0xFFFF9800).withOpacity(0.1) : null,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isSelected ? const Color(0xFFFF9800) : Colors.grey[300],
                  child: Icon(
                    Icons.timeline,
                    color: isSelected ? Colors.white : Colors.grey[600],
                  ),
                ),
                title: Text(tur),
                trailing: isSelected ? const Icon(Icons.check, color: Color(0xFFFF9800)) : null,
                onTap: () {
                  Navigator.pop(context);
                  _onDegerTuruChanged(tur);
                },
              ),
            );
          }).toList(),
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

  void _showTimeRangeDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.date_range, color: Color(0xFF9C27B0)),
            SizedBox(width: 8),
            Text('Zaman Aralığı Seçin'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _timeRanges.map((range) {
            final isSelected = _selectedTimeRange == range;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: isSelected ? const Color(0xFF9C27B0).withOpacity(0.1) : null,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isSelected ? const Color(0xFF9C27B0) : Colors.grey[300],
                  child: Icon(
                    Icons.date_range,
                    color: isSelected ? Colors.white : Colors.grey[600],
                  ),
                ),
                title: Text(range),
                trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF9C27B0)) : null,
                onTap: () async {
                  Navigator.pop(context);
                  if (range == 'Özel Tarih Aralığı') {
                    final DateTimeRange? picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      initialDateRange: _startDate != null && _endDate != null
                          ? DateTimeRange(start: _startDate!, end: _endDate!)
                          : DateTimeRange(
                              start: DateTime.now().subtract(const Duration(days: 1)),
                              end: DateTime.now(),
                            ),
                      builder: (context, child) {
                        return Theme(
                          data: ThemeData.light().copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Color(0xFF9C27B0),
                              onPrimary: Colors.white,
                              surface: Colors.white,
                              onSurface: Colors.black,
                            ),
                            dialogBackgroundColor: Colors.white,
                          ),
                          child: child!,
                        );
                      },
                    );

                    if (picked != null) {
                      setState(() {
                        _selectedTimeRange = 'Özel Tarih Aralığı';
                        _startDate = picked.start;
                        _endDate = picked.end;
                        _selectedDays = 0; // Özel aralıkta gün sayısı kullanılmaz
                      });
                      _loadAnalysis();
                    }
                  } else {
                    _onTimeRangeChanged(range);
                  }
                },
              ),
            );
          }).toList(),
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

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavButton(
              'Yenile',
              Icons.refresh,
              _loadAnalysis,
            ),
            _buildNavButton(
              'Paylaş',
              Icons.share,
              () => _showSnackBar('Paylaşım özelliği yakında!'),
            ),
            _buildNavButton(
              'Export',
              Icons.download,
              () => _showSnackBar('Export özelliği yakında!'),
            ),
            _buildNavButton(
              'Geri',
              Icons.arrow_back,
              () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF42A5F5).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF42A5F5), size: 20),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF42A5F5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}