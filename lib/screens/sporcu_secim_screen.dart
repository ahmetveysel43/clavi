import 'package:flutter/material.dart';
import 'jump_screen.dart';
import 'sprint_screen.dart';
import 'sporcu_kayit_screen.dart';
import '../models/sporcu_model.dart';
import '../services/database_service.dart';

class SporcuSecimScreen extends StatefulWidget {
  const SporcuSecimScreen({super.key});

  @override
  _SporcuSecimScreenState createState() => _SporcuSecimScreenState();
}

class _SporcuSecimScreenState extends State<SporcuSecimScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<Sporcu> _sporcular = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSporcular();
  }

  Future<void> _loadSporcular() async {
    try {
      setState(() => _isLoading = true);
      _sporcular = await _databaseService.getAllSporcular();
    } catch (e) {
      debugPrint('Sporcular yüklenirken hata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sporcular yüklenirken hata: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Sporcu> get _filteredSporcular {
    if (_searchQuery.isEmpty) return _sporcular;
    
    return _sporcular.where((sporcu) {
      final searchLower = _searchQuery.toLowerCase();
      return '${sporcu.ad} ${sporcu.soyad}'.toLowerCase().contains(searchLower) ||
          (sporcu.brans != null && sporcu.brans!.toLowerCase().contains(searchLower)) ||
          (sporcu.kulup != null && sporcu.kulup!.toLowerCase().contains(searchLower));
    }).toList();
  }

  void _editSporcu(Sporcu sporcu) {
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => SporcuKayitScreen(sporcu: sporcu),
      ),
    ).then((_) => _loadSporcular());
  }

  Future<void> _deleteSporcu(Sporcu sporcu) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Sporcu Sil'),
          content: Text('${sporcu.ad} ${sporcu.soyad} sporcusunu silmek istediğinize emin misiniz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await _databaseService.deleteSporcu(sporcu.id!);
                  _loadSporcular();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sporcu başarıyla silindi'),
                        backgroundColor: Color(0xFF4CAF50),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Sporcu silinirken hata: $e'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sporcu Seçimi'),
        backgroundColor: const Color(0xFF0288D1),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSporcular,
            tooltip: 'Yenile',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SporcuKayitScreen()),
          ).then((_) => _loadSporcular());
        },
        backgroundColor: const Color(0xFF0288D1),
        child: const Icon(Icons.add),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE3F2FD), Colors.white],
          ),
        ),
        child: Column(
          children: [
            // Arama kutusu
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: "Sporcu Ara...",
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF0288D1)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF0288D1), width: 2),
                  ),
                ),
              ),
            ),
            
            // Sporcu listesi
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _filteredSporcular.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_alt_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty 
                              ? 'Kayıtlı sporcu bulunamadı.'
                              : 'Arama kriterlerine uygun sporcu bulunamadı.',
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const SporcuKayitScreen()),
                              ).then((_) => _loadSporcular());
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Yeni Sporcu Ekle'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0288D1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredSporcular.length,
                      itemBuilder: (context, index) {
                        final sporcu = _filteredSporcular[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              // Önce sporcuyu geri döndürün veya seçin
                              Navigator.pop(context, sporcu.id);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // Avatar
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundColor: const Color(0xFF0288D1),
                                    child: Text(
                                      '${sporcu.ad[0]}${sporcu.soyad[0]}'.toUpperCase(),
                                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Sporcu bilgileri
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${sporcu.ad} ${sporcu.soyad}',
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0288D1)),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Yaş: ${sporcu.yas} • ${sporcu.cinsiyet}',
                                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                        ),
                                        if (sporcu.brans != null && sporcu.brans!.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'Branş: ${sporcu.brans}',
                                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  // Butonlar
                                  Column(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Color(0xFF0288D1)),
                                        onPressed: () => _editSporcu(sporcu),
                                        tooltip: 'Düzenle',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                                        onPressed: () => _deleteSporcu(sporcu),
                                        tooltip: 'Sil',
                                      ),
                                    ],
                                  ),
                                  // Test butonları
                                  Column(
                                    children: [
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => SprintScreen(sporcuId: sporcu.id),
                                            ),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFE57373),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          minimumSize: const Size(80, 30),
                                        ),
                                        child: const Text('Sprint'),
                                      ),
                                      const SizedBox(height: 8),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => JumpScreen(sporcuId: sporcu.id),
                                            ),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF64B5F6),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          minimumSize: const Size(80, 30),
                                        ),
                                        child: const Text('Sıçrama'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
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
}