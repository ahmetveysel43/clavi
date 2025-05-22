import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'screens/home_screen.dart';
import 'screens/sprint_screen.dart';
import 'screens/jump_screen.dart';
import 'screens/analiz_screen.dart';
import 'screens/sporcu_kayit_screen.dart';
import 'screens/sporcu_secim_screen.dart';
import 'screens/dikey_profil_screen.dart';
import 'screens/yatay_profil_screen.dart';
import 'screens/ilerleme_raporu_screen.dart';
import 'screens/test_karsilastirma_screen.dart';
import 'screens/performance_analysis_screen.dart';
import 'services/database_service.dart';
import 'models/sporcu_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // SADECE GELİŞTİRME AŞAMASINDA ÖRNEK VERİ EKLEMEK İÇİN:
  if (kDebugMode) {
    final dbService = DatabaseService();
    
    // Örnek verileri sadece veritabanı boşsa veya belirli bir koşulda eklemek için:
    List<Sporcu> mevcutSporcular = await dbService.getAllSporcular();
    if (mevcutSporcular.isEmpty) {
      debugPrint("Veritabanında sporcu bulunamadı, örnek veriler ekleniyor...");
      await dbService.populateMockData();
    } else {
      debugPrint("Veritabanında ${mevcutSporcular.length} sporcu zaten mevcut, örnek veri eklenmedi.");
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'İzLab Sports',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.blue,
        ).copyWith(
          secondary: Colors.orangeAccent,
        ),
        fontFamily: 'Roboto',
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D47A1),
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.blue[700],
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.orangeAccent[700],
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.grey[400]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.grey[400]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.blue[700]!, width: 2.0),
          ),
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        ),
      ),
      home: const HomeScreen(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/sprint': (context) => const SprintScreen(),
        '/jump': (context) => const JumpScreen(),
        '/analiz': (context) => const AnalizScreen(),
        '/sporcuKayit': (context) => const SporcuKayitScreen(),
        '/sporcuSecim': (context) => const SporcuSecimScreen(),
        '/dikeyProfil': (context) => const DikeyProfilScreen(),
        '/yatayProfil': (context) => const YatayProfilScreen(),
        '/ilerlemeRaporu': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          final sporcuId = args?['sporcuId'];
          if (sporcuId is int) {
            return IlerlemeRaporuScreen(sporcuId: sporcuId);
          }
          return IlerlemeRaporuScreen(sporcuId: 0);
        },
        '/testKarsilastirma': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          final sporcuId = args?['sporcuId'];
          final testType = args?['testType'];
          if (sporcuId is int && testType is String) {
            return TestKarsilastirmaScreen(
              sporcuId: sporcuId,
              testType: testType,
            );
          }
          return TestKarsilastirmaScreen(sporcuId: 0, testType: 'CMJ');
        },
        '/performanceAnalysis': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          return PerformanceAnalysisScreen(
            sporcuId: args?['sporcuId'] as int?,
            olcumTuru: args?['olcumTuru'] as String?,
          );
        }
      },
    );
  }
}