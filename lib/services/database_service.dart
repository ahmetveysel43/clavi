import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../models/sporcu_model.dart';
import '../models/olcum_model.dart';
import 'dart:math' as math;

class DatabaseService {
  static Database? _database;
  List<Sporcu>? _sporcularCache;

  Future<Database> get database async {
    if (_database != null) return _database!;
    
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'izlab_sports.db');
    
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Sporcular tablosu
    await db.execute('''
      CREATE TABLE Sporcular(
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Ad TEXT NOT NULL,
        Soyad TEXT NOT NULL,
        Yas INTEGER NOT NULL,
        Cinsiyet TEXT NOT NULL,
        Brans TEXT,
        Kulup TEXT,
        Takim TEXT,
        SikletYas TEXT,
        SikletKilo TEXT,
        SporculukYili TEXT,
        Boy TEXT,
        Kilo TEXT,
        BacakBoyu TEXT,
        OturmaBoyu TEXT,
        EkBilgi1 TEXT,
        EkBilgi2 TEXT
      )
    ''');

    // Ölçümler tablosu
    await db.execute('''
      CREATE TABLE Olcumler(
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        SporcuId INTEGER NOT NULL,
        TestId INTEGER NOT NULL,
        OlcumTuru TEXT NOT NULL,
        OlcumSirasi INTEGER NOT NULL,
        OlcumTarihi TEXT NOT NULL,
        FOREIGN KEY (SporcuId) REFERENCES Sporcular (Id)
      )
    ''');

    // Ölçüm değerleri tablosu
    await db.execute('''
      CREATE TABLE OlcumDegerler(
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        OlcumId INTEGER NOT NULL,
        DegerTuru TEXT NOT NULL,
        Deger REAL NOT NULL,
        FOREIGN KEY (OlcumId) REFERENCES Olcumler (Id)
      )
    ''');

    // Performans analizi tablosu
    await db.execute('''
      CREATE TABLE performans_analiz(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        SporcuId INTEGER NOT NULL,
        OlcumTuru TEXT NOT NULL,
        DegerTuru TEXT NOT NULL,
        BaslangicTarihi TEXT NOT NULL,
        BitisTarihi TEXT NOT NULL,
        Ortalama REAL NOT NULL,
        StdDev REAL NOT NULL,
        CVYuzde REAL NOT NULL,
        TrendSlope REAL NOT NULL,
        Momentum REAL NOT NULL,
        TypicalityIndex REAL NOT NULL,
        SonAnalizTarihi TEXT NOT NULL,
        FOREIGN KEY (SporcuId) REFERENCES Sporcular (Id)
      )
    ''');

    // Test güvenilirlik tablosu
    await db.execute('''
      CREATE TABLE test_guvenilirlik(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        OlcumTuru TEXT NOT NULL,
        DegerTuru TEXT NOT NULL,
        TestRetestSEM REAL NOT NULL,
        MDC95 REAL NOT NULL,
        SWC REAL NOT NULL,
        GuncellemeTarihi TEXT NOT NULL,
        UNIQUE(OlcumTuru, DegerTuru)
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Performans analizi tabloları ekle
      await db.execute('''
        CREATE TABLE IF NOT EXISTS performans_analiz(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          SporcuId INTEGER NOT NULL,
          OlcumTuru TEXT NOT NULL,
          DegerTuru TEXT NOT NULL,
          BaslangicTarihi TEXT NOT NULL,
          BitisTarihi TEXT NOT NULL,
          Ortalama REAL NOT NULL,
          StdDev REAL NOT NULL,
          CVYuzde REAL NOT NULL,
          TrendSlope REAL NOT NULL,
          Momentum REAL NOT NULL,
          TypicalityIndex REAL NOT NULL,
          SonAnalizTarihi TEXT NOT NULL,
          FOREIGN KEY (SporcuId) REFERENCES Sporcular (Id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS test_guvenilirlik(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          OlcumTuru TEXT NOT NULL,
          DegerTuru TEXT NOT NULL,
          TestRetestSEM REAL NOT NULL,
          MDC95 REAL NOT NULL,
          SWC REAL NOT NULL,
          GuncellemeTarihi TEXT NOT NULL,
          UNIQUE(OlcumTuru, DegerTuru)
        )
      ''');
    }
  }

  // Sporcu işlemleri
  Future<int> insertSporcu(Sporcu sporcu) async {
    final db = await database;
    try {
      int id = await db.insert('Sporcular', sporcu.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      debugPrint('Sporcu eklendi: ID: $id, Ad: ${sporcu.ad} ${sporcu.soyad}');
      clearCache();
      return id;
    } catch (e) {
      debugPrint('Sporcu eklenirken hata: $e');
      throw Exception('Sporcu kaydedilemedi: $e');
    }
  }

  Future<Sporcu> getSporcu(int id) async {
    final Database db = await database;
    try {
      List<Map<String, dynamic>> maps = await db.query(
        'Sporcular',
        where: 'Id = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        debugPrint('Sporcu alındı: ${maps.first}');
        return Sporcu.fromMap(maps.first);
      }
      debugPrint('Sporcu bulunamadı: ID: $id');
      throw Exception('Sporcu bulunamadı');
    } catch (e) {
      debugPrint('Sporcu alınırken hata: $e');
      throw Exception('Sporcu yüklenemedi: $e');
    }
  }

  Future<List<Sporcu>> getAllSporcular() async {
    if (_sporcularCache != null) return _sporcularCache!;
    final Database db = await database;
    try {
      List<Map<String, dynamic>> maps = await db.query('Sporcular');
      debugPrint('Veritabanından alınan sporcular: ${maps.length} adet');
      _sporcularCache = List.generate(maps.length, (i) => Sporcu.fromMap(maps[i]));
      return _sporcularCache!;
    } catch (e) {
      debugPrint('Sporcular alınırken hata: $e');
      throw Exception('Sporcular yüklenemedi: $e');
    }
  }

  Future<int> updateSporcu(Sporcu sporcu) async {
    final db = await database;
    try {
      int count = await db.update(
        'Sporcular',
        sporcu.toMap(),
        where: 'Id = ?',
        whereArgs: [sporcu.id],
      );
      debugPrint('Sporcu güncellendi: ID: ${sporcu.id}');
      clearCache();
      return count;
    } catch (e) {
      debugPrint('Sporcu güncellenirken hata: $e');
      throw Exception('Sporcu güncellenemedi: $e');
    }
  }

  Future<int> deleteSporcu(int id) async {
    final db = await database;
    try {
      int count = await db.delete(
        'Sporcular',
        where: 'Id = ?',
        whereArgs: [id],
      );
      debugPrint('Sporcu silindi: ID: $id');
      clearCache();
      return count;
    } catch (e) {
      debugPrint('Sporcu silinirken hata: $e');
      throw Exception('Sporcu silinemedi: $e');
    }
  }

  void clearCache() {
    _sporcularCache = null;
    debugPrint('Sporcular cache temizlendi');
  }

  // Ölçüm işlemleri
  Future<int> insertOlcum(Olcum olcum) async {
    final Database db = await database;
    try {
      int id = await db.insert('Olcumler', olcum.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      debugPrint('Ölçüm eklendi: ID: $id, SporcuID: ${olcum.sporcuId}, Tür: ${olcum.olcumTuru}, Sıra: ${olcum.olcumSirasi}');
      olcum.id = id;
      return id;
    } catch (e) {
      debugPrint('Ölçüm eklenirken hata: $e');
      throw Exception('Ölçüm kaydedilemedi: $e');
    }
  }

  Future<int> updateOlcum(Olcum olcum) async {
    final Database db = await database;
    try {
      int count = await db.update(
        'Olcumler',
        olcum.toMap(),
        where: 'Id = ?',
        whereArgs: [olcum.id],
      );
      debugPrint('Ölçüm güncellendi: ID: ${olcum.id}');
      return count;
    } catch (e) {
      debugPrint('Ölçüm güncellenirken hata: $e');
      throw Exception('Ölçüm güncellenemedi: $e');
    }
  }

  Future<int> deleteOlcum(int id) async {
    final Database db = await database;
    try {
      // Önce ölçüm değerlerini sil
      await db.delete(
        'OlcumDegerler',
        where: 'OlcumId = ?',
        whereArgs: [id],
      );
      
      // Sonra ölçümü sil
      int count = await db.delete(
        'Olcumler',
        where: 'Id = ?',
        whereArgs: [id],
      );
      debugPrint('Ölçüm silindi: ID: $id');
      return count;
    } catch (e) {
      debugPrint('Ölçüm silinirken hata: $e');
      throw Exception('Ölçüm silinemedi: $e');
    }
  }

  Future<Olcum?> getOlcum(int id) async {
    final Database db = await database;
    try {
      List<Map<String, dynamic>> maps = await db.query(
        'Olcumler',
        where: 'Id = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        Olcum olcum = Olcum.fromMap(maps.first);
        olcum.degerler = await getOlcumDegerlerByOlcumId(olcum.id ?? 0);
        debugPrint('Ölçüm alındı: ${maps.first}, Değerler: ${olcum.degerler.length} adet');
        return olcum;
      }
      debugPrint('Ölçüm bulunamadı: ID: $id');
      return null;
    } catch (e) {
      debugPrint('Ölçüm alınırken hata: $e');
      throw Exception('Ölçüm yüklenemedi: $e');
    }
  }

  Future<List<Olcum>> getOlcumlerBySporcuId(int sporcuId) async {
    final Database db = await database;
    try {
      List<Map<String, dynamic>> maps = await db.query(
        'Olcumler',
        where: 'SporcuId = ?',
        whereArgs: [sporcuId],
        orderBy: 'OlcumTarihi DESC',
      );
      debugPrint('SporcuId ile ölçümler alındı: ${maps.length} adet');
      
      List<Olcum> olcumler = [];
      for (var map in maps) {
        Olcum olcum = Olcum.fromMap(map);
        if (olcum.id != null) {
          olcum.degerler = await getOlcumDegerlerByOlcumId(olcum.id!);
          debugPrint('Ölçüm ${olcum.id} için ${olcum.degerler.length} değer yüklendi');
        } else {
          debugPrint('UYARI: Ölçüm ID null, değerler yüklenemedi');
        }
        olcumler.add(olcum);
      }
      debugPrint('Sporcunun ölçümleri yüklendi: ${olcumler.length} adet');
      return olcumler;
    } catch (e) {
      debugPrint('Ölçümler alınırken hata: $e');
      return [];
    }
  }

  Future<List<Olcum>> getOlcumlerByTestId(int testId) async {
    final Database db = await database;
    try {
      List<Map<String, dynamic>> maps = await db.query(
        'Olcumler',
        where: 'TestId = ?',
        whereArgs: [testId],
      );
      debugPrint('TestId ile ölçümler sorgusu: $testId, Sonuç: ${maps.length} adet');
      List<Olcum> olcumler = [];
      for (var map in maps) {
        Olcum olcum = Olcum.fromMap(map);
        olcum.degerler = await getOlcumDegerlerByOlcumId(olcum.id ?? 0);
        olcumler.add(olcum);
        debugPrint('Ölçüm: ${olcum.id}, Tür: ${olcum.olcumTuru}, Değerler: ${olcum.degerler.length} adet');
      }
      return olcumler;
    } catch (e) {
      debugPrint('Ölçümler alınırken hata: $e');
      throw Exception('Ölçümler yüklenemedi: $e');
    }
  }

  // Ölçüm değerleri işlemleri
  Future<int> insertOlcumDeger(OlcumDeger olcumDeger) async {
    final Database db = await database;
    try {
      if (olcumDeger.olcumId <= 0) {
        throw Exception('Geçersiz OlcumId: ${olcumDeger.olcumId}');
      }
      int id = await db.insert('OlcumDegerler', olcumDeger.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      debugPrint('Ölçüm değeri eklendi: ID: $id, ÖlçümID: ${olcumDeger.olcumId}, Tür: ${olcumDeger.degerTuru}, Değer: ${olcumDeger.deger}');
      olcumDeger.id = id;
      return id;
    } catch (e) {
      debugPrint('Ölçüm değeri eklenirken hata: $e');
      throw Exception('Ölçüm değeri kaydedilemedi: $e');
    }
  }

  Future<int> updateOlcumDeger(OlcumDeger olcumDeger) async {
    final Database db = await database;
    try {
      int count = await db.update(
        'OlcumDegerler',
        olcumDeger.toMap(),
        where: 'Id = ?',
        whereArgs: [olcumDeger.id],
      );
      debugPrint('Ölçüm değeri güncellendi: ID: ${olcumDeger.id}');
      return count;
    } catch (e) {
      debugPrint('Ölçüm değeri güncellenirken hata: $e');
      throw Exception('Ölçüm değeri güncellenemedi: $e');
    }
  }

  Future<int> deleteOlcumDeger(int id) async {
    final Database db = await database;
    try {
      int count = await db.delete(
        'OlcumDegerler',
        where: 'Id = ?',
        whereArgs: [id],
      );
      debugPrint('Ölçüm değeri silindi: ID: $id');
      return count;
    } catch (e) {
      debugPrint('Ölçüm değeri silinirken hata: $e');
      throw Exception('Ölçüm değeri silinemedi: $e');
    }
  }

  Future<List<OlcumDeger>> getOlcumDegerlerByOlcumId(int olcumId) async {
    final Database db = await database;
    try {
      if (olcumId <= 0) {
        debugPrint('Geçersiz ölçüm ID: $olcumId');
        return [];
      }
      List<Map<String, dynamic>> maps = await db.query(
        'OlcumDegerler',
        where: 'OlcumId = ?',
        whereArgs: [olcumId],
      );
      debugPrint('Ölçüm değerleri alındı için ÖlçümID: $olcumId, Sonuç: ${maps.length} adet');
      return List.generate(maps.length, (i) => OlcumDeger.fromMap(maps[i]));
    } catch (e) {
      debugPrint('Ölçüm değerleri alınırken hata: $e');
      return [];
    }
  }

  Future<int> getNewTestId() async {
    final Database db = await database;
    try {
      List<Map<String, dynamic>> result = await db.rawQuery('SELECT COALESCE(MAX(TestId), 0) as maxId FROM Olcumler');
      int newTestId = (result.first['maxId'] as int) + 1;
      debugPrint('Yeni TestId: $newTestId');
      return newTestId;
    } catch (e) {
      debugPrint('TestId alınırken hata: $e');
      return 1;
    }
  }

  // Performans analizi metodları
  Future<void> savePerformansAnaliz({
    required int sporcuId,
    required String olcumTuru,
    required String degerTuru,
    required String baslangicTarihi,
    required String bitisTarihi,
    required double ortalama,
    required double stdDev,
    required double cvYuzde,
    required double trendSlope,
    required double momentum,
    required double typicalityIndex,
  }) async {
    final db = await database;
    
    await db.insert(
      'performans_analiz',
      {
        'SporcuId': sporcuId,
        'OlcumTuru': olcumTuru,
        'DegerTuru': degerTuru,
        'BaslangicTarihi': baslangicTarihi,
        'BitisTarihi': bitisTarihi,
        'Ortalama': ortalama,
        'StdDev': stdDev,
        'CVYuzde': cvYuzde,
        'TrendSlope': trendSlope,
        'Momentum': momentum,
        'TypicalityIndex': typicalityIndex,
        'SonAnalizTarihi': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getPerformansAnaliz({
    required int sporcuId,
    required String olcumTuru,
    required String degerTuru,
  }) async {
    final db = await database;
    
    final results = await db.query(
      'performans_analiz',
      where: 'SporcuId = ? AND OlcumTuru = ? AND DegerTuru = ?',
      whereArgs: [sporcuId, olcumTuru, degerTuru],
      orderBy: 'SonAnalizTarihi DESC',
      limit: 1,
    );
    
    if (results.isNotEmpty) {
      return results.first;
    }
    
    return null;
  }

  // Test güvenilirlik metodları
  Future<void> saveTestGuvenilirlik({
    required String olcumTuru,
    required String degerTuru,
    required double testRetestSEM,
    required double mdc95,
    required double swc,
  }) async {
    final db = await database;
    
    await db.insert(
      'test_guvenilirlik',
      {
        'OlcumTuru': olcumTuru,
        'DegerTuru': degerTuru,
        'TestRetestSEM': testRetestSEM,
        'MDC95': mdc95,
        'SWC': swc,
        'GuncellemeTarihi': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getTestGuvenilirlik({
    required String olcumTuru,
    required String degerTuru,
  }) async {
    final db = await database;
    
    final results = await db.query(
      'test_guvenilirlik',
      where: 'OlcumTuru = ? AND DegerTuru = ?',
      whereArgs: [olcumTuru, degerTuru],
      limit: 1,
    );
    
    if (results.isNotEmpty) {
      return results.first;
    }
    
    return null;
  }

  // Veritabanı yönetimi
  Future<void> deleteDatabaseFile() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'izlab_sports.db');
    
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    
    await deleteDatabase(path);
    clearCache();
  }

  // Demo veri oluşturma
  Future<void> populateMockData() async {
    debugPrint("===== KAPSAMLI DEMO VERİSİ EKLEME BAŞLADI =====");
    final db = await database;
    math.Random random = math.Random();

    // Demo sporcuları tanımla
    List<Sporcu> sporcular = [
      Sporcu(
        ad: "İzzet",
        soyad: "İnce",
        yas: 45,
        cinsiyet: "Erkek",
        brans: "Koşu",
        kulup: "Ferdi",
        takim: "Masterlar",
        boy: "175",
        kilo: "70",
        bacakBoyu: "80",
        oturmaBoyu: "90",
        sporculukYili: "20",
        sikletYas: "Master",
        sikletKilo: "70kg",
      ),
      Sporcu(
        ad: "Süleyman",
        soyad: "Ulupınar",
        yas: 35,
        cinsiyet: "Erkek",
        brans: "Basketbol",
        kulup: "Anadolu Efes",
        takim: "A Takımı",
        boy: "190",
        kilo: "85",
        bacakBoyu: "95",
        oturmaBoyu: "98",
        sporculukYili: "15",
        sikletYas: "Elit",
        sikletKilo: "85kg",
      ),
      Sporcu(
        ad: "Ayşe",
        soyad: "Kaya",
        yas: 22,
        cinsiyet: "Kadın",
        brans: "Atletizm",
        kulup: "Galatasaray",
        takim: "Kadın Takımı",
        boy: "165",
        kilo: "55",
        bacakBoyu: "75",
        oturmaBoyu: "85",
        sporculukYili: "8",
        sikletYas: "Genç",
        sikletKilo: "55kg",
      ),
    ];

    // Sporcuları ekle ve ID'lerini al
    for (var sporcuModel in sporcular) {
      int sporcuId = await insertSporcu(sporcuModel);
      sporcuModel.id = sporcuId;
      debugPrint("Demo sporcu eklendi: ${sporcuModel.ad} ${sporcuModel.soyad} (ID: $sporcuId)");

      if (sporcuModel.id == null) {
        debugPrint("HATA: Sporcu ID alınamadı - ${sporcuModel.ad}");
        continue;
      }

      // Her sporcu için 6 farklı tarihte kapsamlı ölçümler oluştur
      List<DateTime> measurementDates = [
        DateTime.now().subtract(Duration(days: 150)), // 5 ay önce
        DateTime.now().subtract(Duration(days: 120)), // 4 ay önce  
        DateTime.now().subtract(Duration(days: 90)),  // 3 ay önce
        DateTime.now().subtract(Duration(days: 60)),  // 2 ay önce
        DateTime.now().subtract(Duration(days: 30)),  // 1 ay önce
        DateTime.now().subtract(Duration(days: 7)),   // 1 hafta önce
      ];

      List<String> testTypes = ["SPRINT", "CMJ", "SJ", "DJ", "RJ"];

      for (int sessionIndex = 0; sessionIndex < measurementDates.length; sessionIndex++) {
        DateTime sessionDate = measurementDates[sessionIndex];
        int baseTestId = await getNewTestId();
        
        debugPrint("${sporcuModel.ad} için ${sessionIndex + 1}. test seansı - Tarih: ${sessionDate.toIso8601String()}");

        // Her test seansında tüm test türlerini yap
        for (int testTypeIndex = 0; testTypeIndex < testTypes.length; testTypeIndex++) {
          String testType = testTypes[testTypeIndex];
          int testId = baseTestId + testTypeIndex;
          
          DateTime testTime = sessionDate.add(Duration(
            hours: 9 + testTypeIndex,
            minutes: random.nextInt(60),
          ));

          if (testType == "SPRINT") {
            await _createSprintTest(
              sporcuModel, 
              testId, 
              testTime, 
              sessionIndex + 1,
              random,
            );
          } else {
            await _createJumpTest(
              sporcuModel, 
              testType,
              testId, 
              testTime, 
              sessionIndex + 1,
              random,
              db,
            );
          }
        }
        
        await Future.delayed(Duration(milliseconds: 10));
      }
    }
    
    clearCache();
    debugPrint("===== KAPSAMLI DEMO VERİSİ EKLEME TAMAMLANDI =====");
  }

  Future<void> _createSprintTest(
    Sporcu sporcu, 
    int testId, 
    DateTime testTime, 
    int sessionNumber,
    math.Random random,
  ) async {
    Olcum sprintOlcum = Olcum(
      sporcuId: sporcu.id!,
      testId: testId,
      olcumTarihi: testTime.toIso8601String(),
      olcumTuru: "SPRINT",
      olcumSirasi: sessionNumber,
    );
    
    int sprintOlcumId = await insertOlcum(sprintOlcum);
    
    // Sporcuya göre temel performans seviyesi belirle
    double performanceLevel = _getSprintPerformanceLevel(sporcu);
    
    // Seansa göre ilerleme faktörü (zaman içinde iyileşme)
    double progressFactor = 1.0 - (sessionNumber * 0.02); // Her seans %2 iyileşme
    
    // Kapı zamanlarını hesapla (realistik sprint profili)
    double kapi1Zaman = (0.3 + random.nextDouble() * 0.1) * performanceLevel * progressFactor;
    
    await insertOlcumDeger(OlcumDeger(
      olcumId: sprintOlcumId,
      degerTuru: "Kapi1",
      deger: double.parse(kapi1Zaman.toStringAsFixed(3)),
    ));
    
    // Sonraki kapılarda ivme azalması ile realistik zaman artışı
    double currentTime = kapi1Zaman;
    List<double> segmentTimes = [0.7, 0.9, 1.1, 1.4, 1.8, 2.2]; // Gerçekçi segment süreleri
    
    for (int kapino = 2; kapino <= 7; kapino++) {
      double segmentTime = segmentTimes[kapino - 2] * performanceLevel * progressFactor;
      segmentTime += (random.nextDouble() - 0.5) * 0.1; // ±0.05s varyasyon
      currentTime += segmentTime;
      
      await insertOlcumDeger(OlcumDeger(
        olcumId: sprintOlcumId,
        degerTuru: "Kapi$kapino",
        deger: double.parse(currentTime.toStringAsFixed(3)),
      ));
    }
    
    debugPrint("${sporcu.ad} için SPRINT (Seans $sessionNumber) Test ID $testId eklendi. Final: ${currentTime.toStringAsFixed(3)}s");
  }

Future<void> _createJumpTest(
   Sporcu sporcu, 
   String jumpType,
   int testId, 
   DateTime testTime, 
   int sessionNumber,
   math.Random random,
   Database db,
 ) async {
   Olcum jumpOlcum = Olcum(
     sporcuId: sporcu.id!,
     testId: testId,
     olcumTarihi: testTime.toIso8601String(),
     olcumTuru: jumpType,
     olcumSirasi: sessionNumber,
   );
   
   int jumpOlcumId = await insertOlcum(jumpOlcum);
   
   // Sporcuya göre temel performans seviyesi belirle
   Map<String, double> jumpPerformance = _getJumpPerformanceLevel(sporcu, jumpType);
   
   // Seansa göre ilerleme faktörü
   double progressFactor = 1.0 + (sessionNumber * 0.03); // Her seans %3 iyileşme
   
   // Temel metrikler
   double baseHeight = jumpPerformance['height']! * progressFactor;
   double baseFlightTime = jumpPerformance['flightTime']! * progressFactor;
   double basePower = jumpPerformance['power']! * progressFactor;
   
   // Varyasyon ekle (±5%)
   double heightVariation = (random.nextDouble() - 0.5) * 0.1;
   double flightVariation = (random.nextDouble() - 0.5) * 0.1;
   double powerVariation = (random.nextDouble() - 0.5) * 0.1;
   
   double finalHeight = baseHeight * (1 + heightVariation);
   double finalFlightTime = baseFlightTime * (1 + flightVariation);
   double finalPower = basePower * (1 + powerVariation);
   
   // Ana değerleri ekle
   await insertOlcumDeger(OlcumDeger(
     olcumId: jumpOlcumId,
     degerTuru: "yukseklik",
     deger: double.parse(finalHeight.toStringAsFixed(1)),
   ));
   
   await insertOlcumDeger(OlcumDeger(
     olcumId: jumpOlcumId,
     degerTuru: "ucusSuresi",
     deger: double.parse(finalFlightTime.toStringAsFixed(3)),
   ));
   
   await insertOlcumDeger(OlcumDeger(
     olcumId: jumpOlcumId,
     degerTuru: "guc",
     deger: double.parse(finalPower.toStringAsFixed(0)),
   ));
   
   // DJ ve RJ için ek metrikler
   if (jumpType == "DJ" || jumpType == "RJ") {
     double contactTime = jumpPerformance['contactTime']! * (1 + (random.nextDouble() - 0.5) * 0.2);
     double rsi = finalFlightTime / contactTime;
     
     await insertOlcumDeger(OlcumDeger(
       olcumId: jumpOlcumId,
       degerTuru: "temasSuresi",
       deger: double.parse(contactTime.toStringAsFixed(3)),
     ));
     
     await insertOlcumDeger(OlcumDeger(
       olcumId: jumpOlcumId,
       degerTuru: "rsi",
       deger: double.parse(rsi.toStringAsFixed(2)),
     ));
   }
   
   // RJ için seri sıçramalar
   if (jumpType == "RJ") {
     double rhythm = 2.2 + random.nextDouble() * 0.8; // 2.2-3.0 sıçrama/s
     await insertOlcumDeger(OlcumDeger(
       olcumId: jumpOlcumId,
       degerTuru: "ritim",
       deger: double.parse(rhythm.toStringAsFixed(2)),
     ));
     
     // 5-8 tekrarlı sıçrama serisi
     int jumpCount = 5 + random.nextInt(4);
     for (int r = 1; r <= jumpCount; r++) {
       double seriFlight = finalFlightTime * (0.85 + random.nextDouble() * 0.3);
       double seriContact = jumpPerformance['contactTime']! * (0.85 + random.nextDouble() * 0.3);
       double seriHeight = 0.122625 * math.pow(seriFlight * 1000, 2) / 1000;
       
       await insertOlcumDeger(OlcumDeger(
         olcumId: jumpOlcumId,
         degerTuru: 'Flight$r',
         deger: double.parse(seriFlight.toStringAsFixed(3)),
       ));
       
       await insertOlcumDeger(OlcumDeger(
         olcumId: jumpOlcumId,
         degerTuru: 'Contact$r',
         deger: double.parse(seriContact.toStringAsFixed(3)),
       ));
       
       await insertOlcumDeger(OlcumDeger(
         olcumId: jumpOlcumId,
         degerTuru: 'Height$r',
         deger: double.parse(seriHeight.toStringAsFixed(1)),
       ));
     }
     
     // Ortalama değerleri güncelle
     await _updateRJAverages(db, jumpOlcumId, jumpCount);
   }
   
   debugPrint("${sporcu.ad} için $jumpType (Seans $sessionNumber) Test ID $testId eklendi. Yükseklik: ${finalHeight.toStringAsFixed(1)}cm");
 }

 double _getSprintPerformanceLevel(Sporcu sporcu) {
   // Sporcuya göre performans seviyesi
   switch (sporcu.ad) {
     case "İzzet":
       return 1.15; // Master kategorisi, biraz daha yavaş
     case "Süleyman":
       return 0.95; // Profesyonel basketbolcu, hızlı
     case "Ayşe":
       return 1.05; // Genç kadın atlet, orta seviye
     default:
       return 1.0;
   }
 }

 Map<String, double> _getJumpPerformanceLevel(Sporcu sporcu, String jumpType) {
   Map<String, double> baseValues = {};
   
   switch (sporcu.ad) {
     case "İzzet":
       baseValues = {
         'height': jumpType == "CMJ" ? 38.0 : jumpType == "SJ" ? 35.0 : jumpType == "DJ" ? 32.0 : 30.0,
         'flightTime': jumpType == "CMJ" ? 0.450 : jumpType == "SJ" ? 0.430 : jumpType == "DJ" ? 0.410 : 0.400,
         'power': 2800.0,
         'contactTime': 0.180,
       };
       break;
     case "Süleyman":
       baseValues = {
         'height': jumpType == "CMJ" ? 55.0 : jumpType == "SJ" ? 52.0 : jumpType == "DJ" ? 48.0 : 45.0,
         'flightTime': jumpType == "CMJ" ? 0.540 : jumpType == "SJ" ? 0.525 : jumpType == "DJ" ? 0.505 : 0.490,
         'power': 4200.0,
         'contactTime': 0.150,
       };
       break;
     case "Ayşe":
       baseValues = {
         'height': jumpType == "CMJ" ? 42.0 : jumpType == "SJ" ? 39.0 : jumpType == "DJ" ? 36.0 : 34.0,
         'flightTime': jumpType == "CMJ" ? 0.470 : jumpType == "SJ" ? 0.455 : jumpType == "DJ" ? 0.435 : 0.425,
         'power': 2200.0,
         'contactTime': 0.165,
       };
       break;
     default:
       baseValues = {
         'height': 40.0,
         'flightTime': 0.460,
         'power': 3000.0,
         'contactTime': 0.170,
       };
   }
   
   return baseValues;
 }

 Future<void> _updateRJAverages(Database db, int jumpOlcumId, int jumpCount) async {
   // RJ için ortalama değerleri hesapla ve güncelle
   List<Map<String, dynamic>> flights = await db.query(
     'OlcumDegerler',
     where: 'OlcumId = ? AND DegerTuru LIKE ?',
     whereArgs: [jumpOlcumId, 'Flight%'],
   );
   
   List<Map<String, dynamic>> contacts = await db.query(
     'OlcumDegerler',
     where: 'OlcumId = ? AND DegerTuru LIKE ?',
     whereArgs: [jumpOlcumId, 'Contact%'],
   );
   
   List<Map<String, dynamic>> heights = await db.query(
     'OlcumDegerler',
     where: 'OlcumId = ? AND DegerTuru LIKE ?',
     whereArgs: [jumpOlcumId, 'Height%'],
   );
   
   if (flights.isNotEmpty && contacts.isNotEmpty && heights.isNotEmpty) {
     double avgFlight = flights.map((f) => f['Deger'] as double).reduce((a, b) => a + b) / flights.length;
     double avgContact = contacts.map((c) => c['Deger'] as double).reduce((a, b) => a + b) / contacts.length;
     double avgHeight = heights.map((h) => h['Deger'] as double).reduce((a, b) => a + b) / heights.length;
     double avgRSI = avgContact > 0 ? avgFlight / avgContact : 0;
     
     // Ana değerleri güncelle
     await db.update(
       'OlcumDegerler',
       {'Deger': double.parse(avgFlight.toStringAsFixed(3))},
       where: 'OlcumId = ? AND DegerTuru = ?',
       whereArgs: [jumpOlcumId, 'ucusSuresi'],
     );
     
     await db.update(
       'OlcumDegerler',
       {'Deger': double.parse(avgContact.toStringAsFixed(3))},
       where: 'OlcumId = ? AND DegerTuru = ?',
       whereArgs: [jumpOlcumId, 'temasSuresi'],
     );
     
     await db.update(
       'OlcumDegerler',
       {'Deger': double.parse(avgHeight.toStringAsFixed(1))},
       where: 'OlcumId = ? AND DegerTuru = ?',
       whereArgs: [jumpOlcumId, 'yukseklik'],
     );
     
     await db.update(
       'OlcumDegerler',
       {'Deger': double.parse(avgRSI.toStringAsFixed(2))},
       where: 'OlcumId = ? AND DegerTuru = ?',
       whereArgs: [jumpOlcumId, 'rsi'],
     );
   }
 }
}