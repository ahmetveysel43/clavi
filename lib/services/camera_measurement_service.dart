import 'dart:async';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math' as math;

/// Sıçrama ölçüm sonucu sınıfı
class JumpMeasurementResult {
  /// Uçuş süresi (saniye)
  final double flightTime;
  
  /// Sıçrama yüksekliği (cm)
  final double jumpHeight;
  
  /// Temas süresi (saniye) - opsiyonel, sadece tekrarlı sıçramalarda
  final double contactTime;
  
  /// Ölçüm zamanı
  final DateTime timestamp;
  
  /// Zemin durumu (true: zeminde, false: havada, null: belirsiz)
  final bool? isOnGround;
  
  JumpMeasurementResult({
    required this.flightTime,
    required this.jumpHeight,
    this.contactTime = 0.0,
    required this.timestamp,
    this.isOnGround,
  });
}

/// Sıçrama tespit fazları
enum JumpDetectionPhase {
  waitingForStart,
  takeoff,
  flight,
  landing,
  contact,
}

/// Kamera tabanlı sıçrama ölçüm servisi
class CameraMeasurementService {
  /// Kamera kontrol değişkenleri
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _isProcessingFrame = false;
  bool _isCalibrating = false;
  bool _isMeasuring = false;
  bool _isCalibrated = false;
  
  /// Ölçüm parametreleri
  JumpDetectionPhase _currentPhase = JumpDetectionPhase.waitingForStart;
  String _jumpTypeStr = 'CMJ';
  double _motionThreshold = 25.0;
  double _calibrationFactor = 1.0;
  double _targetCalibrationHeight = 0.0;
  bool _isOnGround = true;
  int _frameSkipCounter = 0;
  final int _frameSkipThreshold = 2;  // Her X kareden birini işle (performans için)
  
  /// Hareket ve algılama için arka plan referansları
  List<ui.Color> _backgroundReference = [];
  List<List<double>> _motionHistory = [];
  final int _motionHistorySize = 10;
  
  /// Ölçüm zamanlamaları
  DateTime? _takeoffTime;
  DateTime? _landingTime;
  Duration _lastFlightTime = Duration.zero;
  Duration _lastContactTime = Duration.zero;
  
  /// Filtre parametreleri
  List<double> _lastJumpHeights = [];
  final double _movingAverageAlpha = 0.2;  // Üstel hareketli ortalama katsayısı
  
  /// Ölçüm sonuçları ve Stream controller
  final StreamController<JumpMeasurementResult> _resultStreamController = 
      StreamController<JumpMeasurementResult>.broadcast();
  
  /// Kalibrasyon tamamlandığında tetiklenecek Completer
  Completer<double>? _calibrationCompleter;
  
  /// Dışarıdan erişim için özellikler
  Stream<JumpMeasurementResult> get jumpMeasurements => _resultStreamController.stream;
  Future<double> get calibrationComplete => _calibrationCompleter?.future ?? Future.value(1.0);
  bool get isInitialized => _isInitialized;
  bool get isCalibrated => _isCalibrated;
  CameraController? get cameraController => _cameraController;
  
  /// Eşik değeri ayarlama
  double get motionThreshold => _motionThreshold;
  set motionThreshold(double value) {
    if (value >= 5.0 && value <= 100.0) {
      _motionThreshold = value;
    }
  }
  
  /// Kamera servisini başlat
  Future<bool> initialize() async {
    // İzinleri kontrol et
    if (!await _checkPermissions()) {
      debugPrint('Kamera izni reddedildi');
      return false;
    }
    
    try {
      // Kamera listesini al
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('Kullanılabilir kamera bulunamadı');
        return false;
      }
      
      // Arka kamera seç
      final rearCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      
      // Mevcut kontrolör varsa kapat
      await _disposeController();
      
      // Yeni kontrolör oluştur ve başlat
      _cameraController = CameraController(
        rearCamera,
        ResolutionPreset.medium,  // Performans dengesi için medium
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      
      await _cameraController!.initialize();
      
      // Kamera ayarlarını optimize et
      await _optimizeCameraSettings();
      
      _isInitialized = true;
      debugPrint('Kamera başarıyla başlatıldı: ${rearCamera.name}');
      return true;
    } catch (e) {
      debugPrint('Kamera başlatma hatası: $e');
      _isInitialized = false;
      return false;
    }
  }
  
  /// Kamera ayarlarını optimize et
  Future<void> _optimizeCameraSettings() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    
    try {
      // Otomatik pozlama modu
      await _cameraController!.setExposureMode(ExposureMode.auto);
      
      // Otomatik odaklama modu
      if (_cameraController!.value.exposurePointSupported) {
        await _cameraController!.setFocusMode(FocusMode.auto);
      }
      
      // FPS ayarı (varsa)
      // Bazı cihazlarda desteklenmiyor olabilir
      try {
        // Sıçrama ölçümleri için yüksek FPS daha iyi
        await _cameraController!.setFocusMode(FocusMode.auto);
      } catch (e) {
        debugPrint('FPS ayarı yapılamadı: $e');
      }
    } catch (e) {
      debugPrint('Kamera ayarları optimize edilirken hata: $e');
    }
  }
  
  /// Kamera izinlerini kontrol et
  Future<bool> _checkPermissions() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }
  
  /// Kalibrasyon modunu başlat
  void startCalibration(double targetHeight) {
    if (!_isInitialized || _isMeasuring) {
      debugPrint('Kalibrasyon başlatılamadı: Kamera hazır değil veya ölçüm devam ediyor');
      return;
    }
    
    _targetCalibrationHeight = targetHeight;
    _isCalibrating = true;
    _calibrationCompleter = Completer<double>();
    
    // Arka plan referansını temizle
    _backgroundReference = [];
    
    // Görüntü stream'ini başlat
    _startImageStream((image) => _processCalibrateImage(image));
    
    // 20 saniye sonra kalibrasyon zaman aşımı
    Future.delayed(const Duration(seconds: 20), () {
      if (_isCalibrating && !(_calibrationCompleter?.isCompleted ?? false)) {
        _calibrationCompleter?.completeError('Kalibrasyon zaman aşımı');
        _isCalibrating = false;
        _stopImageStream();
      }
    });
  }
  
  /// Kalibre görüntüsünü işle
  void _processCalibrateImage(CameraImage image) {
    if (!_isCalibrating) return;
    
    if (_backgroundReference.isEmpty) {
      // İlk önce arka plan referansını oluştur
      _captureBackgroundReference(image);
      return;
    }
    
    // Kare işlemeyi engelle ve atla
    if (_isProcessingFrame) return;
    _isProcessingFrame = true;
    
    try {
      // Hareket analizi yap
      final motionScore = _analyzeMotion(image);
      
      // Eğer büyük bir hareket algılandıysa (sıçrama başlangıcı)
      if (motionScore > _motionThreshold * 1.2) {
        // Zemin durumunu değiştir - havaya çıkış (takeoff)
        _isOnGround = false;
        _takeoffTime = DateTime.now();
        
        // Ardından iniş için bekle
        Timer(const Duration(milliseconds: 100), () {
          _waitForLanding(image);
        });
      }
    } catch (e) {
      debugPrint('Kalibrasyon görüntüsü işleme hatası: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }
  
  /// İniş anını bekle (kalibrasyon için)
  void _waitForLanding(CameraImage image) {
    if (!_isCalibrating || _isOnGround) return;
    
    // Hareket analizi yap
    final motionScore = _analyzeMotion(image);
    
    // Eğer hareket durdu ve kişi indi olduğunu algıla
    if (motionScore < _motionThreshold * 0.5) {
      _isOnGround = true;
      _landingTime = DateTime.now();
      
      // Uçuş süresini hesapla
      if (_takeoffTime != null && _landingTime != null) {
        _lastFlightTime = _landingTime!.difference(_takeoffTime!);
        
        // Sıçrama yüksekliği hesapla (santimetre)
        final flightTimeSeconds = _lastFlightTime.inMicroseconds / 1000000.0;
        final rawJumpHeight = _calculateJumpHeight(flightTimeSeconds);
        
        // Kalibrasyon faktörünü hesapla
        _calibrationFactor = _targetCalibrationHeight / rawJumpHeight;
        _isCalibrated = true;
        
        debugPrint('Kalibrasyon tamamlandı: Ham Yükseklik: $rawJumpHeight cm, '
                  'Hedef Yükseklik: $_targetCalibrationHeight cm, '
                  'Faktör: $_calibrationFactor');
        
        // Kalibrasyonu tamamla
        _calibrationCompleter?.complete(_calibrationFactor);
        _isCalibrating = false;
        _stopImageStream();
      }
    } else {
      // Hala havada, tekrar kontrol et
      Timer(const Duration(milliseconds: 30), () {
        _waitForLanding(image);
      });
    }
  }
  
  /// Ölçüm modunu başlat
  void startMeasurement(String jumpType) {
    if (!_isInitialized) {
      debugPrint('Ölçüm başlatılamadı: Kamera hazır değil');
      return;
    }
    
    // Arka plan referansı yoksa oluştur
    if (_backgroundReference.isEmpty) {
      _isCalibrated = false;
    }
    
    _jumpTypeStr = jumpType.toString();
    _isMeasuring = true;
    _currentPhase = JumpDetectionPhase.waitingForStart;
    _isOnGround = true;
    _takeoffTime = null;
    _landingTime = null;
    _lastFlightTime = Duration.zero;
    _lastContactTime = Duration.zero;
    _lastJumpHeights = [];
    
    // Görüntü stream'ini başlat
    _startImageStream((image) => _processMeasurementImage(image));
  }
  
  /// Ölçüm görüntüsünü işle
  void _processMeasurementImage(CameraImage image) {
    if (!_isMeasuring) return;
    
    // Kare atlama (her X kareden birini işle - performans için)
    _frameSkipCounter++;
    if (_frameSkipCounter < _frameSkipThreshold) {
      return;
    }
    _frameSkipCounter = 0;
    
    // İşlem zaten devam ediyorsa atla
    if (_isProcessingFrame) return;
    _isProcessingFrame = true;
    
    try {
      // İlk çalıştırmada arka plan referansı yoksa oluştur
      if (_backgroundReference.isEmpty) {
        _captureBackgroundReference(image);
        _isProcessingFrame = false;
        return;
      }
      
      // Hareketi analiz et
      final motionScore = _analyzeMotion(image);
      _updateMotionHistory(motionScore);
      
      // Mevcut faza göre işle
      switch (_currentPhase) {
        case JumpDetectionPhase.waitingForStart:
          if (motionScore > _motionThreshold * 1.5 || _detectTakeoffPattern()) {
            _currentPhase = JumpDetectionPhase.takeoff;
            _isOnGround = false;
            _takeoffTime = DateTime.now();
            
            debugPrint('Sıçrama başlangıcı tespit edildi: ${_takeoffTime!.millisecondsSinceEpoch}');
            
            // Temas süresi hesapla (önceki inişten bu yana)
            if (_landingTime != null) {
              _lastContactTime = _takeoffTime!.difference(_landingTime!);
              debugPrint('Temas süresi: ${_lastContactTime.inMilliseconds}ms');
            }
          }
          break;
          
        case JumpDetectionPhase.takeoff:
        case JumpDetectionPhase.flight:
          // Havadayken motor stabilizasyonu algıla
          _currentPhase = JumpDetectionPhase.flight;
          
          // İniş algılama - motion score düşer veya iniş paterni algılanır
          if (motionScore < _motionThreshold * 0.6 || _detectLandingPattern()) {
            _currentPhase = JumpDetectionPhase.landing;
            _isOnGround = true;
            _landingTime = DateTime.now();
            
            // Uçuş süresini hesapla
            if (_takeoffTime != null) {
              _lastFlightTime = _landingTime!.difference(_takeoffTime!);
              
              // Uçuş süresi geçerliliğini kontrol et
              if (_isValidFlightTime(_lastFlightTime)) {
                // Sıçrama yüksekliği hesapla (santimetre)
                final flightTimeSeconds = _lastFlightTime.inMicroseconds / 1000000.0;
                double jumpHeight = _calculateJumpHeight(flightTimeSeconds);
                
                // Kalibrasyon düzeltmesi uygula
                if (_isCalibrated) {
                  jumpHeight *= _calibrationFactor;
                }
                
                // Üstel hareketli ortalama ile gürültü azaltma
                jumpHeight = _applyExponentialMovingAverage(jumpHeight);
                
                debugPrint('Geçerli sıçrama tespit edildi: '
                           'Uçuş süresi: ${flightTimeSeconds.toStringAsFixed(3)}s, '
                           'Yükseklik: ${jumpHeight.toStringAsFixed(1)}cm');
                
                // Ölçüm sonucunu oluştur
                final result = JumpMeasurementResult(
                  flightTime: flightTimeSeconds,
                  jumpHeight: jumpHeight,
                  contactTime: _lastContactTime.inMicroseconds / 1000000.0,
                  timestamp: DateTime.now(),
                  isOnGround: _isOnGround,
                );
                
                // Sonucu ilet
                _resultStreamController.add(result);
              } else {
                debugPrint('Geçersiz uçuş süresi: ${_lastFlightTime.inMilliseconds}ms');
              }
            }
            
            // Tekrarlı sıçrama ise, bir sonraki sıçrama için bekle
            if (_jumpTypeStr.toUpperCase() == 'RJ') {
              _currentPhase = JumpDetectionPhase.contact;
            } else {
              // Tek sıçrama ise ölçümü tamamla
              _currentPhase = JumpDetectionPhase.waitingForStart;
            }
          }
          break;
          
        case JumpDetectionPhase.landing:
        case JumpDetectionPhase.contact:
          // Zemindeyken yeni sıçrama bekleniyor
          // Tekrarlı sıçrama ise, yeni sıçrama için hemen hazırlık yap
          if (_jumpTypeStr.toUpperCase() == 'RJ') {
            if (motionScore > _motionThreshold * 1.2 || _detectTakeoffPattern()) {
              _currentPhase = JumpDetectionPhase.takeoff;
              _isOnGround = false;
              _takeoffTime = DateTime.now();
              
              // Temas süresi hesapla
              if (_landingTime != null) {
                _lastContactTime = _takeoffTime!.difference(_landingTime!);
              }
            }
          } else {
            _currentPhase = JumpDetectionPhase.waitingForStart;
          }
          break;
      }
    } catch (e) {
      debugPrint('Ölçüm görüntüsü işleme hatası: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }
  
  /// Arka plan referansını yakala
  void _captureBackgroundReference(CameraImage image) {
    final luminanceValues = <int>[];
    
    // Sadece Y kanalını kullan (YUV formatında)
    final yPlane = image.planes[0];
    final yBuffer = yPlane.bytes;
    final pixelStride = yPlane.bytesPerPixel ?? 1;
    final rowStride = yPlane.bytesPerRow;
    
    // Grid örnekleme yap (her 20 pikselde bir örnek al)
    final stepX = image.width ~/ 10;
    final stepY = image.height ~/ 10;
    
    for (int y = 0; y < image.height; y += stepY) {
      for (int x = 0; x < image.width; x += stepX) {
        final pixelIndex = y * rowStride + x * pixelStride;
        if (pixelIndex < yBuffer.length) {
          luminanceValues.add(yBuffer[pixelIndex]);
        }
      }
    }
    
    // Renk değerleri oluştur
    _backgroundReference = luminanceValues.map((lum) => 
        Color.fromARGB(255, lum, lum, lum)).toList();
    
    debugPrint('Arka plan referansı oluşturuldu: ${_backgroundReference.length} örnek');
  }
  
  /// Görüntüden hareket skorunu hesapla
  double _analyzeMotion(CameraImage image) {
    if (_backgroundReference.isEmpty) return 0.0;
    
    double totalDifference = 0.0;
    int sampleCount = 0;
    
    // Y kanalını kullan (YUV formatında)
    final yPlane = image.planes[0];
    final yBuffer = yPlane.bytes;
    final pixelStride = yPlane.bytesPerPixel ?? 1;
    final rowStride = yPlane.bytesPerRow;
    
    // Görüntünün alt kısmına odaklan (koşucunun / sıçrayan kişinin olduğu yer)
    final startY = image.height ~/ 2;
    final stepX = image.width ~/ 10;
    final stepY = (image.height - startY) ~/ 10;
    
    for (int y = startY; y < image.height; y += stepY) {
      for (int x = 0; x < image.width; x += stepX) {
        final pixelIndex = y * rowStride + x * pixelStride;
        
        if (pixelIndex < yBuffer.length) {
          final currentLum = yBuffer[pixelIndex];
          
          // Referans ile mevcut pikseli karşılaştır
          final refIndex = sampleCount % _backgroundReference.length;
          final refColor = _backgroundReference[refIndex];
          final refLum = refColor.r;  // grayscale değeri (deprecated red yerine r kullan)
          
          // Farkı hesapla ve normalize et
          final difference = (currentLum - refLum).abs() / 255.0;
          totalDifference += difference;
          sampleCount++;
        }
      }
    }
    
    // Ortalama farkı hesapla ve yüzde olarak döndür
    return sampleCount > 0 ? (totalDifference / sampleCount) * 100.0 : 0.0;
  }
  
  /// Hareket geçmişini güncelle
  void _updateMotionHistory(double motionScore) {
    // İlk çalıştırmada diziyi oluştur
    if (_motionHistory.isEmpty) {
      _motionHistory = List.generate(_motionHistorySize, (_) => [0.0, 0.0]);
    }
    
    // Yeni değeri ekle ve en eskiyi çıkar
    _motionHistory.removeAt(0);
    _motionHistory.add([DateTime.now().millisecondsSinceEpoch.toDouble(), motionScore]);
  }
  
  /// Hareketten sıçrama başlangıcı paternini algıla
  bool _detectTakeoffPattern() {
    if (_motionHistory.length < 5) return false;
    
    // Son 5 örneğin eğilimini analiz et
    // Yukarı doğru keskin bir artış sıçrama başlangıcını gösterir
    
    final recentValues = _motionHistory.sublist(_motionHistory.length - 5)
        .map((e) => e[1]).toList();
    
    double sum = 0;
    for (int i = 1; i < recentValues.length; i++) {
      sum += recentValues[i] - recentValues[i-1];
    }
    
    // Pozitif eğilim (artış) sıçrama başlangıcını gösterir
    return sum > _motionThreshold * 0.8;
  }
  
  /// İniş paternini algıla
  bool _detectLandingPattern() {
    if (_motionHistory.length < 5) return false;
    
    // Son 5 örneğin eğilimini analiz et
    // Aşağı doğru keskin bir düşüş inişi gösterir
    
    final recentValues = _motionHistory.sublist(_motionHistory.length - 5)
        .map((e) => e[1]).toList();
    
    double sum = 0;
    for (int i = 1; i < recentValues.length; i++) {
      sum += recentValues[i] - recentValues[i-1];
    }
    
    // Negatif eğilim (düşüş) inişi gösterir
    return sum < -_motionThreshold * 0.8;
  }
  
  /// Kamera görüntü stream'i başlat
  void _startImageStream(Function(CameraImage image) onImage) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    
    try {
      // Eğer zaten stream başlatılmışsa durdur
      if (_cameraController!.value.isStreamingImages) {
        _cameraController!.stopImageStream();
      }
      
      // Yeni stream başlat
      _cameraController!.startImageStream(onImage);
      debugPrint('Kamera görüntü stream\'i başlatıldı');
    } catch (e) {
      debugPrint('Kamera stream hatası: $e');
    }
  }
  
  /// Kamera görüntü stream'i durdur
  void _stopImageStream() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    
    try {
      if (_cameraController!.value.isStreamingImages) {
        _cameraController!.stopImageStream();
        debugPrint('Kamera görüntü stream\'i durduruldu');
      }
    } catch (e) {
      debugPrint('Kamera stream durdurma hatası: $e');
    }
  }
  
  /// Bilimsel sıçrama yüksekliği hesaplama
  double _calculateJumpHeight(double flightTime) {
    // Sıçrama yüksekliği formülü: h = g * t^2 / 8
    // g = 9.81 m/s² (yerçekimi ivmesi)
    // t = uçuş süresi (saniye)
    // h = yükseklik (metre)
    // 100 ile çarpılarak cm'ye dönüştürülür
    
    return 122.625 * math.pow(flightTime, 2);
  }
  
  /// Uçuş süresinin geçerli olup olmadığını kontrol et
  bool _isValidFlightTime(Duration flightTime) {
    final ms = flightTime.inMilliseconds;
    
    // Çok kısa süreler muhtemelen gürültü/hatalı algılama
    if (ms < 150) return false;
    
    // Çok uzun süreler muhtemelen hatalı algılama (1.5 saniyeden uzunsa)
    if (ms > 1500) return false;
    
    return true;
  }
  
  /// Üstel hareketli ortalama filtresi ile gürültü azaltma
  double _applyExponentialMovingAverage(double newValue) {
    // Eğer ilk değerse veya değer çok büyük/küçükse filtreleme yapma
    if (_lastJumpHeights.isEmpty) {
      _lastJumpHeights.add(newValue);
      return newValue;
    }
    
    // Son ölçüm ile karşılaştır
    final lastValue = _lastJumpHeights.last;
    
    // Eğer çok büyük bir fark varsa aykırı değer olarak kabul et
    if ((newValue > lastValue * 1.5) || (newValue < lastValue * 0.5)) {
      // Aykırı değer algılaması
      debugPrint('Aykırı değer algılandı: $newValue cm (son: $lastValue cm)');
      
      // Eğer makul bir aralıktaysa hala kaydet (aykırı değeri reddetme)
      if (newValue > 3.0 && newValue < 80.0) {
        _lastJumpHeights.add(newValue);
        if (_lastJumpHeights.length > 5) {
          _lastJumpHeights.removeAt(0);
        }
      }
      
      return lastValue;  // Aykırı değeri reddet
    }
    
    // Üstel hareketli ortalama hesapla: EMA = alpha * newValue + (1 - alpha) * lastEMA
    final filteredValue = _movingAverageAlpha * newValue + (1 - _movingAverageAlpha) * lastValue;
    
    // Filtrelenmiş değeri kaydet
    _lastJumpHeights.add(filteredValue);
    if (_lastJumpHeights.length > 5) {
      _lastJumpHeights.removeAt(0);
    }
    
    return filteredValue;
  }
  
  /// Ölçümü durdur
  void stopMeasurement() {
    _isMeasuring = false;
    _isCalibrating = false;
    _stopImageStream();
  }
  
  /// Kamera kontrolörünü serbest bırak
  Future<void> _disposeController() async {
    if (_cameraController != null) {
      try {
        // Görüntü stream'ini durdur
        if (_cameraController!.value.isInitialized && 
            _cameraController!.value.isStreamingImages) {
          await _cameraController!.stopImageStream();
        }
        
        // Kontrolörü serbest bırak
        await _cameraController!.dispose();
        _cameraController = null;
      } catch (e) {
        debugPrint('Kamera kontrolörü serbest bırakılırken hata: $e');
      }
    }
  }
  
  /// Servisi kapat
  Future<void> dispose() async {
    _isMeasuring = false;
    _isCalibrating = false;
    
    await _disposeController();
    
    // Stream controller'ı kapat
    if (!_resultStreamController.isClosed) {
      await _resultStreamController.close();
    }
    
    _isInitialized = false;
  }
}