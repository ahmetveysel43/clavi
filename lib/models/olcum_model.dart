class Olcum {
  int? id;
  int sporcuId;
  int testId;
  String olcumTarihi;
  String olcumTuru;
  int olcumSirasi;
  List<OlcumDeger> degerler = [];

  Olcum({
    this.id,
    required this.sporcuId,
    required this.testId,
    required this.olcumTarihi,
    required this.olcumTuru,
    required this.olcumSirasi,
    this.degerler = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'Id': id, // "Id" olarak değiştirdik (büyük I)
      'SporcuId': sporcuId,
      'TestId': testId,
      'OlcumTarihi': olcumTarihi,
      'OlcumTuru': olcumTuru,
      'OlcumSirasi': olcumSirasi,
    };
  }

  factory Olcum.fromMap(Map<String, dynamic> map) {
    return Olcum(
      id: map['Id'] as int?, // "Id" olarak değiştirdik (büyük I)
      sporcuId: map['SporcuId'] as int? ?? 0,
      testId: map['TestId'] as int? ?? 0,
      olcumTarihi: map['OlcumTarihi'] as String? ?? '',
      olcumTuru: map['OlcumTuru'] as String? ?? '',
      olcumSirasi: map['OlcumSirasi'] as int? ?? 0,
      degerler: [],
    );
  }
  
  @override
  String toString() {
    return 'Olcum{id: $id, sporcuId: $sporcuId, olcumTuru: $olcumTuru, olcumSirasi: $olcumSirasi}';
  }
}

class OlcumDeger {
  int? id;
  int olcumId;
  String degerTuru;
  double deger;

  OlcumDeger({
    this.id,
    required this.olcumId,
    required this.degerTuru,
    required this.deger,
  });

  Map<String, dynamic> toMap() {
    return {
      'Id': id, // "Id" olarak değiştirdik (büyük I)
      'OlcumId': olcumId,
      'DegerTuru': degerTuru,
      'Deger': deger,
    };
  }

  factory OlcumDeger.fromMap(Map<String, dynamic> map) {
    return OlcumDeger(
      id: map['Id'] as int?, // "Id" olarak değiştirdik (büyük I)
      olcumId: map['OlcumId'] as int? ?? 0,
      degerTuru: map['DegerTuru'] as String? ?? '',
      deger: (map['Deger'] as num?)?.toDouble() ?? 0.0,
    );
  }
  
  @override
  String toString() {
    return 'OlcumDeger{id: $id, olcumId: $olcumId, degerTuru: $degerTuru, deger: $deger}';
  }
}

enum OlcumTuru {
  sprint,
  cmj,
  sj,
  dj,
  rj
}

extension OlcumTuruExtension on OlcumTuru {
  String get displayName {
    switch (this) {
      case OlcumTuru.sprint:
        return 'Sprint';
      case OlcumTuru.cmj:
        return 'Counter Movement Jump';
      case OlcumTuru.sj:
        return 'Squat Jump';
      case OlcumTuru.dj:
        return 'Drop Jump';
      case OlcumTuru.rj:
        return 'Repeated Jump';
    }
  }

  String get name {
    switch (this) {
      case OlcumTuru.sprint:
        return 'Sprint';
      case OlcumTuru.cmj:
        return 'CMJ';
      case OlcumTuru.sj:
        return 'SJ';
      case OlcumTuru.dj:
        return 'DJ';
      case OlcumTuru.rj:
        return 'RJ';
    }
  }
}