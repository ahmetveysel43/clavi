import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import '../models/sporcu_model.dart';
import '../models/olcum_model.dart';
import '../services/database_service.dart';
import '../services/bluetooth_connection_service.dart';

class JumpGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Zemin çizgisi referansı - alt kısma daha yakın
    final groundLineY = size.height * 0.92; // Altta %8 boşluk bırakarak
    
    // Rehber için boyutlar - daha büyük bir boyut
    final double centerX = size.width / 2;
    final double guideHeight = size.height * 0.80; // Rehberi %80 yüksekliğe çıkar
    final double guideWidth = size.width * 0.70; // Rehberi daha geniş yap (%70)
    
    // Rehber çizgileri için paint - daha kalın ve belirgin
    final Paint dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.86) // withAlpha yerine withValues
      ..strokeWidth = 3 // Çizgi kalınlığını arttırdım
      ..style = PaintingStyle.stroke;
    
    // Yan rehber çizgiler (dikey çizgiler)
    _drawDashedLine(
      canvas, 
      Offset(centerX - guideWidth/2, groundLineY - guideHeight),
      Offset(centerX - guideWidth/2, groundLineY),
      dashPaint
    );
    
    _drawDashedLine(
      canvas, 
      Offset(centerX + guideWidth/2, groundLineY - guideHeight),
      Offset(centerX + guideWidth/2, groundLineY),
      dashPaint
    );
    
    // Üst rehber çizgi (yatay çizgi)
    _drawDashedLine(
      canvas, 
      Offset(centerX - guideWidth/2, groundLineY - guideHeight),
      Offset(centerX + guideWidth/2, groundLineY - guideHeight),
      dashPaint
    );
    
    // Zemin çizgisi çok daha belirgin olsun
    final Paint groundPaint = Paint()
      ..color = Colors.red.withValues(alpha: 1.0) // Tam belirgin kırmızı
      ..strokeWidth = 5 // Daha kalın çizgi
      ..style = PaintingStyle.stroke;
      
    // Zemin çizgisi - daha geniş
    canvas.drawLine(
      Offset(centerX - guideWidth/2 - 30, groundLineY),
      Offset(centerX + guideWidth/2 + 30, groundLineY),
      groundPaint
    );
    
    // Zemin uyarısı için arka plan
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.59) // withAlpha yerine withValues
      ..style = PaintingStyle.fill;
      
    final textSpan = TextSpan(
      text: 'BAŞLANGIÇ NOKTASI',
      style: TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            offset: const Offset(1, 1),
            blurRadius: 3.0,
            color: Colors.black.withValues(alpha: 0.59),
          ),
        ],
      ),
    );
    
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    
    textPainter.layout();
    
    // Kırmızı çizgi üzerinde veya hemen altında dikkat çekici bir etiket
    final textBackgroundRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        centerX - textPainter.width / 2 - 10, 
        groundLineY + 5, 
        textPainter.width + 20, 
        textPainter.height + 10
      ),
      const Radius.circular(8)
    );
    
    canvas.drawRRect(textBackgroundRect, backgroundPaint);
    textPainter.paint(canvas, Offset(centerX - textPainter.width / 2, groundLineY + 10));
  }
  
  // Kesikli çizgi çizme yardımcı metodu (aynı)
  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    // Kesikli çizgi için dash pattern - daha büyük kesikler
    final dashPattern = [8, 8]; // 8 piksel çizgi, 8 piksel boşluk
    final dash = dashPattern[0];
    final gap = dashPattern[1];
    
    // Toplam mesafe
    double distance = (end - start).distance;
    int dashCount = (distance / (dash + gap)).floor();
    
    // Yön vektörü
    double dx = (end.dx - start.dx) / distance;
    double dy = (end.dy - start.dy) / distance;
    
    // Kesikli çizgiyi çiz
    double x = start.dx;
    double y = start.dy;
    bool isDash = true;
    double dashLength = dash.toDouble();
    
    for (int i = 0; i < dashCount; i++) {
      if (isDash) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x + dx * dashLength, y + dy * dashLength),
          paint,
        );
      }
      
      x += dx * (isDash ? dashLength : gap.toDouble());
      y += dy * (isDash ? dashLength : gap.toDouble());
      isDash = !isDash;
      dashLength = isDash ? dash.toDouble() : gap.toDouble();
    }
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}



class JumpAnalysisPainter extends CustomPainter {
  final int takeoffFrame;
  final int landingFrame;
  final int currentFrame;
  final int totalFrames;
  final double fps;
  
  JumpAnalysisPainter({
    required this.takeoffFrame,
    required this.landingFrame,
    required this.currentFrame,
    required this.totalFrames,
    required this.fps,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Video boyunca zaman çizgisi - tüm video genişliği
    final timelineY = size.height - 40; // Alt kısımda bir zaman çizgisi
    
    // Takeoff ve landing pozisyonlarını hesapla (x konumları)
    final double takeoffPos = size.width * (takeoffFrame / totalFrames);
    final double landingPos = size.width * (landingFrame / totalFrames);
    final double currentPos = size.width * (currentFrame / totalFrames);
    
    // Zemin çizgisi
    final Paint groundPaint = Paint()
      ..color = Colors.grey.withAlpha(100)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
      
    canvas.drawLine(
      Offset(0, timelineY),
      Offset(size.width, timelineY),
      groundPaint,
    );
    
    // Uçuş bölgesini çiz
    final Paint flightPaint = Paint()
      ..color = Colors.blue.withAlpha(70)
      ..style = PaintingStyle.fill;
      
    canvas.drawRect(
      Rect.fromLTRB(takeoffPos, 0, landingPos, timelineY),
      flightPaint,
    );
    
    // Kalkış anı gösterimi - Yatay referans çizgisi
    final Paint takeoffLinePaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    
    // Sporcu kalkış ikonu
    _drawTakeoffJumperIcon(canvas, Offset(takeoffPos, timelineY - 80), Colors.green);
    
    // Kalkış anı - Alt çizgi (yatay referans)
    canvas.drawLine(
      Offset(takeoffPos, timelineY - 5),
      Offset(takeoffPos, timelineY + 5),
      takeoffLinePaint,
    );
    
    // İniş anı gösterimi - Yatay referans çizgisi
    final Paint landingLinePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    
    // Sporcu iniş ikonu
    _drawLandingJumperIcon(canvas, Offset(landingPos, timelineY - 80), Colors.red);
    
    // İniş anı - Alt çizgi (yatay referans)
    canvas.drawLine(
      Offset(landingPos, timelineY - 5),
      Offset(landingPos, timelineY + 5),
      landingLinePaint,
    );
    
    // Mevcut frame göstergesi
    final Paint currentPaint = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
      
    canvas.drawLine(
      Offset(currentPos, 0),
      Offset(currentPos, timelineY),
      currentPaint,
    );
    
    // İkon ile zaman çizgisi arasında bağlantı çizgileri
    canvas.drawLine(
      Offset(takeoffPos, timelineY - 40),
      Offset(takeoffPos, timelineY),
      takeoffLinePaint..strokeWidth = 1,
    );
    
    canvas.drawLine(
      Offset(landingPos, timelineY - 40),
      Offset(landingPos, timelineY),
      landingLinePaint..strokeWidth = 1,
    );
    
    // Uçuş süresi bilgisi
    final double flightTime = (landingFrame - takeoffFrame) / fps;
    final double jumpHeight = 0.5 * 9.81 * math.pow(flightTime / 2, 2) * 100;
    
    // Uçuş bilgisi metin kutusu
    final backgroundPaint = Paint()
      ..color = Colors.black.withAlpha(150)
      ..style = PaintingStyle.fill;
      
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.bold,
      shadows: [
        Shadow(
          offset: const Offset(1, 1),
          blurRadius: 3.0,
          color: Colors.black.withAlpha(150),
        ),
      ],
    );
    
    final textSpan = TextSpan(
      text: 'Uçuş: ${flightTime.toStringAsFixed(3)} s\nYükseklik: ${jumpHeight.toStringAsFixed(1)} cm',
      style: textStyle,
    );
    
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    
    textPainter.layout();
    final double midPoint = (takeoffPos + landingPos) / 2 - textPainter.width / 2;
    
    // Bilgi kutusu arka planı
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          midPoint - 10, 
          10, // Üst kısımda göster
          textPainter.width + 20, 
          textPainter.height + 10
        ),
        const Radius.circular(8)
      ),
      backgroundPaint
    );
    
    textPainter.paint(canvas, Offset(midPoint, 15));
  }
  
  // Sporcu kalkış ikonu çizimi - aynı
  void _drawTakeoffJumperIcon(Canvas canvas, Offset position, Color color) {
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.bold,
      shadows: [
        Shadow(
          offset: const Offset(1, 1),
          blurRadius: 3.0,
          color: Colors.black.withAlpha(150),
        ),
      ],
    );
    
    final textSpan = TextSpan(
      text: 'Kalkış',
      style: textStyle,
    );
    
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    
    // Arka plan çiz
    final backgroundPaint = Paint()
      ..color = color.withAlpha(200)
      ..style = PaintingStyle.fill;
      
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          position.dx - textPainter.width / 2 - 25,
          position.dy - 5, 
          textPainter.width + 50,
          textPainter.height + 40
        ),
        const Radius.circular(8)
      ),
      backgroundPaint
    );
    
    // Sporcu kalkış ikonu çiz
    final Paint figurePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    // İkon pozisyonu
    final centerX = position.dx - textPainter.width / 2 + 15;
    final centerY = position.dy + textPainter.height + 15;
    
    // Kafa
    canvas.drawCircle(
      Offset(centerX, centerY - 15),
      5,
      Paint()..color = Colors.white
    );
    
    // Gövde - kalkış pozisyonunda hafif eğik
    canvas.drawLine(
      Offset(centerX, centerY - 10),
      Offset(centerX + 2, centerY + 5),
      figurePaint
    );
    
    // Kollar - kalkış pozisyonunda yukarı uzatılmış
    canvas.drawLine(
      Offset(centerX, centerY - 5),
      Offset(centerX - 8, centerY - 10),
      figurePaint
    );
    
    canvas.drawLine(
      Offset(centerX, centerY - 5),
      Offset(centerX + 8, centerY - 10),
      figurePaint
    );
    
    // Bacaklar - kalkış pozisyonunda aşağı uzatılmış
    canvas.drawLine(
      Offset(centerX + 2, centerY + 5),
      Offset(centerX - 5, centerY + 15),
      figurePaint
    );
    
    canvas.drawLine(
      Offset(centerX + 2, centerY + 5),
      Offset(centerX + 9, centerY + 15),
      figurePaint
    );
    
    // Yukarı ok
    canvas.drawLine(
      Offset(centerX + 15, centerY + 10),
      Offset(centerX + 15, centerY - 10),
      figurePaint
    );
    
    // Ok ucu
    canvas.drawLine(
      Offset(centerX + 15, centerY - 10),
      Offset(centerX + 10, centerY - 5),
      figurePaint
    );
    
    canvas.drawLine(
      Offset(centerX + 15, centerY - 10),
      Offset(centerX + 20, centerY - 5),
      figurePaint
    );
    
    // Metni çiz
    textPainter.paint(canvas, Offset(position.dx - textPainter.width / 2 + 25, position.dy));
  }
  
  // Sporcu iniş ikonu çizimi - aynı
  void _drawLandingJumperIcon(Canvas canvas, Offset position, Color color) {
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.bold,
      shadows: [
        Shadow(
          offset: const Offset(1, 1),
          blurRadius: 3.0,
          color: Colors.black.withAlpha(150),
        ),
      ],
    );
    
    final textSpan = TextSpan(
      text: 'İniş',
      style: textStyle,
    );
    
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    
    // Arka plan çiz
    final backgroundPaint = Paint()
      ..color = color.withAlpha(200)
      ..style = PaintingStyle.fill;
      
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          position.dx - textPainter.width / 2 - 25,
          position.dy - 5, 
          textPainter.width + 50,  
          textPainter.height + 40
        ),
        const Radius.circular(8)
      ),
      backgroundPaint
    );
    
    // Sporcu iniş ikonu çiz
    final Paint figurePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    // İkon pozisyonu
    final centerX = position.dx - textPainter.width / 2 + 15;
    final centerY = position.dy + textPainter.height + 15;
    
    // Kafa
    canvas.drawCircle(
      Offset(centerX, centerY - 15),
      5,
      Paint()..color = Colors.white
    );
    
    // Gövde - iniş pozisyonunda dik
    canvas.drawLine(
      Offset(centerX, centerY - 10),
      Offset(centerX, centerY + 5),
      figurePaint
    );
    
    // Kollar - iniş pozisyonunda yana açık
    canvas.drawLine(
      Offset(centerX, centerY - 5),
      Offset(centerX - 8, centerY),
      figurePaint
    );
    
    canvas.drawLine(
      Offset(centerX, centerY - 5),
      Offset(centerX + 8, centerY),
      figurePaint
    );
    
    // Bacaklar - iniş pozisyonunda hafif kırık
    canvas.drawLine(
      Offset(centerX, centerY + 5),
      Offset(centerX - 8, centerY + 12),
      figurePaint
    );
    
    canvas.drawLine(
      Offset(centerX, centerY + 5),
      Offset(centerX + 8, centerY + 12),
      figurePaint
    );
    
    // Aşağı ok
    canvas.drawLine(
      Offset(centerX + 15, centerY - 10),
      Offset(centerX + 15, centerY + 10),
      figurePaint
    );
    
    // Ok ucu
    canvas.drawLine(
      Offset(centerX + 15, centerY + 10),
      Offset(centerX + 10, centerY + 5),
      figurePaint
    );
    
    canvas.drawLine(
      Offset(centerX + 15, centerY + 10),
      Offset(centerX + 20, centerY + 5),
      figurePaint
    );
    
    // Metni çiz
    textPainter.paint(canvas, Offset(position.dx - textPainter.width / 2 + 25, position.dy));
  }
  
  @override
  bool shouldRepaint(covariant JumpAnalysisPainter oldDelegate) {
    // Optimizasyon için sadece değişiklik olduğunda yeniden çiz
    return oldDelegate.takeoffFrame != takeoffFrame ||
           oldDelegate.landingFrame != landingFrame ||
           // Akıcılık için her karede yeniden çizmeye gerek yok,
           // Sadece kare değiştiğinde yeniden çiz
           (oldDelegate.currentFrame != currentFrame && currentFrame % 2 == 0);
  }
}

class JumpScreen extends StatefulWidget {
  final int? sporcuId;
  const JumpScreen({super.key, this.sporcuId});

  @override
  State<JumpScreen> createState() => _JumpScreenState();
}

class _JumpScreenState extends State<JumpScreen> with WidgetsBindingObserver {
  final _dbService = DatabaseService();
  final _btService = BluetoothConnectionService.instance;

  bool _isLoading = true;
  bool _isConnected = false;
  Sporcu? _sporcu;
  OlcumTuru _jumpType = OlcumTuru.cmj;
  int _secilenOlcumNo = 1;
  int _threshold = 500;
  List<double> _sensorValues = List.filled(7, 0.0);
  List<double> _displaySensorValues = List.filled(7, 8190.0);
  StreamSubscription<String>? _btSubscription;
  
  // Form controller
  final _vucutAgirligiController = TextEditingController();
  
  // Ölçüm sonuçları
  final _olcumVerileri = List.generate(
    7,
    (_) => <String, double?>{'ucusSuresi': null, 'yukseklik': null, 'guc': null, 'temasSuresi': null, 'rsi': null, 'ritim': null},
  );
  
  // Sıçrama ölçüm değişkenleri
  Timer? _timer;
  bool _islemBasladi = false;
  bool _zemindeMi = true;
  DateTime? _kalkisZamani;
  DateTime? _inisZamani;
  Duration _ucusSuresi = Duration.zero;
  Duration _temasSuresi = Duration.zero;
  int _sicramaSayisi = 0;
  DateTime? _rjBaslamaZamani;
  final _flightTimes = <Duration>[];
  final _contactTimes = <Duration>[];
  final _jumpHeights = <double>[];
  bool _showSensors = false;
  
  // Video kayıt değişkenleri
  bool _useVideoMode = false;
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  bool _isAnalyzing = false;
  String? _videoPath;
  VideoPlayerController? _videoPlayerController;
  
  // Video analizi için değişkenler
  int? _takeoffFrame;
  int? _landingFrame;
  double _fps = 60.0; // Varsayılan FPS, manuel olarak değiştirilebilir
  final _fpsController = TextEditingController(text: '60.0'); // FPS için TextField controller'ı

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _setupBluetooth();
    _initializeCamera();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _loadData() async {
    try {
      if (widget.sporcuId != null) {
        _sporcu = await _dbService.getSporcu(widget.sporcuId!);
        if (_sporcu?.kilo != null) _vucutAgirligiController.text = _sporcu!.kilo!;
      }
    } catch (e) {
      debugPrint('Yükleme hatası: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setupBluetooth() async {
    try {
      setState(() => _isConnected = _btService.isConnected);
      _btSubscription = _btService.dataStream.listen(
        _processBluetoothData,
        onError: (e) => _showSnackBar('Bluetooth veri hatası: $e'),
      );
    } catch (e) {
      _showSnackBar('Bluetooth başlatma hatası: $e');
    }
  }

  void _processBluetoothData(String data) {
    try {
      final values = data.trim().split(' ');
      if (values.length < 5 || values.any((v) => double.tryParse(v) == null)) return;

      setState(() {
        _sensorValues = values.map((v) => double.parse(v)).toList();
        _displaySensorValues = _sensorValues.map((value) => value >= _threshold ? 8190.0 : value).toList();
      });

      if (_islemBasladi && !_useVideoMode) _processMeasurement();
    } catch (e) {
      debugPrint('Bluetooth veri işleme hatası: $e');
    }
  }

  void _processMeasurement() {
  final anyActive = _sensorValues.any((v) => v < _threshold);
  final allAbove = _sensorValues.every((v) => v >= _threshold);

  if (_zemindeMi && allAbove) {
    _zemindeMi = false;
    _kalkisZamani = DateTime.now();
    if (_inisZamani != null) _temasSuresi = _kalkisZamani!.difference(_inisZamani!);
    if (_jumpType == OlcumTuru.rj && _sicramaSayisi == 0) _rjBaslamaZamani = DateTime.now();
  } else if (!_zemindeMi && anyActive) {
    _zemindeMi = true;
    _inisZamani = DateTime.now();

    if (_kalkisZamani != null) {
      _ucusSuresi = _inisZamani!.difference(_kalkisZamani!);
      _sicramaSayisi++;

      final ucusSaniye = _ucusSuresi.inMicroseconds / 1000000.0;
      final yukseklikCM = 0.5 * 9.81 * pow(ucusSaniye / 2, 2) * 100;
      final kilo = double.tryParse(_vucutAgirligiController.text) ?? double.tryParse(_sporcu?.kilo ?? '') ?? 0;
      final guc = kilo > 0 ? 61.9 * yukseklikCM + 36.0 * kilo + 1822 : null;
      final temasSaniye = _temasSuresi.inMicroseconds > 0 ? _temasSuresi.inMicroseconds / 1000000.0 : null;
      
      // RSI hesaplaması - düzeltilmiş
      double? rsi;
      if ((_jumpType == OlcumTuru.dj || _jumpType == OlcumTuru.rj) && temasSaniye != null && temasSaniye > 0) {
        // StatisticsHelper metodunu kullan
        rsi = ucusSaniye / temasSaniye; // Basit RSI formülü
      }
      
      final ritim = _jumpType == OlcumTuru.rj && _sicramaSayisi > 0 && _rjBaslamaZamani != null
          ? _sicramaSayisi / (DateTime.now().difference(_rjBaslamaZamani!).inMilliseconds / 1000.0)
          : null;

      if (_isValidJump(yukseklikCM, ucusSaniye)) {
        setState(() {
          _olcumVerileri[_secilenOlcumNo - 1] = {
            'ucusSuresi': ucusSaniye,
            'yukseklik': yukseklikCM,
            'guc': guc,
            'temasSuresi': temasSaniye,
            'rsi': rsi,
            'ritim': ritim,
          };

          if (_jumpType == OlcumTuru.rj) {
            _flightTimes.add(_ucusSuresi);
            _contactTimes.add(_temasSuresi);
            _jumpHeights.add(yukseklikCM);
            if (_rjBaslamaZamani != null && DateTime.now().difference(_rjBaslamaZamani!).inSeconds >= 15) {
              _stopMeasurement('Tekrarlı sıçrama ölçümü tamamlandı (15 saniye)');
            }
          } else if (_sicramaSayisi >= 1) {
            _stopMeasurement('${_jumpType.displayName} ölçümü tamamlandı');
          }
        });
      } else {
        debugPrint('Geçersiz sıçrama tespit edildi: $yukseklikCM cm, $ucusSaniye saniye');
      }
    }
  }
}
  
  bool _isValidJump(double height, double flightTime) {
    if (height > 120 || height < 3) return false;
    if (flightTime < 0.15) return false;
    return true;
  }

  Future<void> _toggleConnection() async {
    if (_isConnected) {
      _btService.disconnect();
      setState(() {
        _isConnected = false;
        _sensorValues = List.filled(7, 0.0);
        _displaySensorValues = List.filled(7, 8190.0);
      });
    } else {
      try {
        final connected = await _btService.connectWithDeviceSelection(context);
        setState(() => _isConnected = connected);
        if (!connected) _showSnackBar('Bluetooth cihazı bağlanamadı.');
      } catch (e) {
        _showSnackBar('Bluetooth bağlantı hatası: $e');
      }
    }
  }

  

     Future<void> _initializeCamera() async {
  final cameras = await availableCameras();
  if (cameras.isEmpty) return;
  
  final rearCamera = cameras.firstWhere(
    (camera) => camera.lensDirection == CameraLensDirection.back,
    orElse: () => cameras.first
  );
  
  // Mevcut kontrolör varsa dispose et
  if (_cameraController != null) {
    await _cameraController!.dispose();
  }
  
  _cameraController = CameraController(
    rearCamera,
    ResolutionPreset.max, // En yüksek çözünürlük
    enableAudio: false,
    imageFormatGroup: ImageFormatGroup.jpeg,
  );
  
  try {
    await _cameraController!.initialize();
    
    // Kamera ayarlarını optimize et - yüksek FPS için
    try {
      // Bazı cihazlarda desteklenmeyebilir
      await _cameraController!.setFocusMode(FocusMode.auto);
      await _cameraController!.setExposureMode(ExposureMode.auto);
      await _cameraController!.setFlashMode(FlashMode.off);
      
      // Bazı cihazlar için FPS ayarı varsa max yap
      _cameraController!.getMaxZoomLevel();
    } catch (e) {
      debugPrint('Kamera optimizasyon hatası: $e');
    }
    
    if (mounted) {
      setState(() => _isCameraInitialized = true);
    }
  } catch (e) {
    debugPrint('Kamera başlatma hatası: $e');
  }
}
  
  Future<void> _startVideoRecording() async {
    if (!_isCameraInitialized || _isRecording) return;
    
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = '${tempDir.path}/jump_${DateTime.now().millisecondsSinceEpoch}.mp4';
      
      await _cameraController!.startVideoRecording();
      
      setState(() {
        _isRecording = true;
        _videoPath = tempPath;
        _islemBasladi = true;
        _takeoffFrame = null;
        _landingFrame = null;
      });
      
      _showSnackBar('Sıçrama için hazırlanın...', const Color(0xFF3498DB));
      
      Future.delayed(const Duration(seconds: 5), () {
        if (_isRecording) {
          _stopVideoRecording();
        }
      });
    } catch (e) {
      _showSnackBar('Video kaydı başlatılamadı: $e');
    }
  }
  
  Future<void> _stopVideoRecording() async {
    if (!_isRecording || _cameraController == null) return;
    
    try {
      final videoFile = await _cameraController!.stopVideoRecording();
      
      setState(() {
        _isRecording = false;
        _videoPath = videoFile.path;
      });
      
      _showSnackBar('Video kaydedildi, lütfen kareleri seçin...');
      
      _videoPlayerController?.dispose();
      _videoPlayerController = VideoPlayerController.file(File(_videoPath!));
      await _videoPlayerController!.initialize();
      await _videoPlayerController!.setLooping(false);
      
      setState(() {});
    } catch (e) {
      setState(() => _isRecording = false);
      _showSnackBar('Video kaydı durdurulamadı: $e');
    }
  }

Future<void> _pickVideoFromDevice() async {
  try {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _videoPath = result.files.single.path;
        _takeoffFrame = null;
        _landingFrame = null;
      });

      // Optimize edilmiş başlatma fonksiyonunu kullan
      await _initializeVideoPlayer(_videoPath!);
      _showSnackBar('Video başarıyla seçildi');
    } else {
      _showSnackBar('Video seçimi iptal edildi');
    }
  } catch (e) {
    _showSnackBar('Video seçimi sırasında hata oluştu: $e');
  }
}

// _initializeVideoPlayer metodunu güncelle:
Future<void> _initializeVideoPlayer(String videoPath) async {
  try {
    _videoPlayerController?.dispose();
    
    _videoPlayerController = VideoPlayerController.file(
      File(videoPath),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: false,
        allowBackgroundPlayback: false,
      ),
    );
    
    await _videoPlayerController!.initialize();
    
    // FPS tespiti için metadata kontrolü
    final videoDuration = _videoPlayerController!.value.duration;
    if (videoDuration.inMilliseconds > 0) {
      // Varsayılan FPS değerleri
      setState(() {
        // Video çözünürlüğüne göre tahmini FPS
        final height = _videoPlayerController!.value.size.height;
        if (height >= 1080) {
          _fps = 30.0; // Full HD genelde 30fps
        } else if (height >= 720) {
          _fps = 60.0; // HD genelde 60fps olabilir
        } else {
          _fps = 30.0; // Varsayılan
        }
        _fpsController.text = _fps.toString();
      });
    }
    
    await _videoPlayerController!.setPlaybackSpeed(1.0);
    await _videoPlayerController!.setLooping(false);
    await _videoPlayerController!.seekTo(const Duration(milliseconds: 1));
    await _videoPlayerController!.pause();
    
    setState(() {});
    _addVideoPositionListener();
    
  } catch (e) {
    debugPrint('Video oynatıcı başlatma hatası: $e');
    _showSnackBar('Video oynatılamadı: $e');
  }
}
  double _calculateJumpHeight(double flightTime) {
    const double g = 9.81; // Yerçekimi ivmesi (m/s²)
    final heightInMeters = 0.5 * g * pow(flightTime / 2, 2);
    return heightInMeters * 100; // Santimetreye çevir
  }

  Future<void> _analyzeJumpVideo() async {
    if (_videoPath == null || _videoPlayerController == null || _takeoffFrame == null || _landingFrame == null) {
      _showSnackBar('Lütfen başlangıç ve bitiş karelerini seçin');
      return;
    }
    
    setState(() => _isAnalyzing = true);
    
    try {
      final frameCount = _landingFrame! - _takeoffFrame!;
      if (frameCount <= 0) {
        _showSnackBar('Bitiş karesi başlangıç karesinden önce olamaz');
        setState(() => _isAnalyzing = false);
        return;
      }
      
      final flightTime = frameCount / _fps; // Dinamik FPS kullanılıyor
      final jumpHeight = _calculateJumpHeight(flightTime);
      
      // Kilo değerini kontrol et, yoksa varsayılan olarak 70 kg kullan
      final kilo = double.tryParse(_vucutAgirligiController.text) ?? 
                  double.tryParse(_sporcu?.kilo ?? '') ?? 70.0;
      
      // Güç hesaplama formülü
      final guc = 61.9 * jumpHeight + 36.0 * kilo + 1822;
      
      setState(() {
        _olcumVerileri[_secilenOlcumNo - 1] = {
          'ucusSuresi': flightTime,
          'yukseklik': jumpHeight,
          'guc': guc,
          'temasSuresi': null, // Video analizinde temas süresi hesaplanmıyor
          'rsi': null,
          'ritim': null,
        };
        _isAnalyzing = false;
        _islemBasladi = false;
      });
      
      // Sonuçları göster
      _showSuccessDialog(jumpHeight, flightTime, guc);
    } catch (e) {
      setState(() => _isAnalyzing = false);
      _showSnackBar('Video analiz edilemedi: $e');
    }
  }
  
  void _showSuccessDialog(double height, double flightTime, double power) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF27AE60).withAlpha(50), // 0.2 * 255 ≈ 50
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, color: Color(0xFF27AE60)),
          ),
          const SizedBox(width: 12),
          const Text('Analiz Tamamlandı', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildResultRow('Sıçrama Yüksekliği', '${height.toStringAsFixed(1)} cm', Icons.height, const Color(0xFF3498DB)),
          const SizedBox(height: 8),
          _buildResultRow('Uçuş Süresi', '${flightTime.toStringAsFixed(3)} sn', Icons.timer, const Color(0xFFF39C12)),
          const SizedBox(height: 8),
          _buildResultRow('Güç', '${power.toStringAsFixed(1)} W', Icons.bolt, const Color(0xFF8E44AD)),
          const SizedBox(height: 16),
          const Text(
            'Ölçümünüz başarıyla kaydedildi. İsterseniz farklı ölçüm numaralarına da kaydedebilirsiniz.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kapat'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            _clearMeasurement();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3498DB),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Yeni Ölçüm', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

Widget _buildResultRow(String label, String value, IconData icon, Color color) {
  return Row(
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withAlpha(50), // 0.2 * 255 ≈ 50
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
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
      ),
    ],
  );
}
 
  
  void _startMeasurement() {
    if (_vucutAgirligiController.text.isEmpty && (_sporcu?.kilo == null || _sporcu!.kilo!.isEmpty)) {
      return _showSnackBar('Lütfen vücut ağırlığını girin');
    }

    setState(() {
      _islemBasladi = true;
      _zemindeMi = true;
      _kalkisZamani = null;
      _inisZamani = null;
      _ucusSuresi = Duration.zero;
      _temasSuresi = Duration.zero;
      _sicramaSayisi = 0;
      _rjBaslamaZamani = null;
      _flightTimes.clear();
      _contactTimes.clear();
      _jumpHeights.clear();
    });

    _timer = Timer.periodic(const Duration(milliseconds: 10), (_) => setState(() {}));

    _showSnackBar('${_jumpType.displayName} ölçümü başlatıldı');
  }

  void _stopMeasurement([String message = 'Ölçüm durduruldu']) {
    setState(() {
      _islemBasladi = false;
      _timer?.cancel();
    });
    
    _showSnackBar(message);
  }

void _clearMeasurement() {
    setState(() {
      _islemBasladi = false;
      _zemindeMi = true;
      _kalkisZamani = null;
      _inisZamani = null;
      _ucusSuresi = Duration.zero;
      _temasSuresi = Duration.zero;
      _sicramaSayisi = 0;
      _rjBaslamaZamani = null;
      _olcumVerileri[_secilenOlcumNo - 1] = {
        'ucusSuresi': null,
        'yukseklik': null,
        'guc': null,
        'temasSuresi': null,
        'rsi': null,
        'ritim': null,
      };
      _flightTimes.clear();
      _contactTimes.clear();
      _jumpHeights.clear();
      
      _videoPlayerController?.dispose();
      _videoPlayerController = null;
      _videoPath = null;
      _takeoffFrame = null;
      _landingFrame = null;
    });
    _timer?.cancel();
    
    _showSnackBar('Ölçüm temizlendi');
  }

  Future<void> _saveMeasurements() async {
    final currentData = _olcumVerileri[_secilenOlcumNo - 1];
    if (!currentData.values.any((value) => value != null)) {
      return _showSnackBar('Kaydedilecek ölçüm verisi bulunamadı');
    }

    try {
      final testId = await _dbService.getNewTestId();
      final olcum = Olcum(
        sporcuId: widget.sporcuId ?? 0,
        testId: testId,
        olcumTarihi: DateTime.now().toIso8601String(),
        olcumTuru: _jumpType.name.toUpperCase(),
        olcumSirasi: _secilenOlcumNo,
      );

      final olcumId = await _dbService.insertOlcum(olcum);

      for (var entry in currentData.entries) {
        if (entry.value != null) {
          await _dbService.insertOlcumDeger(OlcumDeger(
            olcumId: olcumId,
            degerTuru: entry.key,
            deger: entry.value!,
          ));
        }
      }

      if (_jumpType == OlcumTuru.rj) {
        for (var i = 0; i < _flightTimes.length; i++) {
          await _dbService.insertOlcumDeger(OlcumDeger(
            olcumId: olcumId,
            degerTuru: 'Flight${i + 1}',
            deger: _flightTimes[i].inMilliseconds / 1000.0,
          ));
          
          if (i < _contactTimes.length) {
            await _dbService.insertOlcumDeger(OlcumDeger(
              olcumId: olcumId,
              degerTuru: 'Contact${i + 1}',
              deger: _contactTimes[i].inMilliseconds / 1000.0,
            ));
          }
          
          if (i < _jumpHeights.length) {
            await _dbService.insertOlcumDeger(OlcumDeger(
              olcumId: olcumId,
              degerTuru: 'Height${i + 1}',
              deger: _jumpHeights[i],
            ));
          }
        }
      }

      _showSnackBar(
        widget.sporcuId != null 
          ? 'Ölçüm başarıyla kaydedildi' 
          : 'Sporcu seçilmeden ölçüm kaydedildi',
        const Color(0xFF4CAF50),
      );
    } catch (e) {
      _showSnackBar('Ölçüm kaydedilemedi: $e', Colors.red);
    }
  }

  // Zaman formatı yardımcı metodu
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _btSubscription?.cancel();
    _timer?.cancel();
    _btService.disconnect();
    _cameraController?.dispose();
    _videoPlayerController?.dispose();
    _vucutAgirligiController.dispose();
    _fpsController.dispose();
    super.dispose();
  }

 @override
Widget build(BuildContext context) {
  // Ekran boyutlarını al
  final screenSize = MediaQuery.of(context).size;
  final isSmallScreen = screenSize.width < 360;
  
  return Scaffold(
    backgroundColor: const Color(0xFFF8FAFC),
    appBar: AppBar(
      title: const Text('Sıçrama Testi', style: TextStyle(fontWeight: FontWeight.bold)),
      centerTitle: true,
      backgroundColor: const Color(0xFF2C3E50),
      elevation: 0,
      actions: [
        IconButton(
          icon: Icon(_showSensors ? Icons.visibility_off : Icons.visibility, color: Colors.white),
          onPressed: () => setState(() => _showSensors = !_showSensors),
          tooltip: _showSensors ? 'Sensörleri Gizle' : 'Sensörleri Göster',
        ),
      ],
    ),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              _buildHeader(),
              
              // Mod seçici
              Container(
                padding: const EdgeInsets.all(8),
                margin: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 8 : 16, 
                  vertical: isSmallScreen ? 4 : 8
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.sensors, size: 16),
                            SizedBox(width: 8),
                            Text('Sensör Modu'),
                          ],
                        ),
                        selected: !_useVideoMode,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _useVideoMode = false);
                          }
                        },
                        selectedColor: const Color(0xFF0288D1),
                        labelStyle: TextStyle(
                          color: !_useVideoMode ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ChoiceChip(
                        label: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.videocam, size: 16),
                            SizedBox(width: 8),
                            Text('Video Modu'),
                          ],
                        ),
                        selected: _useVideoMode,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _useVideoMode = true);
                            if (!_isCameraInitialized) {
                              _initializeCamera();
                            }
                          }
                        },
                        selectedColor: const Color(0xFF0288D1),
                        labelStyle: TextStyle(
                          color: _useVideoMode ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 16),
                  child: Column(
                    children: [
                      _buildJumpTypeSelector(),
                      const SizedBox(height: 16),
                      
                      if (_useVideoMode && _isCameraInitialized)
                        _buildCameraPreview()
                      else
                        _buildConfigSection(),
                        
                      const SizedBox(height: 16),
                      _buildMeasurementSection(),
                      
                      if (_islemBasladi && !_useVideoMode) 
                        _buildLiveStatus(),
                        
                      if (_useVideoMode && _videoPath != null)
                        _buildVideoPlayer(),
                    ],
                  ),
                ),
              ),
              
              _buildActionButtons(),
            ],
          ),
  );
}

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2C3E50),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _sporcu != null ? '${_sporcu!.ad} ${_sporcu!.soyad}' : 'Sporcu Seçilmedi',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (!_useVideoMode) 
                  ElevatedButton.icon(
                    onPressed: _toggleConnection,
                    icon: Icon(_isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled),
                    label: Text(_isConnected ? 'Bağlı' : 'Bağlı Değil'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isConnected ? const Color(0xFF27AE60) : const Color(0xFFE74C3C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
              ],
            ),
          ),
          if (_showSensors && !_useVideoMode) _buildSensorIndicators(),
        ],
      ),
    );
  }

 Widget _buildJumpTypeSelector() {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5)),
      ],
    ),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Test Türü', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: OlcumTuru.values.where((t) => t != OlcumTuru.sprint).map((type) {
              final isSelected = _jumpType == type;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(type.name.toUpperCase()),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _jumpType = type);
                  },
                  color: WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.selected)) {
                      return const Color(0xFF3498DB);
                    }
                    return const Color(0xFFECF0F1);
                  }),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF2C3E50),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    ),
  );
}


Widget _buildCameraPreview() {
  if (!_isCameraInitialized || _cameraController == null) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7, // Yüksekliği %70'e çıkardım
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('Kamera başlatılıyor...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // Ekran boyutunu al
  final screenSize = MediaQuery.of(context).size;
  
  // Video boyutlarını ekran boyutlarına göre ayarla
  // Genişliği ekran genişliği, yüksekliği ekranın %70'i olarak ayarlayarak diklemesine büyüt
  final videoWidth = screenSize.width;
  final videoHeight = screenSize.height * 0.7; // Ekranın %70'i kadar yükseklik

  return Column(
    children: [
      // Kamera önizleme konteynerini diklemesine büyüt
      Container(
        width: videoWidth,
        height: videoHeight,
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Kamera önizleme - genişletilmiş halde (oranı korumak zorunda değiliz)
            CameraPreview(_cameraController!),
            
            // Sıçrama rehber alanı - tam video boyutunda
            CustomPaint(
              painter: JumpGuidePainter(),
              size: Size(videoWidth, videoHeight),
            ),
            
            // Kayıt göstergesi
            if (_isRecording)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(200),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'KAYDEDİLİYOR',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Loading overlay
            if (_isRecording || _isAnalyzing)
              Container(
                color: Colors.black.withAlpha(150),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 16),
                      Text(
                        _isRecording ? 'Kayıt alınıyor...' : 'Analiz ediliyor...',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      
      // Kullanım talimatı - daha kompakt hale getiriyorum
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Kenar boşluklarını azalttım
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withAlpha(30),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Text(
          'Kırmızı çizginin üzerinde durun ve BAŞLAT butonuna basın. Ardından sıçramanızı gerçekleştirin.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold), // Font boyutunu azalttım
        ),
      ),
      
      // Kayıtlı video analiz butonu - daha kompakt
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ElevatedButton.icon(
          onPressed: _pickVideoFromDevice,
          icon: const Icon(Icons.movie, color: Colors.white, size: 20), // İkon boyutunu azalttım
          label: const Text('Kayıtlı Videoyu Analiz Et', 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)), // Font boyutunu azalttım
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3498DB),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Padding'i azalttım
            minimumSize: const Size(double.infinity, 48), // Yüksekliği azalttım
          ),
        ),
      ),
    ],
  );
}

  Widget _buildConfigSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ayarlar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _vucutAgirligiController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Vücut Ağırlığı (kg)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.fitness_center),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _threshold,
                  decoration: InputDecoration(
                    labelText: 'Eşik Değeri (mm)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.tune),
                  ),
                  items: List.generate(29, (i) => 100 + i * 50)
                      .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                      .toList(),
                  onChanged: (value) => setState(() => _threshold = value!),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ölçüm Sonuçları', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3498DB),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Ölçüm $_secilenOlcumNo', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(7, (i) {
                final isSelected = _secilenOlcumNo == i + 1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _secilenOlcumNo = i + 1),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF3498DB) : const Color(0xFFECF0F1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF2C3E50),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 20),
          _buildResultCards(),
        ],
      ),
    );
  }

  Widget _buildResultCards() {
    final results = _olcumVerileri[_secilenOlcumNo - 1];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildResultCard('Yükseklik', results['yukseklik'], 'cm', Icons.height, const Color(0xFF27AE60)),
        _buildResultCard('Uçuş Süresi', results['ucusSuresi'], 's', Icons.timer, const Color(0xFF3498DB)),
        _buildResultCard('Güç', results['guc'], 'W', Icons.bolt, const Color(0xFFF39C12)),
        _buildResultCard('Temas Süresi', results['temasSuresi'], 's', Icons.touch_app, const Color(0xFF8E44AD)),
        if (_jumpType == OlcumTuru.dj || _jumpType == OlcumTuru.rj)
          _buildResultCard('RSI', results['rsi'], '', Icons.speed, const Color(0xFFE74C3C)),
        if (_jumpType == OlcumTuru.rj)
          _buildResultCard('Ritim', results['ritim'], '/s', Icons.loop, const Color(0xFF16A085)),
      ],
    );
  }

 Widget _buildResultCard(String label, double? value, String unit, IconData icon, Color color) {
  return Container(
    decoration: BoxDecoration(
      color: color.withAlpha(25),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withAlpha(75)),
    ),
    padding: const EdgeInsets.all(12),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value != null ? '${value.toStringAsFixed(2)} $unit' : '-',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withAlpha(200),
          ),
        ),
      ],
    ),
  );
}


Widget _buildVideoPlayer() {
  if (_videoPath == null || _videoPlayerController == null || !_videoPlayerController!.value.isInitialized) {
    // Boş durumu aynı kalsın ama yüksekliği arttıralım
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.5, // Yüksekliği arttırdım
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.grey.withAlpha(40), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Kayıt Önizleme ve Analiz', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _pickVideoFromDevice,
            icon: const Icon(Icons.upload_file, color: Colors.white),
            label: const Text('Harici Video Seç', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // Ekran boyutlarını al
  final screenSize = MediaQuery.of(context).size;
  final videoHeight = screenSize.height * 0.7; // Kamera önizleme boyutuyla aynı
  
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(color: Colors.grey.withAlpha(40), blurRadius: 20, offset: const Offset(0, 10)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık ve bilgi satırı
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Video Analizi', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3498DB),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      _takeoffFrame != null && _landingFrame != null 
                          ? '${(_landingFrame! - _takeoffFrame!)} kare' 
                          : 'Kareler seçilmedi',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Video Oynatıcı - Boyutu arttırıldı
        Container(
  width: screenSize.width,
  height: videoHeight, // Diklemesine büyüttüm
  color: Colors.black,
  child: Stack(
    fit: StackFit.expand,
    children: [
      // Video Player - ekranı dolduracak şekilde
      Builder(
        builder: (context) {
          // Video oranını al
          final videoWidth = _videoPlayerController!.value.size.width;
          final videoHeight = _videoPlayerController!.value.size.height;
          final videoRatio = videoWidth / videoHeight;
          
          // Ekran oranını al
          final screenRatio = screenSize.width / videoHeight;
          
          // Eğer video geniş ekransa (landscape) fit etmek için farklı ayarla
          if (videoRatio > screenRatio) {
            // Geniş video - yüksekliğe göre ölçeklendir
            return SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.fitHeight,
                child: SizedBox(
                  width: videoWidth,
                  height: videoHeight,
                  child: VideoPlayer(_videoPlayerController!),
                ),
              ),
            );
          } else {
            // Dar video - genişliğe göre ölçeklendir
            return SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.fitWidth,
                child: SizedBox(
                  width: videoWidth,
                  height: videoHeight, 
                  child: VideoPlayer(_videoPlayerController!),
                     ),
              ),
            );
          }
        },
      ),
              
              // Frame bilgisi göstergesi
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(180),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Kare: ${(_videoPlayerController!.value.position.inMilliseconds * _fps / 1000).round()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              // Oynat/duraklat butonu
              Center(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _videoPlayerController!.value.isPlaying
                          ? _videoPlayerController!.pause()
                          : _videoPlayerController!.play();
                    });
                  },
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(120),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _videoPlayerController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
              
              // Sıçrama rehber çizgileri - takeoff ve landing kareleri seçildiyse
              if (_takeoffFrame != null && _landingFrame != null)
                CustomPaint(
                  painter: JumpAnalysisPainter(
                    takeoffFrame: _takeoffFrame!,
                    landingFrame: _landingFrame!,
                    currentFrame: (_videoPlayerController!.value.position.inMilliseconds * _fps / 1000).round(),
                    totalFrames: (_videoPlayerController!.value.duration.inMilliseconds * _fps / 1000).round(),
                    fps: _fps,
                  ),
                ),
              
              // Hassas Kontroller Overlay - Video İçinde
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  color: Colors.black.withAlpha(150),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildInlineVideoControl(
                        icon: Icons.fast_rewind,
                        label: '0.5s',
                        onPressed: () {
                          final currentPosition = _videoPlayerController!.value.position;
                          _videoPlayerController!.seekTo(
                            currentPosition - const Duration(milliseconds: 500)
                          );
                          _videoPlayerController!.pause();
                          setState(() {});
                        },
                      ),
                      _buildInlineVideoControl(
                        icon: Icons.replay_5,
                        label: '1k',
                        onPressed: _seekOneFrameBack, 
                      ),
                      _buildInlineVideoControl(
                        icon: Icons.forward_5,
                        label: '1k',
                        onPressed: _seekOneFrameForward,
                      ),
                      _buildInlineVideoControl(
                        icon: Icons.fast_forward,
                        label: '0.5s',
                        onPressed: () {
                          final currentPosition = _videoPlayerController!.value.position;
                          _videoPlayerController!.seekTo(
                            currentPosition + const Duration(milliseconds: 500)
                          );
                          _videoPlayerController!.pause();
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Video İlerleme Çubuğu
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF3498DB),
              inactiveTrackColor: Colors.grey[300],
              thumbColor: const Color(0xFF3498DB),
              overlayColor: const Color(0xFF3498DB).withAlpha(50),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              trackHeight: 6.0,
            ),
            child: Slider(
              value: _videoPlayerController!.value.position.inMilliseconds.toDouble(),
              min: 0,
              max: _videoPlayerController!.value.duration.inMilliseconds.toDouble(),
              onChanged: (value) async {
                await _videoPlayerController!.seekTo(Duration(milliseconds: value.toInt()));
                setState(() {});
              },
              label: '${(_videoPlayerController!.value.position.inMilliseconds / 1000).toStringAsFixed(1)} s',
            ),
          ),
        ),
        
        // Zaman Göstergesi
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_videoPlayerController!.value.position),
                style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.bold),
              ),
              Text(
                _formatDuration(_videoPlayerController!.value.duration),
                style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        
        // ANAHTAR KALKIŞ/İNİŞ BUTONLARI VİDEO İLE BİRLİKTE GÖRÜNSÜN
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCompactFrameSelector(
                label: 'Kalkış Karesi Seç',
                frameNumber: _takeoffFrame,
                icon: Icons.flight_takeoff,
                color: Colors.green,
                onPressed: _videoPlayerController == null
                    ? null
                    : () async {
                        final position = await _videoPlayerController!.position;
                        if (position != null) {
                          setState(() {
                            _takeoffFrame = (position.inMilliseconds * _fps / 1000).round();
                          });
                          _showSnackBar('Kalkış karesi seçildi: $_takeoffFrame');
                        } else {
                          _showSnackBar('Video pozisyonu alınamadı');
                        }
                      },
              ),
              _buildCompactFrameSelector(
                label: 'İniş Karesi Seç',
                frameNumber: _landingFrame,
                icon: Icons.flight_land,
                color: Colors.red,
                onPressed: _videoPlayerController == null
                    ? null
                    : () async {
                        final position = await _videoPlayerController!.position;
                        if (position != null) {
                          setState(() {
                            _landingFrame = (position.inMilliseconds * _fps / 1000).round();
                          });
                          _showSnackBar('İniş karesi seçildi: $_landingFrame');
                        } else {
                          _showSnackBar('Video pozisyonu alınamadı');
                        }
                      },
              ),
            ],
          ),
        ),
        
        // FPS ve Yeni Video seçme
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _fpsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'FPS Değeri',
                    labelStyle: TextStyle(color: Colors.grey[700], fontSize: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    prefixIcon: const Icon(Icons.speed, size: 20, color: Color(0xFF3498DB)),
                  ),
                  onChanged: (value) {
                    final newFps = double.tryParse(value);
                    if (newFps != null && newFps > 0) {
                      setState(() {
                        _fps = newFps;
                      });
                    } else {
                      _showSnackBar('Geçerli bir FPS değeri girin');
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _pickVideoFromDevice,
                  icon: const Icon(Icons.movie, size: 20),
                  label: const Text('Yeni Video'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Analiz Butonunu en alta yerleştir
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: (_takeoffFrame != null && _landingFrame != null) ? _analyzeJumpVideo : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3498DB),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[300],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              minimumSize: const Size(double.infinity, 50), // Biraz daha kompakt
              elevation: 4,
            ),
            child: const Text(
              'SICRAMA ANALİZİNİ TAMAMLA',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}


void _seekOneFrameBack() {
  if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) return;
  
  try {
    // Mevcut pozisyon ve frame süresi hesaplama
    final currentPosition = _videoPlayerController!.value.position;
    final frameTime = Duration(microseconds: (1000000 / _fps).round());
    
    // Yeni pozisyon hesaplama ve atlama - daha hassas
    final newPosition = currentPosition - frameTime;
    final safePosition = newPosition > Duration.zero ? newPosition : Duration.zero;
    
    // Sadece arama fonksiyonunu çağır - ekstra işlemler yapma
    _videoPlayerController!.seekTo(safePosition);
    _videoPlayerController!.pause();
    
    // UI güncelleme için setState çağır
    setState(() {});
  } catch (e) {
    debugPrint('Kare arama hatası: $e');
  }
}

void _seekOneFrameForward() {
  if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) return;
  
  try {
    // Mevcut pozisyon ve frame süresi hesaplama
    final currentPosition = _videoPlayerController!.value.position;
    final frameTime = Duration(microseconds: (1000000 / _fps).round());
    
    // Yeni pozisyon hesaplama ve atlama - daha hassas
    final newPosition = currentPosition + frameTime;
    
    // Sadece arama fonksiyonunu çağır - ekstra işlemler yapma
    _videoPlayerController!.seekTo(newPosition);
    _videoPlayerController!.pause();
    
    // UI güncelleme için setState çağır
    setState(() {});
  } catch (e) {
    debugPrint('Kare arama hatası: $e');
  }
}

Widget _buildInlineVideoControl({
  required IconData icon, 
  required String label, 
  required VoidCallback onPressed
}) {
  return InkWell(
    onTap: onPressed,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(40),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}


Widget _buildCompactFrameSelector({
  required String label,
  required int? frameNumber,
  required IconData icon,
  required Color color,
  required VoidCallback? onPressed,
}) {
  return Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              frameNumber != null ? 'Kare: $frameNumber' : 'Seçilmedi',
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    ),
  );
}

    Widget _buildLiveStatus() {
  return Container(
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF2F8),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF3498DB), width: 2),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatusIndicator(
          'Durum',
          _zemindeMi ? 'Zeminde' : 'Havada',
          _zemindeMi ? Icons.arrow_downward : Icons.arrow_upward,
          _zemindeMi ? const Color(0xFF27AE60) : const Color(0xFFE74C3C),
        ),
        _buildStatusIndicator(
          'Sıçrama',
          '$_sicramaSayisi',
          Icons.fitness_center,
          const Color(0xFF3498DB),
        ),
        if (_jumpType == OlcumTuru.rj && _rjBaslamaZamani != null)
          _buildStatusIndicator(
            'Süre',
            '${DateTime.now().difference(_rjBaslamaZamani!).inSeconds}s',
            Icons.timer,
            const Color(0xFFF39C12),
          ),
      ],
    ),
  );
}

Widget _buildStatusIndicator(String label, String value, IconData icon, Color color) {
  return Column(
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withAlpha(64), // 0.25 * 255 ≈ 64
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color),
      ),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
    ],
  );
}

  Widget _buildSensorIndicators() {
    return Container(
      height: 60,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (context, i) {
          final isActive = i < _sensorValues.length && _sensorValues[i] < _threshold;
          return Container(
            width: 60,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFE74C3C) : const Color(0xFFECF0F1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'S${i + 1}',
                  style: TextStyle(
                    color: isActive ? Colors.white : const Color(0xFF2C3E50),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  i < _displaySensorValues.length ? '${_displaySensorValues[i].toInt()}' : '8190',
                  style: TextStyle(
                    color: isActive ? Colors.white : const Color(0xFF2C3E50),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_useVideoMode) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [

            Expanded(
              child: ElevatedButton.icon(
                onPressed: (_isRecording || _isAnalyzing) ? null : _startVideoRecording,
                icon: const Icon(Icons.videocam),
                label: const Text('Başlat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27AE60),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isRecording ? _stopVideoRecording : null,
                icon: const Icon(Icons.stop),
                label: const Text('Durdur'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE74C3C),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _clearMeasurement,
                icon: const Icon(Icons.refresh),
                label: const Text('Temizle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF39C12),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _saveMeasurements,
                icon: const Icon(Icons.save),
                label: const Text('Kaydet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3498DB),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _islemBasladi ? null : () {
                if (!_isConnected) {
                  _showSnackBar('Lütfen önce sensör bağlantısını kurun');
                  return;
                }
                _startMeasurement();
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Başlat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF27AE60),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: !_islemBasladi ? null : _stopMeasurement,
              icon: const Icon(Icons.stop),
              label: const Text('Durdur'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE74C3C),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _clearMeasurement,
              icon: const Icon(Icons.refresh),
              label: const Text('Temizle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF39C12),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _saveMeasurements,
              icon: const Icon(Icons.save),
              label: const Text('Kaydet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3498DB),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
// _JumpScreenState sınıfında pozisyon takip değişkeni
Duration _oldVideoPosition = Duration.zero;

void _addVideoPositionListener() {
  if (_videoPlayerController == null) return;
  
  _videoPlayerController!.addListener(() {
    // Yalnızca oynatma durumu veya pozisyon değiştiğinde UI güncelleyin
    if (_videoPlayerController!.value.isPlaying || _oldVideoPosition != _videoPlayerController!.value.position) {
      _oldVideoPosition = _videoPlayerController!.value.position;
      
      // Performans için sadece belirli aralıklarla güncelle (her 4 karede bir)
      final frameCount = (_videoPlayerController!.value.position.inMilliseconds * _fps / 1000).round();
      if (frameCount % 4 == 0) {
        if (mounted) setState(() {});
      }
    }
  });
}
  void _showSnackBar(String message, [Color? color]) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color ?? const Color(0xFF2C3E50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}
