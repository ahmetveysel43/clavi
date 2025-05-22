// utils/olcum_paylasim_helper.dart dosyası

import 'package:flutter/material.dart';
import 'package:izLab/models/olcum_model.dart';
import '../models/sporcu_model.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class OlcumPaylasimHelper {
  /// Paylaşım Widget'ını oluşturur
  static Widget buildPaylasimWidget({
    required Sporcu sporcu,
    required Olcum olcum,
    required String appName,
  }) {
    final testColor = _getTestTypeColor(olcum.olcumTuru);
    final testIcon = _getTestTypeIcon(olcum.olcumTuru);
    
    // Ölçüm verilerini al
    final isSprintTest = olcum.olcumTuru.toUpperCase() == 'SPRINT';
    
    // Ölçüm türüne göre başlıca değeri al
    String anaMetrik = '';
    String anaMetrikDeger = '';
    String anaMetrikBirim = '';
    
    if (isSprintTest) {
      final kapi7 = olcum.degerler.firstWhere(
        (d) => d.degerTuru.toUpperCase() == 'KAPI7',
        orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
      );
      
      anaMetrik = 'Toplam Süre';
      anaMetrikDeger = kapi7.deger.toStringAsFixed(2);
      anaMetrikBirim = 's';
    } else {
      final yukseklik = olcum.degerler.firstWhere(
        (d) => d.degerTuru.toLowerCase() == 'yukseklik',
        orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
      );
      
      anaMetrik = 'Yükseklik';
      anaMetrikDeger = yukseklik.deger.toStringAsFixed(1);
      anaMetrikBirim = 'cm';
    }
    
    // Tarih formatı
    DateTime olcumTarihi;
    try {
      olcumTarihi = DateTime.parse(olcum.olcumTarihi);
    } catch (e) {
      olcumTarihi = DateTime.now();
    }
    final tarihStr = DateFormat('dd.MM.yyyy - HH:mm').format(olcumTarihi);
    
    return Container(
      width: 400,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25), // withOpacity(0.1) -> withAlpha(25)
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo ve Uygulama Adı
          Row(
            children: [
              Icon(Icons.fitness_center, color: testColor),
              const SizedBox(width: 8),
              Text(
                appName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // QR kod veya benzer bir şey eklenebilir
            ],
          ),
          const Divider(),
          
          // Sporcu Bilgileri
          Row(
            children: [
              CircleAvatar(
                backgroundColor: testColor.withAlpha(76), // withOpacity(0.3) -> withAlpha(76)
                radius: 24,
                child: Icon(Icons.person, color: testColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${sporcu.ad} ${sporcu.soyad}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${sporcu.yas} yaş, ${sporcu.boy} cm, ${sporcu.kilo} kg',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Test Başlığı
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: testColor.withAlpha(25), // withOpacity(0.1) -> withAlpha(25)
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(testIcon, color: testColor),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${olcum.olcumTuru} - ${olcum.olcumSirasi}. Ölçüm',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: testColor,
                      ),
                    ),
                    Text(
                      tarihStr,
                      style: TextStyle(
                        fontSize: 12,
                        color: testColor.withAlpha(204), // withOpacity(0.8) -> withAlpha(204)
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Ana Metrik (büyük gösterge)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  anaMetrik,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      anaMetrikDeger,
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: testColor,
                      ),
                    ),
                    Text(
                      ' $anaMetrikBirim',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: testColor.withAlpha(204), // withOpacity(0.8) -> withAlpha(204)
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Diğer Metrikler
          if (isSprintTest)
            _buildSprintMetrikler(olcum)
          else
            _buildSicramaMetrikler(olcum),
            
          const SizedBox(height: 24),
          
          // Footer
          Text(
            'Bu sonuç $appName uygulaması ile ölçülmüştür',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  static Widget _buildSprintMetrikler(Olcum olcum) {
    // Son 30m hızı hesapla
    final kapi6 = olcum.degerler.firstWhere(
      (d) => d.degerTuru.toUpperCase() == 'KAPI6',
      orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
    );
    
    final kapi7 = olcum.degerler.firstWhere(
      (d) => d.degerTuru.toUpperCase() == 'KAPI7',
      orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
    );
    
    double hiz = 0;
    if (kapi6.deger != 0 && kapi7.deger != 0) {
      final sureFark = kapi7.deger - kapi6.deger;
      if (sureFark > 0) {
        // Varsayılan kapı mesafeleri (6. ve 7. kapı arası 10m)
        hiz = 10 / sureFark;
      }
    }
    
    return Row(
      children: [
        Expanded(
          child: _buildMetrikCard(
            label: '30-40m Hız',
            value: hiz != 0 ? '${hiz.toStringAsFixed(2)} m/s' : '-',
            icon: Icons.speed,
            color: const Color(0xFF64B5F6),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetrikCard(
            label: '30-40m Süre',
            value: kapi6.deger != 0 && kapi7.deger != 0 
              ? '${(kapi7.deger - kapi6.deger).toStringAsFixed(3)} s' 
              : '-',
            icon: Icons.timer,
            color: const Color(0xFFE57373),
          ),
        ),
      ],
    );
  }
  
  static Widget _buildSicramaMetrikler(Olcum olcum) {
    final ucusSuresi = olcum.degerler.firstWhere(
      (d) => d.degerTuru.toLowerCase() == 'ucussuresi',
      orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
    );
    
    final guc = olcum.degerler.firstWhere(
      (d) => d.degerTuru.toLowerCase() == 'guc',
      orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
    );
    
    return Row(
      children: [
        Expanded(
          child: _buildMetrikCard(
            label: 'Uçuş Süresi',
            value: ucusSuresi.deger != 0 ? '${ucusSuresi.deger.toStringAsFixed(3)} s' : '-',
            icon: Icons.timer,
            color: const Color(0xFF64B5F6),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetrikCard(
            label: 'Güç',
            value: guc.deger != 0 ? '${guc.deger.toStringAsFixed(0)} W' : '-',
            icon: Icons.bolt,
            color: const Color(0xFFFFB74D),
          ),
        ),
      ],
    );
  }
  
  static Widget _buildMetrikCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(25), // withOpacity(0.1) -> withAlpha(25)
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color.withAlpha(204), // withOpacity(0.8) -> withAlpha(204)
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Basitleştirilmiş paylaşım işlevi - sadece metni panoya kopyalar
  static Future<void> shareOlcum({
    required BuildContext context, 
    required GlobalKey repaintKey,
    required Sporcu sporcu,
    required Olcum olcum,
  }) async {
    try {
      // Detaylı bilgileri içeren metin oluştur
      String shareText = """
${sporcu.ad} ${sporcu.soyad}'nin ${olcum.olcumTuru} Testi Sonuçları:
Tarih: ${olcum.olcumTarihi}
Test ID: ${olcum.id}
Test Sırası: ${olcum.olcumSirasi}
""";
      
      // Ölçüm türüne göre detay ekle
      if (olcum.olcumTuru.toUpperCase() == 'SPRINT') {
        final kapi7 = olcum.degerler.firstWhere(
          (d) => d.degerTuru.toUpperCase() == 'KAPI7',
          orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
        );
        
        if (kapi7.deger != 0) {
          shareText += "Toplam Süre: ${kapi7.deger.toStringAsFixed(2)} s\n";
        }
      } else {
        final yukseklik = olcum.degerler.firstWhere(
          (d) => d.degerTuru.toLowerCase() == 'yukseklik',
          orElse: () => OlcumDeger(olcumId: 0, degerTuru: '', deger: 0),
        );
        
        if (yukseklik.deger != 0) {
          shareText += "Yükseklik: ${yukseklik.deger.toStringAsFixed(1)} cm\n";
        }
      }
      
      // Bilgileri panoya kopyala
      await Clipboard.setData(ClipboardData(text: shareText));
      
      // Başarı mesajı göster
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test sonuçları panoya kopyalandı. İstediğiniz uygulamada yapıştırabilirsiniz.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      
      // Görsel olarak paylaşım diyaloğu göster
      _showShareOptionsDialog(context);

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paylaşım sırasında hata: $e')),
        );
      }
    }
  }

  /// Paylaşım seçenekleri gösteren dialog
  static void _showShareOptionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Paylaşım'),
          content: const Text(
            'Test sonuçları panoya kopyalandı. Şimdi istediğiniz uygulamada paylaşabilirsiniz.\n\n'
            'Örneğin: WhatsApp, Email, Mesajlar, vb.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Tamam'),
            ),
          ],
        );
      },
    );
  }
  
  // Test türüne göre renk ve ikon belirleme fonksiyonları
  static Color _getTestTypeColor(String testType) {
    switch (testType.toUpperCase()) {
      case 'SPRINT': return const Color(0xFFE57373);
      case 'CMJ': return const Color(0xFF64B5F6);
      case 'SJ': return const Color(0xFF81C784);
      case 'DJ': return const Color(0xFFFFB74D);
      case 'RJ': return const Color(0xFFA1887F);
      default: return Colors.grey;
    }
  }

  static IconData _getTestTypeIcon(String testType) {
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