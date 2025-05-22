import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'analiz_screen.dart';
import 'sprint_screen.dart';
import 'jump_screen.dart';
import 'sporcu_kayit_screen.dart';
import 'sporcu_secim_screen.dart';
import 'dikey_profil_screen.dart';
import 'yatay_profil_screen.dart';
import 'ilerleme_raporu_screen.dart';
import 'test_karsilastirma_screen.dart';
import '../models/sporcu_model.dart';
import '../services/database_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  List<Sporcu> _athletes = [];
  int? _selectedSporcuId;
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // İstatistik verileri
  int _toplamSporcu = 0;
  int _buHaftaTest = 0;
  int _aktifTest = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadData();
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

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      
      final sporcular = await DatabaseService().getAllSporcular();
      
      if (mounted) {
        setState(() {
          _athletes = sporcular.take(5).toList();
          _toplamSporcu = sporcular.length;
          _buHaftaTest = 12; // Bu değer veritabanından hesaplanabilir
          _aktifTest = 3;    // Bu değer veritabanından hesaplanabilir
          _isLoading = false;
        });
        
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Veriler yüklenirken hata: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _exportData() async {
    try {
      final sporcular = await DatabaseService().getAllSporcular();
      final csv = StringBuffer('ID,Ad,Soyad,Yaş,Cinsiyet,Branş,Kulüp,Boy,Kilo\n');
      
      for (var s in sporcular) {
        csv.writeln(
          '${s.id},${s.ad},${s.soyad},${s.yas},${s.cinsiyet},${s.brans ?? ""},${s.kulup ?? ""},${s.boy ?? ""},${s.kilo ?? ""}'
        );
      }
      
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/sporcular_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csv.toString());
      
      _showSuccessSnackBar('Export başarılı! Dosya: ${file.path}');
    } catch (e) {
      _showErrorSnackBar('Export sırasında hata: $e');
    }
  }

  void _navigateToTest(String testType) {
    if (_selectedSporcuId == null) {
      _showSporcuSecimDialog(testType);
    } else {
      _navigateToTestScreen(testType, _selectedSporcuId);
    }
  }

  void _showSporcuSecimDialog(String testType) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              testType == 'sprint' ? Icons.directions_run : Icons.height,
              color: const Color(0xFF1565C0),
            ),
            const SizedBox(width: 8),
            const Text('Sporcu Seçimi'),
          ],
        ),
        content: const Text(
          'Test başlatmak için önce bir sporcu seçmek ister misiniz?'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToTestScreen(testType, null);
            },
            child: const Text('Hayır, Devam Et'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToSporcuSecim(testType);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
            ),
            child: const Text(
              'Evet, Sporcu Seç',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToSporcuSecim(String testType) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SporcuSecimScreen()),
    ).then((selectedId) {
      if (selectedId != null && mounted) {
        setState(() => _selectedSporcuId = selectedId);
        _navigateToTestScreen(testType, selectedId);
      }
    });
  }

  void _navigateToTestScreen(String testType, int? sporcuId) {
    if (!mounted) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => testType == 'sprint'
            ? SprintScreen(sporcuId: sporcuId)
            : JumpScreen(sporcuId: sporcuId),
      ),
    );
  }

  void _navigateToAnalysisScreen() {
    if (_selectedSporcuId == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AnalizScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnalizScreen(initialSporcuId: _selectedSporcuId),
        ),
      );
    }
  }

  void _navigateToIlerlemeRaporu() {
    if (_selectedSporcuId == null) {
      _showSporcuGerekmesiDialog('İlerleme Raporu');
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IlerlemeRaporuScreen(sporcuId: _selectedSporcuId!),
        ),
      );
    }
  }

  void _navigateToTestKarsilastirma() {
    if (_selectedSporcuId == null) {
      _showSporcuGerekmesiDialog('Test Karşılaştırması');
    } else {
      _showTestTuruSecimDialog();
    }
  }

  void _showSporcuGerekmesiDialog(String feature) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.person, color: Color(0xFF1565C0)),
            const SizedBox(width: 8),
            Text('$feature için Sporcu Seçimi'),
          ],
        ),
        content: Text(
          '$feature özelliğini kullanmak için önce bir sporcu seçmelisiniz.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SporcuSecimScreen()),
              ).then((selectedId) {
                if (selectedId != null && mounted) {
                  setState(() => _selectedSporcuId = selectedId);
                  
                  if (feature == 'İlerleme Raporu') {
                    _navigateToIlerlemeRaporu();
                  } else if (feature == 'Test Karşılaştırması') {
                    _navigateToTestKarsilastirma();
                  }
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
            ),
            child: const Text(
              'Sporcu Seç',
              style: TextStyle(color: Colors.white),
            ),
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
            Icon(Icons.compare_arrows, color: Color(0xFF1565C0)),
            SizedBox(width: 8),
            Text('Test Türü Seçin'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Karşılaştırmak istediğiniz test türünü seçin'),
            const SizedBox(height: 16),
            ...['Sprint', 'CMJ', 'SJ', 'DJ', 'RJ'].map((type) {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getTestTypeColor(type).withOpacity(0.2),
                    child: Icon(_getTestTypeIcon(type), color: _getTestTypeColor(type)),
                  ),
                  title: Text(type),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TestKarsilastirmaScreen(
                          sporcuId: _selectedSporcuId!,
                          testType: type,
                        ),
                      ),
                    );
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
      default: return Icons.height;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        _buildQuickActions(),
                        _buildStats(),
                        _buildAdvancedAnalysis(),
                        _buildRecentAthletes(),
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 40,
                      width: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.sports, color: Colors.white),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'İzLab Sports',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'izSel Hibrit',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
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
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _loadData,
                  tooltip: 'Yenile',
                ),
              ),
            ],
          ),
          if (_selectedSporcuId != null) ...[
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
                  Text(
                    'Seçili Sporcu: ${_athletes.firstWhere((a) => a.id == _selectedSporcuId, orElse: () => Sporcu(ad: 'Bilinmeyen', soyad: '', yas: 0, cinsiyet: '')).ad}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _selectedSporcuId = null),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
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

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hızlı Testler',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTestCard(
                  'Sprint Testi',
                  'Hız ve ivmelenme ölçümü',
                  Icons.speed,
                  const Color(0xFFFF5252),
                  () => _navigateToTest('sprint'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTestCard(
                  'Sıçrama Testi',
                  'Dikey sıçrama analizi',
                  Icons.trending_up,
                  const Color(0xFF448AFF),
                  () => _navigateToTest('jump'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hızlı İstatistikler',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Toplam Sporcu',
                  _toplamSporcu.toString(),
                  Icons.people,
                  const Color(0xFF1E88E5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Bu Hafta',
                  _buHaftaTest.toString(),
                  Icons.calendar_today,
                  const Color(0xFF43A047),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Aktif Test',
                  _aktifTest.toString(),
                  Icons.assessment,
                  const Color(0xFFFB8C00),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedAnalysis() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gelişmiş Analizler',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildAnalysisCard(
                  'İlerleme Raporu',
                  'Zaman içindeki gelişimi görüntüle',
                  Icons.trending_up,
                  const Color(0xFF4DB6AC),
                  _navigateToIlerlemeRaporu,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAnalysisCard(
                  'Test Karşılaştırma',
                  'Farklı testleri karşılaştır',
                  Icons.compare_arrows,
                  const Color(0xFF9575CD),
                  _navigateToTestKarsilastirma,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildAnalysisCard(
                  'Dikey Profil',
                  'Sıçrama performansı analizi',
                  Icons.show_chart,
                  const Color(0xFF64B5F6),
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DikeyProfilScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAnalysisCard(
                  'Yatay Profil',
                  'Sprint performansı analizi',
                  Icons.swap_horiz,
                  const Color(0xFFE57373),
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const YatayProfilScreen()),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAthletes() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Son Sporcular',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SporcuSecimScreen()),
                ),
                child: const Text('Tümünü Gör', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_athletes.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.person_add, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Henüz sporcu kaydı yok',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SporcuKayitScreen()),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('İlk Sporcuyu Ekle'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...List.generate(
              _athletes.length,
              (index) => _buildAthleteCard(_athletes[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildTestCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
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
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAthleteCard(Sporcu sporcu) {
    final isSelected = _selectedSporcuId == sporcu.id;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFF1E88E5) : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        onTap: () {
          setState(() => _selectedSporcuId = sporcu.id);
         _showSuccessSnackBar('${sporcu.ad} ${sporcu.soyad} seçildi');
       },
       contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
       leading: CircleAvatar(
         radius: 24,
         backgroundColor: isSelected ? const Color(0xFF1E88E5) : const Color(0xFFE3F2FD),
         child: Text(
           '${sporcu.ad[0]}${sporcu.soyad[0]}'.toUpperCase(),
           style: TextStyle(
             color: isSelected ? Colors.white : const Color(0xFF1E88E5),
             fontWeight: FontWeight.bold,
           ),
         ),
       ),
       title: Text(
         '${sporcu.ad} ${sporcu.soyad}',
         style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
       ),
       subtitle: Text('Yaş: ${sporcu.yas} • ${sporcu.cinsiyet}'),
       trailing: isSelected
           ? Container(
               padding: const EdgeInsets.all(6),
               decoration: const BoxDecoration(
                 color: Color(0xFF1E88E5),
                 shape: BoxShape.circle,
               ),
               child: const Icon(Icons.check, color: Colors.white, size: 16),
             )
           : Icon(Icons.chevron_right, color: Colors.grey[400]),
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
             'Sporcu Ekle',
             Icons.person_add,
             () => Navigator.push(
               context,
               MaterialPageRoute(builder: (_) => const SporcuKayitScreen()),
             ).then((_) => _loadData()),
           ),
           _buildNavButton(
             'Analiz',
             Icons.analytics,
             _navigateToAnalysisScreen,
           ),
           _buildNavButton(
             'Export',
             Icons.cloud_download,
             _exportData,
           ),
           _buildNavButton(
             'Ayarlar',
             Icons.settings,
             () => _showSettingsDialog(),
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
               color: const Color(0xFF1565C0).withOpacity(0.1),
               borderRadius: BorderRadius.circular(8),
             ),
             child: Icon(icon, color: const Color(0xFF1565C0), size: 20),
           ),
           const SizedBox(height: 4),
           Text(
             label,
             style: const TextStyle(
               fontSize: 11,
               fontWeight: FontWeight.w600,
               color: Color(0xFF1565C0),
             ),
             textAlign: TextAlign.center,
           ),
         ],
       ),
     ),
   );
 }

 void _showSettingsDialog() {
   showDialog(
     context: context,
     builder: (_) => AlertDialog(
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
       title: const Row(
         children: [
           Icon(Icons.settings, color: Color(0xFF1565C0)),
           SizedBox(width: 8),
           Text('Ayarlar'),
         ],
       ),
       content: Column(
         mainAxisSize: MainAxisSize.min,
         children: [
           ListTile(
             leading: const Icon(Icons.delete_sweep, color: Colors.red),
             title: const Text('Veritabanını Temizle'),
             subtitle: const Text('Tüm veriler silinecek'),
             onTap: () => _showClearDatabaseDialog(),
           ),
           ListTile(
             leading: const Icon(Icons.backup, color: Color(0xFF1565C0)),
             title: const Text('Test Verisi Oluştur'),
             subtitle: const Text('Örnek veriler ekle'),
             onTap: () => _populateTestData(),
           ),
           ListTile(
             leading: const Icon(Icons.info, color: Color(0xFF1565C0)),
             title: const Text('Uygulama Hakkında'),
             onTap: () => _showAboutDialog(),
           ),
         ],
       ),
       actions: [
         TextButton(
           onPressed: () => Navigator.pop(context),
           child: const Text('Kapat'),
         ),
       ],
     ),
   );
 }

 void _showClearDatabaseDialog() {
   Navigator.pop(context); // Ayarlar dialog'unu kapat
   
   showDialog(
     context: context,
     builder: (_) => AlertDialog(
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
       title: const Row(
         children: [
           Icon(Icons.warning, color: Colors.red),
           SizedBox(width: 8),
           Text('Dikkat!'),
         ],
       ),
       content: const Text(
         'Bu işlem tüm sporcu verilerini ve ölçümleri kalıcı olarak silecektir. '
         'Bu işlem geri alınamaz. Devam etmek istediğinizden emin misiniz?'
       ),
       actions: [
         TextButton(
           onPressed: () => Navigator.pop(context),
           child: const Text('İptal'),
         ),
         ElevatedButton(
           onPressed: () async {
             Navigator.pop(context);
             try {
               await DatabaseService().deleteDatabaseFile();
               setState(() {
                 _athletes.clear();
                 _selectedSporcuId = null;
                 _toplamSporcu = 0;
               });
               _showSuccessSnackBar('Veritabanı başarıyla temizlendi');
             } catch (e) {
               _showErrorSnackBar('Veritabanı temizlenirken hata: $e');
             }
           },
           style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
           child: const Text('Sil', style: TextStyle(color: Colors.white)),
         ),
       ],
     ),
   );
 }

 void _populateTestData() {
   Navigator.pop(context); // Ayarlar dialog'unu kapat
   
   showDialog(
     context: context,
     builder: (_) => AlertDialog(
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
       title: const Row(
         children: [
           Icon(Icons.backup, color: Color(0xFF1565C0)),
           SizedBox(width: 8),
           Text('Test Verisi Oluştur'),
         ],
       ),
       content: const Text(
         'Örnek sporcu verileri ve ölçümler oluşturulacak. '
         'Bu işlem birkaç dakika sürebilir.'
       ),
       actions: [
         TextButton(
           onPressed: () => Navigator.pop(context),
           child: const Text('İptal'),
         ),
         ElevatedButton(
           onPressed: () async {
             Navigator.pop(context);
             
             // Loading dialog göster
             showDialog(
               context: context,
               barrierDismissible: false,
               builder: (_) => const AlertDialog(
                 content: Row(
                   children: [
                     CircularProgressIndicator(),
                     SizedBox(width: 16),
                     Text('Test verileri oluşturuluyor...'),
                   ],
                 ),
               ),
             );
             
             try {
               await DatabaseService().populateMockData();
               Navigator.pop(context); // Loading dialog'unu kapat
               await _loadData(); // Verileri yeniden yükle
               _showSuccessSnackBar('Test verileri başarıyla oluşturuldu');
             } catch (e) {
               Navigator.pop(context); // Loading dialog'unu kapat
               _showErrorSnackBar('Test verileri oluşturulurken hata: $e');
             }
           },
           style: ElevatedButton.styleFrom(
             backgroundColor: const Color(0xFF1565C0),
           ),
           child: const Text('Oluştur', style: TextStyle(color: Colors.white)),
         ),
       ],
     ),
   );
 }

 void _showAboutDialog() {
   Navigator.pop(context); // Ayarlar dialog'unu kapat
   
   showAboutDialog(
     context: context,
     applicationName: 'İzLab Sports',
     applicationVersion: '1.0.0',
     applicationIcon: Container(
       width: 48,
       height: 48,
       decoration: BoxDecoration(
         color: const Color(0xFF1565C0),
         borderRadius: BorderRadius.circular(12),
       ),
       child: const Icon(Icons.sports, color: Colors.white, size: 24),
     ),
     children: [
       const Text(
         'İzLab Sports - izSel Hibrit\n\n'
         'Sporcuların performans analizini yapmak için geliştirilmiş '
         'profesyonel bir uygulama.\n\n'
         'Özellikler:\n'
         '• Sprint ve sıçrama testleri\n'
         '• Detaylı performans analizi\n'
         '• İlerleme takibi\n'
         '• Test karşılaştırması\n'
         '• Kuvvet-hız profil analizi',
       ),
     ],
   );
 }
}