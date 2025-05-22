import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../models/sporcu_model.dart';
import '../models/olcum_model.dart';
import '../services/database_service.dart';
import '../services/bluetooth_connection_service.dart';

class SprintScreen extends StatefulWidget {
  final int? sporcuId;
  const SprintScreen({super.key, this.sporcuId});

  @override
  State<SprintScreen> createState() => _SprintScreenState();
}

class _SprintScreenState extends State<SprintScreen> {
  final _dbService = DatabaseService();
  final _btService = BluetoothConnectionService.instance;
  bool _isLoading = true;
  bool _isConnected = false;
  Sporcu? _sporcu;
  int _threshold = 500;
  List<double> _sensorValues = List.filled(7, 0.0);
  List<double> _displaySensorValues = List.filled(7, 8190.0);
  StreamSubscription<String>? _btSubscription;
  int _secilenOlcumNo = 1;
  final _olcumVerileri = List.generate(
    3,
    (_) => <String, double?>{'kapi1': null, 'kapi2': null, 'kapi3': null, 'kapi4': null, 'kapi5': null, 'kapi6': null, 'kapi7': null},
  );
  Timer? _timer;
  bool _islemBasladi = false;
  bool _isStartButtonPressed = false;
  DateTime? _kalkisZamani;
  int _triggerCount = 0;
  final _lastTriggers = List.generate(7, (_) => DateTime(2000));
  final _debounceDelay = const Duration(milliseconds: 800);
  final _sensorStates = List.generate(7, (_) => false);
  bool _showSensors = false;
  
  // Kamera tabanlı ölçüm değişkenleri
  bool _useCameraMode = false;
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isProcessingFrame = false;
  
  // Motion detection için değişkenler
  bool _isCalibrating = false;
  bool _isCalibrated = false;
  List<Color> _backgroundReference = [];
  double _motionThreshold = 40.0;
  
  // Sprint alanında oluşturulan sanal kapılar
  final List<Rect> _gates = [];
  final List<DateTime?> _gateTriggerTimes = List.filled(7, null);
  final List<bool> _gateTriggered = List.filled(7, false);
  
  // Kullanıcı ayarları
  double _distanceBetweenGates = 5.0; // metre
  final _distanceController = TextEditingController(text: "5.0");
  final _gateCountController = TextEditingController(text: "5");
  int _gateCount = 5;
  
  @override
  void initState() {
    super.initState();
    _loadData();
    _setupBluetooth();
    _initializeCamera();
  }

  Future<void> _loadData() async {
    try {
      if (widget.sporcuId != null) {
        _sporcu = await _dbService.getSporcu(widget.sporcuId!);
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
  
  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        _showSnackBar('Kamera bulunamadı');
        return;
      }
    } catch (e) {
      _showSnackBar('Kamera başlatma hatası: $e');
    }
  }
  
  Future<void> _startCameraPreview() async {
    if (_cameras == null || _cameras!.isEmpty) {
      await _initializeCamera();
      if (_cameras == null || _cameras!.isEmpty) return;
    }
    
    // Mevcut kamera kontrolörünü kapat
    if (_cameraController != null) {
      try {
        if (_cameraController!.value.isInitialized) {
          if (_cameraController!.value.isStreamingImages) {
            await _cameraController!.stopImageStream();
          }
          await _cameraController!.dispose();
        }
      } catch (e) {
        debugPrint('Kamera kapatılırken hata: $e');
      }
    }
    
    // Arka kamerayı tercih et
    final camera = _cameras!.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras!.first,
    );
    
    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium, // Performans için medium kullanabilirsiniz
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    
    try {
      await _cameraController!.initialize();
      
      // Otomatik pozlama modu ayarla
      await _cameraController!.setExposureMode(ExposureMode.auto);
      
      setState(() {
        _isCameraInitialized = true;
        _isCalibrated = false;
        _gates.clear();
        _gateTriggered.fillRange(0, _gateTriggered.length, false);
        _gateTriggerTimes.fillRange(0, _gateTriggerTimes.length, null);
      });
    } catch (e) {
      _showSnackBar('Kamera başlatılamadı: $e');
      _isCameraInitialized = false;
    }
  }
  
  void _createVirtualGates() {
    if (!_isCameraInitialized || _cameraController == null) return;
    
    // Kamera önizleme alanının boyutları
    final width = _cameraController!.value.previewSize?.width ?? 640;
    final height = _cameraController!.value.previewSize?.height ?? 480;
    
    // Gate sayısını güncelle
    try {
      _gateCount = int.parse(_gateCountController.text);
      if (_gateCount < 2) _gateCount = 2;
      if (_gateCount > 7) _gateCount = 7;
    } catch (e) {
      _gateCount = 5;
    }
    
    // Gate'ler arasındaki mesafeyi güncelle
    try {
      _distanceBetweenGates = double.parse(_distanceController.text);
      if (_distanceBetweenGates <= 0) _distanceBetweenGates = 5.0;
    } catch (e) {
      _distanceBetweenGates = 5.0;
    }
    
    // Gate'leri oluştur
    _gates.clear();
    
    // Dikey kapılar için hesaplama
    final gateWidth = width * 0.1; // Kapı genişliği
    final gateSpacing = width / (_gateCount + 1); // Kapılar arası eşit mesafe
    
    for (int i = 0; i < _gateCount; i++) {
      final gateX = gateSpacing * (i + 1) - (gateWidth / 2);
      final gateRect = Rect.fromLTWH(
        gateX, 
        height * 0.1, // Üstten biraz boşluk
        gateWidth,
        height * 0.8, // Kapı yüksekliği
      );
      _gates.add(gateRect);
    }
    
    // Gate durum listelerini sıfırla
    _gateTriggered.fillRange(0, _gateTriggered.length, false);
    _gateTriggerTimes.fillRange(0, _gateTriggerTimes.length, null);
    
    setState(() {});
  }
  
  void _startCameraCalibration() {
    if (!_isCameraInitialized || _cameraController == null) {
      _showSnackBar('Kamera hazır değil');
      return;
    }
    
    setState(() {
      _isCalibrating = true;
      _isCalibrated = false;
      _backgroundReference.clear();
    });
    
    try {
      if (!_cameraController!.value.isStreamingImages) {
        _cameraController!.startImageStream(_processCalibrateImage);
      }
      
      _showSnackBar('Arka plan kalibrasyonu yapılıyor...');
      
      // 3 saniye sonra kalibrasyon tamamlansın
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isCalibrating) {
          setState(() {
            _isCalibrating = false;
            _isCalibrated = _backgroundReference.isNotEmpty;
          });
          
          if (_cameraController!.value.isStreamingImages) {
            _cameraController!.stopImageStream();
          }
          
          if (_isCalibrated) {
            _createVirtualGates();
            _showSnackBar('Kalibrasyon tamamlandı! Sprint kapıları oluşturuldu.');
          } else {
            _showSnackBar('Kalibrasyon başarısız oldu. Tekrar deneyin.');
          }
        }
      });
    } catch (e) {
      _showSnackBar('Kalibrasyon başlatılamadı: $e');
      _isCalibrating = false;
    }
  }
  
  void _processCalibrateImage(CameraImage image) {
    if (!_isCalibrating) return;
    
    // İlk kalibrasyon karesi için geri dön eğer zaten referans varsa
    if (_backgroundReference.isNotEmpty) return;
    
    try {
      // Görüntüden basit renk verileri çıkar
      final bytes = image.planes[0].bytes;
      final width = image.width;
      final height = image.height;
      
      // Görüntüyü 10x10 grid şeklinde örnekle
      List<Color> backgroundColors = [];
      final gridSize = 10;
      
      for (int y = 0; y < height; y += height ~/ gridSize) {
        for (int x = 0; x < width; x += width ~/ gridSize) {
          final index = y * width + x;
          if (index < bytes.length) {
            // YUV formatında Y kanalı (parlaklık)
            backgroundColors.add(Color.fromARGB(255, bytes[index], bytes[index], bytes[index]));
          }
        }
      }
      
      setState(() {
        _backgroundReference = backgroundColors;
      });
      
    } catch (e) {
      debugPrint('Kalibrasyon karesi işleme hatası: $e');
    }
  }
  
  void _startCameraDetection() {
    if (!_isCameraInitialized || _cameraController == null) {
      _showSnackBar('Kamera hazır değil');
      return;
    }
    
    if (!_isCalibrated) {
      _showSnackBar('Önce kalibrasyonu tamamlayın');
      return;
    }
    
    setState(() {
      _islemBasladi = true;
      _kalkisZamani = DateTime.now();
      _triggerCount = 0;
      _gateTriggered.fillRange(0, _gateTriggered.length, false);
      _gateTriggerTimes.fillRange(0, _gateTriggerTimes.length, null);
      
      // İlk kapının tetiklenme zamanını kaydet (başlangıç)
      _gateTriggerTimes[0] = _kalkisZamani;
      _gateTriggered[0] = true;
      _triggerCount = 1;
      
      // Ölçüm verilerini güncelle
      _olcumVerileri[_secilenOlcumNo - 1]['kapi1'] = 0.0;
    });
    
    try {
      if (!_cameraController!.value.isStreamingImages) {
        _cameraController!.startImageStream(_processSprintImage);
      }
      
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (mounted) setState(() {});
      });
      
      _showSnackBar('Sprint ölçümü başlatıldı');
    } catch (e) {
      _showSnackBar('Kamera stream başlatılamadı: $e');
      _islemBasladi = false;
    }
  }
  
  void _processSprintImage(CameraImage image) {
    if (_isProcessingFrame || !_islemBasladi) return;
    _isProcessingFrame = true;
    
    final timestamp = DateTime.now();
    
    try {
      // Görüntüden basit renk verileri çıkar
      final bytes = image.planes[0].bytes;
      final width = image.width;
      
      
      // Her kapı için ayrı motion detection yap
      for (int gateIndex = 1; gateIndex < _gates.length; gateIndex++) {
        // Eğer bu kapı zaten tetiklendiyse geç
        if (_gateTriggered[gateIndex]) continue;
        
        final gate = _gates[gateIndex];
        
        // Gate içindeki bölgeyi analiz et
        double gateMotionScore = 0;
        int pixelCount = 0;
        
        // Gate içindeki grid noktalarını örnekle
        for (int y = gate.top.toInt(); y < gate.bottom.toInt(); y += 20) {
          for (int x = gate.left.toInt(); x < gate.right.toInt(); x += 10) {
            final index = y * width + x;
            if (index < bytes.length) {
              // Piksel değerini al
              final pixelValue = bytes[index];
              
              // Referans ile farkını hesapla (basit yaklaşım)
              final refIndex = (pixelCount % _backgroundReference.length);
              final refColor = _backgroundReference[refIndex];
              
              final diff = (pixelValue - refColor.red).abs();
              gateMotionScore += diff / 255.0;
              pixelCount++;
            }
          }
        }
        
        // Normalize et
        if (pixelCount > 0) {
          gateMotionScore = (gateMotionScore / pixelCount) * 100;
          
          // Eşik değeri üzerindeki hareket kapıyı tetikler
          if (gateMotionScore > _motionThreshold) {
            _gateTriggerTimes[gateIndex] = timestamp;
            _gateTriggered[gateIndex] = true;
            _triggerCount++;
            
            // Sprint zamanı hesapla
            final startTime = _gateTriggerTimes[0]!;
            final elapsed = timestamp.difference(startTime).inMilliseconds / 1000.0;
            
            // Ölçüm verilerini güncelle
            setState(() {
              _olcumVerileri[_secilenOlcumNo - 1]['kapi${gateIndex + 1}'] = elapsed;
              
              debugPrint('Kapı ${gateIndex + 1} tetiklendi: ${elapsed.toStringAsFixed(3)}s');
            });
            
            // Tüm kapılar tetiklendiyse ölçümü durdur
            if (_triggerCount >= _gates.length) {
              _stopMeasurement('Sprint ölçümü tamamlandı');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Sprint kare işleme hatası: $e');
    } finally {
      _isProcessingFrame = false;
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

    // Burada _isStartButtonPressed alanını kullan
    if (_islemBasladi && !_useCameraMode || (_isStartButtonPressed && !_islemBasladi)) {
      _processSensorMeasurement();
    }
  } catch (e) {
    debugPrint('Bluetooth veri işleme hatası: $e');
  }
}

 void _processSensorMeasurement() {
  // Herhangi bir sensör tetiklendi mi kontrol et
  for (var i = 0; i < _sensorValues.length; i++) {
    final isBelowThreshold = _sensorValues[i] < _threshold;

    // Sensör tetiklendi mi ve debounce süresi geçti mi?
    if (!_sensorStates[i] && isBelowThreshold && 
        DateTime.now().difference(_lastTriggers[i]) >= _debounceDelay) {
      
      _lastTriggers[i] = DateTime.now();
      _sensorStates[i] = true;
      
      // Eğer kronometreyi henüz başlatmadıysak ve Start butonuna basıldıysa
      if (!_islemBasladi && _isStartButtonPressed) {
        setState(() {
          _islemBasladi = true;
          _kalkisZamani = DateTime.now();
          _triggerCount = 0; // Henüz hiçbir sensör kayıt edilmedi
        });
      }
      
      // Ölçüm başladıysa, sensör tetiklemesini kaydet
      if (_islemBasladi) {
        _triggerCount++;
        
        if (_triggerCount <= 7) { // En fazla 7 kapı kaydedebiliriz
          final elapsed = _kalkisZamani != null ? 
              DateTime.now().difference(_kalkisZamani!).inMilliseconds / 1000.0 : 0.0;
          
          // i+1 yerine _triggerCount kullanarak sensörleri tetiklenme sırasına göre kaydediyoruz
          setState(() => _olcumVerileri[_secilenOlcumNo - 1]['kapi$_triggerCount'] = elapsed);
          
          debugPrint('Kapı $_triggerCount (Sensör ${i+1}) tetiklendi: ${elapsed.toStringAsFixed(3)}s');
        }
        
        if (_triggerCount >= 7) {
          _stopMeasurement('Sprint ölçümü tamamlandı');
        }
      }
    } else if (_sensorStates[i] && !isBelowThreshold) {
      // Sensör normal durumuna döndüğünde state'i güncelle
      _sensorStates[i] = false;
    }
  }
}

  @override
  void dispose() {
    _btSubscription?.cancel();
    _timer?.cancel();
    _btService.disconnect();
    _distanceController.dispose();
    _gateCountController.dispose();
    
    // Kamera kontrolörünü düzgün şekilde kapat
    if (_cameraController != null) {
      try {
        if (_cameraController!.value.isStreamingImages) {
          _cameraController!.stopImageStream();
        }
        _cameraController!.dispose();
      } catch (e) {
        debugPrint('Kamera dispose hatası: $e');
      }
    }
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Sprint Testi', style: TextStyle(fontWeight: FontWeight.bold)),
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
                
                // Ölçüm modu seçimi
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
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
                              Icon(Icons.bluetooth, size: 16),
                              SizedBox(width: 8),
                              Text('Sensör Modu'),
                            ],
                          ),
                          selected: !_useCameraMode,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _useCameraMode = false);
                            }
                          },
                          selectedColor: const Color(0xFF0288D1),
                          labelStyle: TextStyle(
                            color: !_useCameraMode ? Colors.white : Colors.black87,
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
                              Icon(Icons.camera_alt, size: 16),
                              SizedBox(width: 8),
                              Text('Kamera Modu'),
                            ],
                          ),
                          selected: _useCameraMode,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _useCameraMode = true);
                              _startCameraPreview();
                            }
                          },
                          selectedColor: const Color(0xFF0288D1),
                          labelStyle: TextStyle(
                            color: _useCameraMode ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (_useCameraMode)
                          _buildCameraView()
                        else
                          _buildConfigSection(),
                          
                        const SizedBox(height: 16),
                        _buildMeasurementSection(),
                        
                        if (_islemBasladi) 
                          _buildLiveStatus(),
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
                if (!_useCameraMode) // Sadece sensör modunda bağlantı durumu göster
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
          if (_showSensors && !_useCameraMode) _buildSensorIndicators(),
        ],
      ),
    );
  }
  
  Widget _buildCameraView() {
    if (!_isCameraInitialized || _cameraController == null) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Kamera başlatılıyor...',
                style: TextStyle(color: Colors.white),
              )
            ],
          ),
        ),
      );
    }
    
    // Kamera kontrolörü başlatılmış mı kontrol et
    if (!_cameraController!.value.isInitialized) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Text(
            'Kamera hazırlanıyor...',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.grey.withAlpha(25), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sprint Kapıları', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 250,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Kamera önizleme
                  _cameraController!.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: _cameraController!.value.aspectRatio,
                          child: CameraPreview(_cameraController!),
                        )
                      : Container(
                          color: Colors.black,
                          child: const Center(
                            child: Text('Kamera bağlantısı bekleniyor...', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                  
                  // Virtual kapıları çiz
                  if (_gates.isNotEmpty)
                    CustomPaint(
                      size: Size.infinite,
                      painter: GatesPainter(
                        gates: _gates,
                        triggered: _gateTriggered,
                        cameraController: _cameraController!
                      ),
                    ),
                  
                  // Kalibrasyon durumu
                  if (_isCalibrating)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 16),
                            Text(
                              'Kalibrasyon yapılıyor...\nLütfen bekleyin',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Kapı ayarları
          if (!_islemBasladi) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _gateCountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Kapı Sayısı',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.door_front_door),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _distanceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Mesafe (m)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.straighten),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isCalibrating ? null : _startCameraCalibration,
                    icon: const Icon(Icons.camera),
                    label: const Text('Kalibre Et'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9C27B0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Slider(
                    value: _motionThreshold,
                    min: 10,
                    max: 80,
                    divisions: 14,
                    label: 'Hassasiyet: ${_motionThreshold.round()}',
                    onChanged: (value) {
                      setState(() {
                        _motionThreshold = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withAlpha(100)),
              ),
              child: Column(
                children: [
                  const Text(
                    'Kamera Kullanım Talimatları:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Kamera sabit ve sprint yoluna dik olmalı\n'
                    '• "Kalibre Et" butonu ile koşu alanını belirleyin\n'
                    '• Kapı sayısı ve mesafeyi ayarlayın\n'
                    '• Hassasiyet ayarı ile tespit düzeyini değiştirin',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfigSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.grey.withAlpha(25), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ayarlar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _threshold,
            decoration: InputDecoration(
              labelText: 'Eşik Değeri (mm)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.tune),
            ),
            items: List.generate(29, (i) => 100 + i * 50).map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
            onChanged: (value) => setState(() => _threshold = value!),
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
          BoxShadow(color: Colors.grey.withAlpha(25), blurRadius: 10, offset: const Offset(0, 5)),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final isSelected = _secilenOlcumNo == i + 1;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
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
          const SizedBox(height: 20),
          _buildGateResults(),
          
          if (_useCameraMode && _isCalibrated && _gateTriggered.where((triggered) => triggered).length >= 2)
            _buildSpeedCalculation(),
        ],
      ),
    );
  }

  Widget _buildGateResults() {
    final results = _olcumVerileri[_secilenOlcumNo - 1];
    
    // Kapı sayısını belirle
    int maxGates = _useCameraMode ? _gateCount : 7;
    
    return Column(
      children: List.generate(maxGates, (i) {
        final value = results['kapi${i + 1}'];
        final isTriggered = value != null;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isTriggered ? const Color(0xFFEAF2F8) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isTriggered ? const Color(0xFF3498DB) : Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isTriggered ? const Color(0xFF3498DB) : Colors.grey[400],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            title: Text(
              '${i + 1}. Kapı',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isTriggered ? Colors.black : Colors.grey[600],
              ),
            ),
            trailing: Text(
              value?.toStringAsFixed(3) ?? '-',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isTriggered ? const Color(0xFF3498DB) : Colors.grey[400],
              ),
            ),
          ),
        );
      }),
    );
  }
  
  Widget _buildSpeedCalculation() {
    // En az iki kapı tetiklenmişse hız hesapla
    final results = _olcumVerileri[_secilenOlcumNo - 1];
    
    // Tetiklenen kapıların indeksleri
    List<int> triggeredGates = [];
    for (int i = 0; i < _gateCount; i++) {
      if (results['kapi${i + 1}'] != null) {
        triggeredGates.add(i);
      }
    }
    
    if (triggeredGates.length < 2) return const SizedBox.shrink();
    
    // Son iki tetiklenen kapı arasındaki hızı hesapla
    final lastGateIndex = triggeredGates.last;
    final prevGateIndex = triggeredGates[triggeredGates.length - 2];
    
    final lastTime = results['kapi${lastGateIndex + 1}']!;
    final prevTime = results['kapi${prevGateIndex + 1}']!;
    
    final timeDiff = lastTime - prevTime; // saniye
    if (timeDiff <= 0) return const SizedBox.shrink();
    
    // Mesafe hesapla (kapı sayısı * mesafe / (kapı sayısı-1))
    final distance = _distanceBetweenGates * (lastGateIndex - prevGateIndex);
    final speed = distance / timeDiff; // m/s
    
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8BC34A)),
      ),
      child: Column(
        children: [
          const Text(
            'Hız Hesaplaması',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF689F38)),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSpeedCard('Mesafe', '$distance m', Icons.straighten),
              _buildSpeedCard('Süre', '${timeDiff.toStringAsFixed(3)} s', Icons.timer),
              _buildSpeedCard('Hız', '${speed.toStringAsFixed(2)} m/s', Icons.speed),
              _buildSpeedCard('Hız', '${(speed * 3.6).toStringAsFixed(2)} km/h', Icons.directions_run),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildSpeedCard(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF689F38)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

Widget _buildLiveStatus() {
  // Eğer ölçüm başlamadıysa veya kalkış zamanı henüz yoksa "0.00s" göster
  final elapsedTime = (_islemBasladi && _kalkisZamani != null)
    ? '${(DateTime.now().difference(_kalkisZamani!).inMilliseconds / 1000).toStringAsFixed(2)}s'
    : '0.00s';

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
          'Geçen Süre',
          elapsedTime,
          Icons.timer,
          const Color(0xFF3498DB),
        ),
        _buildStatusIndicator(
          'Geçilen Kapı',
          '$_triggerCount',
          Icons.sensor_door,
          const Color(0xFF27AE60),
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
            color: color.withAlpha(25),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _islemBasladi 
                  ? null 
                  : _useCameraMode
                      ? (_isCalibrated ? _startCameraDetection : _startCameraCalibration)
                      : _startSensorMeasurement,
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
              onPressed: !_islemBasladi ? null : () => _stopMeasurement(),
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

  void _startSensorMeasurement() {
  if (!_isConnected) {
    _showSnackBar('Lütfen önce sensör bağlantısını kurun');
    return;
  }

  setState(() {
    _islemBasladi = false; // Ölçüm henüz başlamadı
    _isStartButtonPressed = true; // Start butonuna basıldı, sensör tetiklemesi bekleniyor
    _kalkisZamani = null; // İlk tetikleme anında ayarlanacak
    _triggerCount = 0;
    _sensorStates.fillRange(0, 7, false);
    _lastTriggers.fillRange(0, 7, DateTime(2000));
    
    // Önceki ölçüm verilerini temizle
    _olcumVerileri[_secilenOlcumNo - 1] = {
      'kapi1': null,
      'kapi2': null,
      'kapi3': null,
      'kapi4': null,
      'kapi5': null,
      'kapi6': null,
      'kapi7': null,
    };
  });

  // Timer'ı hemen başlatmıyoruz, ilk sensör tetiklenince başlayacak
  _showSnackBar('Sprint ölçümü için hazır. Herhangi bir sensör tetiklendiğinde sayaç başlayacak.');
}

  void _stopMeasurement([String message = 'Ölçüm durduruldu']) {
    setState(() {
      _islemBasladi = false;
      _isStartButtonPressed = false;
      _timer?.cancel();
    });
    
    // Kamera ile ilgili düzeltme
    if (_useCameraMode && _cameraController != null) {
      try {
        // Kamera stream açıksa durdur
        if (_cameraController!.value.isStreamingImages) {
          _cameraController!.stopImageStream();
        }
      } catch (e) {
        debugPrint('Kamera stream durdurulurken hata: $e');
      }
    }
    
    _showSnackBar(message);
  }

  void _clearMeasurement() {
    setState(() {
      _islemBasladi = false;
      _isStartButtonPressed = false;
      _kalkisZamani = null;
      _triggerCount = 0;
      _sensorStates.fillRange(0, 7, false);
      _lastTriggers.fillRange(0, 7, DateTime(2000));
      _olcumVerileri[_secilenOlcumNo - 1] = {
        'kapi1': null,
        'kapi2': null,
        'kapi3': null,
        'kapi4': null,
        'kapi5': null,
        'kapi6': null,
        'kapi7': null,
      };
      
      // Kamera moduna özel temizlikler
      if (_useCameraMode) {
        _gateTriggered.fillRange(0, _gateTriggered.length, false);
        _gateTriggerTimes.fillRange(0, _gateTriggerTimes.length, null);
      }
    });
    _timer?.cancel();
    
    // Kamera ile ilgili düzeltme
    if (_useCameraMode && _cameraController != null) {
      try {
        // Kamera stream açıksa durdur
        if (_cameraController!.value.isStreamingImages) {
          _cameraController!.stopImageStream();
        }
      } catch (e) {
        debugPrint('Kamera stream durdurulurken hata: $e');
      }
    }
    
    _showSnackBar('Ölçüm temizlendi');
  }

  Future<void> _saveMeasurements() async {
    final currentData = _olcumVerileri[_secilenOlcumNo - 1];
    if (!currentData.values.any((v) => v != null)) {
      return _showSnackBar('Kaydedilecek ölçüm verisi yok');
    }

    try {
      final testId = await _dbService.getNewTestId();
      final olcum = Olcum(
        sporcuId: widget.sporcuId ?? 0,
        testId: testId,
        olcumTarihi: DateTime.now().toIso8601String(),
        olcumTuru: 'Sprint',
        olcumSirasi: _secilenOlcumNo,
      );

      final olcumId = await _dbService.insertOlcum(olcum);

      for (var i = 1; i <= 7; i++) {
        final value = currentData['kapi$i'];
        if (value != null) {
          final olcumDeger = OlcumDeger(
            olcumId: olcumId,
            degerTuru: 'Kapi$i',
            deger: value,
          );
          await _dbService.insertOlcumDeger(olcumDeger);
        }
      }

      _showSnackBar(
        widget.sporcuId != null
            ? 'Ölçümler başarıyla kaydedildi'
            : 'Ölçümler sporcusuz kaydedildi',
        const Color(0xFF27AE60),
      );
    } catch (e) {
      _showSnackBar('Ölçümler kaydedilirken hata: $e', const Color(0xFFE74C3C));
    }
  }
}

// Sanal kapıları çizmek için özel painter sınıfı
class GatesPainter extends CustomPainter {
  final List<Rect> gates;
  final List<bool> triggered;
  final CameraController cameraController;
  
  GatesPainter({
    required this.gates,
    required this.triggered,
    required this.cameraController,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (gates.isEmpty) return;
    
    // Kamera boyutlarından UI boyutlarına dönüşüm
    final cameraWidth = cameraController.value.previewSize?.width ?? 640;
    final cameraHeight = cameraController.value.previewSize?.height ?? 480;
    
    final scaleX = size.width / cameraWidth;
    final scaleY = size.height / cameraHeight;
    
    // Her kapıyı çiz
    for (int i = 0; i < gates.length; i++) {
      final gate = gates[i];
      final isTriggered = i < triggered.length && triggered[i];
      
      // Kapı rengini belirle (tetiklenmiş mi?)
      final paint = Paint()
        ..color = isTriggered 
            ? const Color(0xFF4CAF50).withAlpha(150) // Tetiklenmiş
            : const Color(0xFFFF5722).withAlpha(150); // Tetiklenmemiş
      
      // Kapıyı UI boyutlarına dönüştür
      final scaledRect = Rect.fromLTWH(
        gate.left * scaleX,
        gate.top * scaleY,
        gate.width * scaleX,
        gate.height * scaleY,
      );
      
      // Kapıyı çiz
      canvas.drawRect(scaledRect, paint);
      
      // Kapı numarasını yaz
      final textSpan = TextSpan(
        text: '${i + 1}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      );
      
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      
      // Kapı ortasına numara yerleştir
      textPainter.paint(
        canvas, 
        Offset(
          scaledRect.left + (scaledRect.width / 2) - (textPainter.width / 2),
          scaledRect.top + 10,
        ),
      );
    }
  }
  
  @override
  bool shouldRepaint(GatesPainter oldDelegate) {
    return oldDelegate.gates != gates || 
           oldDelegate.triggered != triggered ||
           oldDelegate.cameraController != cameraController;
  }
}