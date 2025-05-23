import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/sporcu_model.dart';
import '../models/olcum_model.dart';
import '../services/database_service.dart';

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
  List<Olcum> _olcumler = [];
  List<Olcum> _tumOlcumler = []; // Tüm CMJ ve SJ ölçümlerini tutacak
  List<bool> _seciliOlcumler = []; // Hangi ölçümlerin seçildiğini tutacak
  List<Olcum> _hesaplamayaGirecekOlcumler = []; // Hesaplamaya girecek ölçümleri tutacak
  List<double> _jumpHeights = [];
  final List<double> _additionalMasses = [0, 20, 40, 60, 80];
  List<double> _forces = [];
  List<double> _velocities = [];

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
    // Sporcu bilgilerini al
    _secilenSporcu = await _databaseService.getSporcu(sporcuId);
    if (_secilenSporcu == null) {
      throw Exception('Sporcu bulunamadı');
    }

    // Vücut ağırlığı, bacak boyu ve oturma boyu bilgilerini al
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

    // İtme mesafesini hesapla (m)
    _pushOffDistance = (_legLength - _sittingHeight) / 100.0;
    if (_pushOffDistance <= 0) {
      throw Exception(
          'İtme mesafesi hesaplanamadı: $_pushOffDistance (Bacak boyu: $_legLength cm, Oturma boyu: $_sittingHeight cm)');
    }

    // Ölçümleri al
    _olcumler = await _databaseService.getOlcumlerBySporcuId(sporcuId);
    debugPrint('DikeyProfilScreen: Toplam ölçüm sayısı: ${_olcumler.length}');

    // Her ölçümün değerlerini kontrol et ve eksikse tekrar yükle
    for (int i = 0; i < _olcumler.length; i++) {
      var olcum = _olcumler[i];
      debugPrint('DikeyProfilScreen: Ölçüm ID: ${olcum.id}, Tür: ${olcum.olcumTuru}, Mevcut değer sayısı: ${olcum.degerler.length}');
      
      // Eğer değerler boşsa, manuel olarak yükle
      if (olcum.degerler.isEmpty && olcum.id != null) {
        debugPrint('DikeyProfilScreen: Ölçüm ID ${olcum.id} için değerler manuel olarak yükleniyor...');
        try {
          List<OlcumDeger> degerler = await _databaseService.getOlcumDegerlerByOlcumId(olcum.id!);
          olcum.degerler = degerler;
          debugPrint('DikeyProfilScreen: Ölçüm ID ${olcum.id} için ${degerler.length} değer yüklendi');
          
          // Değerleri listele
          for (var deger in degerler) {
            debugPrint('  DikeyProfilScreen: Değer türü: ${deger.degerTuru}, Değer: ${deger.deger}');
          }
        } catch (e) {
          debugPrint('DikeyProfilScreen: Ölçüm ID ${olcum.id} için değerler yüklenirken hata: $e');
        }
      }
    }

    // Sadece CMJ ve SJ ölçümlerini filtrele
    _tumOlcumler = _olcumler
        .where((olcum) => olcum.olcumTuru == 'CMJ' || olcum.olcumTuru == 'SJ')
        .toList();

    debugPrint('DikeyProfilScreen: CMJ/SJ ölçüm sayısı: ${_tumOlcumler.length}');
    
    // Filtrelenmiş ölçümlerin değerlerini tekrar kontrol et
    for (var olcum in _tumOlcumler) {
      debugPrint('DikeyProfilScreen: Filtrelenmiş ölçüm ID: ${olcum.id}, Tür: ${olcum.olcumTuru}, Değer sayısı: ${olcum.degerler.length}');
      for (var deger in olcum.degerler) {
        debugPrint('  DikeyProfilScreen: ${deger.degerTuru} = ${deger.deger}');
      }
    }

    if (_tumOlcumler.isEmpty) {
      throw Exception('Sıçrama (CMJ veya SJ) ölçümü bulunamadı.');
    }

    // İlk başta tüm ölçümler seçili olsun
    _seciliOlcumler = List.filled(_tumOlcumler.length, true);
    
    // Seçili ölçümleri güncelle
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
  debugPrint('DikeyProfilScreen: _updateSelectedOlcumler çağrıldı.');
  _hesaplamayaGirecekOlcumler = [];

  for (int i = 0; i < _tumOlcumler.length; i++) {
    if (i < _seciliOlcumler.length && _seciliOlcumler[i]) {
      _hesaplamayaGirecekOlcumler.add(_tumOlcumler[i]);
    }
  }
  debugPrint('DikeyProfilScreen: _hesaplamayaGirecekOlcumler Sayısı: ${_hesaplamayaGirecekOlcumler.length}');

  _jumpHeights = [];
  for (var olcum in _hesaplamayaGirecekOlcumler) {
    debugPrint('DikeyProfilScreen: Yükseklik aranıyor - Olcum ID: ${olcum.id}, Tür: ${olcum.olcumTuru}');
    debugPrint('DikeyProfilScreen: Ölçüm değerleri sayısı: ${olcum.degerler.length}');
    
    // Ölçüm değerlerini listele
    for (var deger in olcum.degerler) {
      debugPrint('  DikeyProfilScreen: Değer türü: ${deger.degerTuru}, Değer: ${deger.deger}');
    }
    
    // Yükseklik değerini bul
    OlcumDeger? yukseklikDegeri;
    try {
      yukseklikDegeri = olcum.degerler.firstWhere(
        (d) => d.degerTuru == 'yukseklik',
      );
      debugPrint('  DikeyProfilScreen: Bulunan "yukseklik" değeri: ${yukseklikDegeri.deger}');
      
      if (yukseklikDegeri.deger > 0) {
        _jumpHeights.add(yukseklikDegeri.deger);
        debugPrint('  DikeyProfilScreen: Yükseklik ${yukseklikDegeri.deger} cm _jumpHeights listesine eklendi.');
      } else {
        debugPrint('  DikeyProfilScreen: Yükseklik <= 0 olduğu için _jumpHeights listesine eklenmedi.');
      }
    } catch (e) {
      debugPrint('  DikeyProfilScreen: Olcum ID ${olcum.id} için "yukseklik" değeri bulunamadı. Hata: $e');
      
      // Alternatif değer türlerini dene
      for (String alternatif in ['Height', 'height', 'YUKSEKLIK', 'jump_height']) {
        try {
          yukseklikDegeri = olcum.degerler.firstWhere(
            (d) => d.degerTuru == alternatif,
          );
          debugPrint('  DikeyProfilScreen: Alternatif "$alternatif" değeri bulundu: ${yukseklikDegeri.deger}');
          
          if (yukseklikDegeri.deger > 0) {
            _jumpHeights.add(yukseklikDegeri.deger);
            debugPrint('  DikeyProfilScreen: Alternatif yükseklik ${yukseklikDegeri.deger} cm _jumpHeights listesine eklendi.');
          }
          break;
        } catch (e2) {
          debugPrint('  DikeyProfilScreen: Alternatif "$alternatif" değeri de bulunamadı.');
        }
      }
    }
  }
  
  debugPrint('DikeyProfilScreen: _jumpHeights: $_jumpHeights');
  debugPrint('DikeyProfilScreen: _jumpHeights toplam sayı: ${_jumpHeights.length}');
  
  setState(() {}); // UI'ı güncellemek için
}
  void _calculateForceVelocityProfile() {
    try {
      // Ölçüm sayısını kontrol et
      if (_jumpHeights.length < 3) {
        throw Exception('En az 3 sıçrama ölçümü gereklidir.');
      }

      const double g = 9.81; // Yerçekimi ivmesi (m/s²)

      // 1. Takeoff hızları ve ortalama itme hızları
      List<double> vTakeoff = [];
      List<double> vMean = [];
      for (int i = 0; i < _jumpHeights.length; i++) {
        double h = _jumpHeights[i] / 100.0; // cm'den m'ye çevir
        double v = math.sqrt(2 * g * h); // v_takeoff
        vTakeoff.add(v);
        vMean.add(v / 2); // v_mean
      }

      // 2. Ortalama kuvvetler (Samozino formülü) ve normalizasyon
      _forces = [];
      _velocities = [];
      for (int i = 0; i < _jumpHeights.length; i++) {
        // _jumpHeights ve _additionalMasses eşleşmesi için sınır kontrolü
        double additionalMass = i < _additionalMasses.length ? _additionalMasses[i] : 0;
        
        double totalMass = _bodyMass + additionalMass;
        double v = vTakeoff[i];
        double fMean = totalMass * ((v * v) / (2 * _pushOffDistance) + g);
        double fNorm = fMean / _bodyMass; // N/kg cinsinden
        _forces.add(fNorm);
        _velocities.add(vMean[i]);
      }

      // 3. Lineer regresyon
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
        a = (n * sumVF - sumV * sumF) / (n * sumV2 - sumV * sumV); // slope (Sfv)
        b = (sumF - a * sumV) / n; // intercept (F0)
      } else {
        a = 0;
        b = 0;
      }

      _f0PerKg = b;
      
      // v0 hesaplaması için payda kontrolü
      if (a != 0) {
        _v0PerKg = -b / a;
      } else {
        _v0PerKg = 0;
      }
      
      _sfvPerKg = a;
      _pmaxPerKg = (_f0PerKg * _v0PerKg) / 4;

      // 4. Optimal profil hesaplamaları (90° ve 30° için)
      double penteOpt90 = _calculatePenteOpt(g, _pmaxPerKg, _pushOffDistance, 90.0);
      _sfvOptPerKg = _calculateSfvOpt(_pmaxPerKg, _pushOffDistance, g, penteOpt90, 90.0);

      double penteOpt30 = _calculatePenteOpt(g, _pmaxPerKg, _pushOffDistance, 30.0);
      _sfvOpt30PerKg = _calculateSfvOpt(_pmaxPerKg, _pushOffDistance, g, penteOpt30, 30.0);

      // 5. FVimb hesaplama (Profil Dengesizliği)
      if (_sfvOptPerKg != 0) {
        _fvimb = 100 * (_sfvPerKg - _sfvOptPerKg) / _sfvOptPerKg.abs();
      } else {
        _fvimb = 0;
      }

      // 6. R² hesaplama
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
      // Açıya bağlı olarak g'yi güncelle (g * sin(alpha))
      double alphaRadians = alphaDegrees * math.pi / 180.0;
      double gAdjusted = g * math.sin(alphaRadians);

      // Eğer giriş değerleri uygun değilse, hesaplama yapmadan dön
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
      // Açıya bağlı olarak g'yi güncelle (g * sin(alpha))
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

      // Birinci terim: -(g^2 / (3 * Pmax))
      double term1 = -(g2 / (3 * pmaxPerKg));

      // İkinci terim
      double term2Numerator = -(g4 * hpo4) - (12 * gAdjusted * hpo3 * pmax2);
      double term2Denominator = 3 * hpo2 * pmaxPerKg * penteOpt;

      double term2Fraction;
      if (term2Denominator == 0) {
        term2Fraction = 0;
      } else {
        term2Fraction = term2Numerator / term2Denominator;
      }

      // Üçüncü terim
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
                    _buildOlcumSecimBolumu(), // Tüm ölçümleri seçme bölümü
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
                  ],
                ],
              ),
            ),
    );
  }

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
              
              // Ölçümün sıçrama yüksekliğini bul
              double yukseklik = 0;
              for (var deger in olcum.degerler) {
                if (deger.degerTuru == 'yukseklik') {
                  yukseklik = deger.deger;
                  break;
                }
              }
              
              // Tarih formatını düzenle
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
    // Hata koruması - geçersiz değerler için erken çıkış
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

    // Optimal F-V Profili hesaplaması (90° ve 30° için)
    double f0Opt90 = 0;
    double v0Opt90 = 0;
    double f0Opt30 = 0;
    double v0Opt30 = 0;
    double fvProfile90 = 0;
    double fvProfile30 = 0;

    // 90° için optimal profil
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

    // 30° için optimal profil
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

    // Grafik sınırlarını belirlerken tüm profilleri dikkate al
    // Geçersiz değerler için koruma ekle
    double maxF0 = 0;
    double maxV0 = 0;
    
    // _f0PerKg, f0Opt90, f0Opt30 değerlerini kontrol et
    List<double> validF0Values = [];
    if (_f0PerKg.isFinite && !_f0PerKg.isNaN && _f0PerKg > 0) validF0Values.add(_f0PerKg);
    if (f0Opt90.isFinite && !f0Opt90.isNaN && f0Opt90 > 0) validF0Values.add(f0Opt90);
    if (f0Opt30.isFinite && !f0Opt30.isNaN && f0Opt30 > 0) validF0Values.add(f0Opt30);
    
    if (validF0Values.isNotEmpty) {
      maxF0 = validF0Values.reduce(math.max);
    } else {
      maxF0 = 40.0; // Varsayılan değer
    }
    
    // _v0PerKg, v0Opt90, v0Opt30 değerlerini kontrol et
    List<double> validV0Values = [];
    if (_v0PerKg.isFinite && !_v0PerKg.isNaN && _v0PerKg > 0) validV0Values.add(_v0PerKg);
    if (v0Opt90.isFinite && !v0Opt90.isNaN && v0Opt90 > 0) validV0Values.add(v0Opt90);
    if (v0Opt30.isFinite && !v0Opt30.isNaN && v0Opt30 > 0) validV0Values.add(v0Opt30);
    
    if (validV0Values.isNotEmpty) {
      maxV0 = validV0Values.reduce(math.max);
    } else {
      maxV0 = 3.0; // Varsayılan değer
    }

    // X ekseni için dinamik etiket aralığı
    double xInterval;
    double maxSpeed = maxV0 * 1.2;
    
    // maxSpeed'in geçerli bir değer olduğundan emin ol
    if (!maxSpeed.isFinite || maxSpeed.isNaN || maxSpeed <= 0) {
      maxSpeed = 3.0; // Varsayılan değer
    }
    
    if (maxSpeed > 10) {
      xInterval = 2.0;
    } else if (maxSpeed > 5) {
      xInterval = 1.0;
    } else {
      xInterval = 0.5;
    }

    // Hata düzeltmesi - maxSpeed'i yuvarlama
    int ceiledValue = 6; // Varsayılan değer
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
          // Lejant (Legend) Ekle - Wrap ile taşmayı önle
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
                              // Sınırları aşmamak için değerleri kısıtla
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

  // Lejant için yardımcı widget
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