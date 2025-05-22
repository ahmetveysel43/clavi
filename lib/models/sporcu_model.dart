class Sporcu {
  int? id;
  String ad;
  String soyad;
  int yas;
  String cinsiyet;
  String? brans;
  String? kulup;
  String? takim;  // Yeni eklenen takım alanı
  String? sikletYas;
  String? sikletKilo;
  String? sporculukYili;
  String? boy;
  String? kilo;
  String? bacakBoyu;
  String? oturmaBoyu;
  String? ekBilgi1;
  String? ekBilgi2;

  Sporcu({
    this.id,
    required this.ad,
    required this.soyad,
    required this.yas,
    required this.cinsiyet,
    this.brans,
    this.kulup,
    this.takim,  // Yapıcı metodda takım alanı
    this.sikletYas,
    this.sikletKilo,
    this.sporculukYili,
    this.boy,
    this.kilo,
    this.bacakBoyu,
    this.oturmaBoyu,
    this.ekBilgi1,
    this.ekBilgi2,
  });

  Map<String, dynamic> toMap() {
    return {
      'Id': id,
      'Ad': ad,
      'Soyad': soyad,
      'Yas': yas,
      'Cinsiyet': cinsiyet,
      'Brans': brans,
      'Kulup': kulup,
      'Takim': takim,  // Map'e takım alanı eklendi
      'SikletYas': sikletYas,
      'SikletKilo': sikletKilo,
      'SporculukYili': sporculukYili,
      'Boy': boy,
      'Kilo': kilo,
      'BacakBoyu': bacakBoyu,
      'OturmaBoyu': oturmaBoyu,
      'EkBilgi1': ekBilgi1,
      'EkBilgi2': ekBilgi2,
    };
  }

  factory Sporcu.fromMap(Map<String, dynamic> map) {
    return Sporcu(
      id: map['Id'] as int?,
      ad: map['Ad'] as String? ?? 'Bilinmeyen',
      soyad: map['Soyad'] as String? ?? 'Bilinmeyen',
      yas: map['Yas'] as int? ?? 0,
      cinsiyet: map['Cinsiyet'] as String? ?? 'Bilinmeyen',
      brans: map['Brans'] as String?,
      kulup: map['Kulup'] as String?,
      takim: map['Takim'] as String?,  // Map'ten takım alanı alındı
      sikletYas: map['SikletYas'] as String?,
      sikletKilo: map['SikletKilo'] as String?,
      sporculukYili: map['SporculukYili'] as String?,
      boy: map['Boy'] as String?,
      kilo: map['Kilo'] as String?,
      bacakBoyu: map['BacakBoyu'] as String?,
      oturmaBoyu: map['OturmaBoyu'] as String?,
      ekBilgi1: map['EkBilgi1'] as String?,
      ekBilgi2: map['EkBilgi2'] as String?,
    );
  }

  @override
  String toString() {
    return '$ad $soyad';
  }
}