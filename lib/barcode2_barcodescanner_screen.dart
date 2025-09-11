import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BarcodeScannerScreen2 extends StatefulWidget {
  const BarcodeScannerScreen2({Key? key}) : super(key: key);

  @override
  State<BarcodeScannerScreen2> createState() => _BarcodeScannerScreen2State();
}

class _BarcodeScannerScreen2State extends State<BarcodeScannerScreen2>
    with WidgetsBindingObserver {
  late MobileScannerController controller;
  bool _isPermissionGranted = false;
  bool _screenOpened = false;
  String _errorMessage = '';
  bool _processingBarcode = false;

  String? _lastScannedCode;
  int _scanCount = 0;
  Timer? _scanResetTimer;
  double _confidenceLevel = 0.1;
  bool _validBarcodeDetected = false;

  DateTime? _lastSuccessfulScan;
  final Duration _scanCooldown = Duration(seconds: 2);

  bool _torchEnabled = false;
  bool _isFrontCamera = false;
  int _currentLanguageFlag = 1;
  String _phOrJp = "ph";

  // Increased scan area for better detection
  static const double scanAreaWidth = 300;
  static const double scanAreaHeight = 120;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPreferences();
    _checkPermissions();
    controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _phOrJp = prefs.getString('phorjp') ?? "ph";
      if (_phOrJp == "ph") {
        _currentLanguageFlag = prefs.getInt('languageFlag') ?? 1;
      } else {
        _currentLanguageFlag = prefs.getInt('languageFlagJP') ?? 1;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    _scanResetTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      controller.start();
    } else if (state == AppLifecycleState.paused) {
      controller.stop();
    }
  }

  Future<void> _checkPermissions() async {
    final status = await Permission.camera.request();
    setState(() {
      _isPermissionGranted = status.isGranted;
      _errorMessage = status.isGranted ? '' : 'Camera permission is required to scan barcodes';
    });
  }

  bool _validateBarcodeContent(String code) {
    if (code.isEmpty) return false;
    if (code.length < 3) return false;
    final RegExp validBarcodePattern = RegExp(r'^[A-Za-z0-9\-_+./:]+$');
    return validBarcodePattern.hasMatch(code);
  }

  void _processScannedCode(BarcodeCapture capture) {
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    if (barcode.rawValue == null) return;
    final code = barcode.rawValue!;

    // Check cooldown period
    if (_lastSuccessfulScan != null) {
      final timeSinceLastScan = DateTime.now().difference(_lastSuccessfulScan!);
      if (timeSinceLastScan < _scanCooldown) return;
    }

    // Validate barcode content
    if (!_validateBarcodeContent(code)) {
      setState(() {
        _validBarcodeDetected = false;
        _confidenceLevel = 0.1;
      });
      return;
    }

    // Confidence logic: increase on every scan, reset if different code
    if (_lastScannedCode == code) {
      _scanCount++;
    } else {
      _lastScannedCode = code;
      _scanCount = 1;
    }

    // Confidence: 0.1 + up to 0.9 for 1+ scans, max 1.0
    double weightedConfidence = math.min(1.0, 0.1 + (_scanCount / 2) * 0.9);

    setState(() {
      _confidenceLevel = weightedConfidence;
      _validBarcodeDetected = _scanCount >= 1 && _confidenceLevel > 0.5;
    });

    // Reset scan count if no scan in 1s
    _scanResetTimer?.cancel();
    _scanResetTimer = Timer(const Duration(milliseconds: 1000), () {
      setState(() {
        _scanCount = 0;
        _lastScannedCode = null;
        _confidenceLevel = 0.1;
        _validBarcodeDetected = false;
      });
    });

    // Accept barcode if confidence is high enough
    if (_confidenceLevel > 0.7) {
      _scanResetTimer?.cancel();
      _foundBarcode(code);
    }
  }

  void _foundBarcode(String code) async {
    if (_processingBarcode || _screenOpened) return;
    _processingBarcode = true;
    _screenOpened = true;
    _lastSuccessfulScan = DateTime.now();

    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 200);
    }

    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      Navigator.of(context).pop(code);
    }
  }

  Future<void> _toggleTorch() async {
    await controller.toggleTorch();
    setState(() => _torchEnabled = !_torchEnabled);
  }

  Future<void> _switchCamera() async {
    await controller.switchCamera();
    setState(() => _isFrontCamera = !_isFrontCamera);
  }

  String get _titleText => _currentLanguageFlag == 2
      ? "バーコードスキャン"
      : "Scan Barcode";

  String get _positionBarcodeText => _currentLanguageFlag == 2
      ? "バーコードをフレーム内に配置してスキャンしてください"
      : "Position the barcode within the frame to scan";

  String get _flashOnTooltip => _currentLanguageFlag == 2
      ? "フラッシュオン"
      : "Flash on";

  String get _flashOffTooltip => _currentLanguageFlag == 2
      ? "フラッシュオフ"
      : "Flash off";

  String get _frontCameraTooltip => _currentLanguageFlag == 2
      ? "フロントカメラ"
      : "Front camera";

  String get _rearCameraTooltip => _currentLanguageFlag == 2
      ? "リアカメラ"
      : "Rear camera";

  String get _accuracyText => _currentLanguageFlag == 2
      ? "精度"
      : "Accuracy";

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    if (!_isPermissionGranted) {
      return Scaffold(
        appBar: AppBar(title: Text(_titleText)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _currentLanguageFlag == 2
                    ? "カメラのアクセス許可が必要です"
                    : "Camera permission is required",
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _checkPermissions,
                child: Text(_currentLanguageFlag == 2 ? "許可する" : "Grant Permission"),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_titleText)),
        body: Center(child: Text(_errorMessage)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: _currentLanguageFlag == 2 ? "戻る" : "Back",
        ),
        title: Text(
          _titleText,
          style: TextStyle(
            color: Colors.white,
            fontSize: _currentLanguageFlag == 2 ? 18.0 : 20.0,
          ),
        ),
      ),
      body: Stack(
        children: [
          // The scanner widget
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              _processScannedCode(capture);
            },
          ),

          // Scanning overlay
          CustomScannerOverlay(
            borderColor: Colors.red,
            borderWidth: 3,
            borderRadius: 10,
            borderLength: 30,
            cutOutWidth: scanAreaWidth,
            cutOutHeight: scanAreaHeight,
            scanningLineEnabled: true,
            confidenceLevel: _confidenceLevel,
            accuracyText: _accuracyText,
            highlight: _validBarcodeDetected,
          ),

          // Instruction text
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Text(
              _positionBarcodeText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                shadows: [
                  Shadow(
                    offset: const Offset(1, 1),
                    blurRadius: 3,
                    color: Colors.black.withOpacity(0.5),
                  ),
                ],
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      _torchEnabled ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white,
                    ),
                    onPressed: _toggleTorch,
                    tooltip: _torchEnabled ? _flashOnTooltip : _flashOffTooltip,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isFrontCamera ? Icons.camera_front : Icons.camera_rear,
                      color: Colors.white,
                    ),
                    onPressed: _switchCamera,
                    tooltip: _isFrontCamera ? _rearCameraTooltip : _frontCameraTooltip,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CustomScannerOverlay extends StatefulWidget {
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final double borderLength;
  final double cutOutWidth;
  final double cutOutHeight;
  final bool scanningLineEnabled;
  final double confidenceLevel;
  final String accuracyText;
  final bool highlight;

  const CustomScannerOverlay({
    Key? key,
    required this.borderColor,
    required this.borderWidth,
    required this.borderRadius,
    required this.borderLength,
    required this.cutOutWidth,
    required this.cutOutHeight,
    required this.scanningLineEnabled,
    required this.confidenceLevel,
    required this.accuracyText,
    required this.highlight,
  }) : super(key: key);

  @override
  State<CustomScannerOverlay> createState() => _CustomScannerOverlayState();
}

class _CustomScannerOverlayState extends State<CustomScannerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: false);
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cutOutWidth = widget.cutOutWidth;
    final cutOutHeight = widget.cutOutHeight;
    final left = (size.width - cutOutWidth) / 2;
    final top = (size.height - cutOutHeight) / 2;

    return Stack(
      children: [
        // Overlay with cutout
        Positioned.fill(
          child: CustomPaint(
            painter: _CornerPainter(
              borderColor: widget.borderColor,
              borderWidth: widget.borderWidth,
              borderRadius: widget.borderRadius,
              borderLength: widget.borderLength,
              cutOutRect: Rect.fromLTWH(left, top, cutOutWidth, cutOutHeight),
            ),
          ),
        ),
        // Scanning line
        if (widget.scanningLineEnabled)
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final y = top + _animation.value * cutOutHeight;
              return Positioned(
                left: left,
                right: left,
                top: y,
                child: Container(
                  width: cutOutWidth,
                  height: 2,
                  color: widget.highlight
                      ? Colors.greenAccent
                      : widget.borderColor.withOpacity(0.7),
                ),
              );
            },
          ),
        // Confidence/accuracy indicator
        Positioned(
          left: left,
          top: top + cutOutHeight + 12,
          width: cutOutWidth,
          child: Column(
            children: [
              LinearProgressIndicator(
                value: widget.confidenceLevel.clamp(0.0, 1.0),
                backgroundColor: Colors.white24,
                color: widget.highlight ? Colors.green : widget.borderColor,
                minHeight: 6,
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.accuracyText}: ${(widget.confidenceLevel * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  shadows: [
                    Shadow(
                      offset: Offset(1, 1),
                      blurRadius: 2,
                      color: Colors.black45,
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final double borderLength;
  final Rect cutOutRect;

  _CornerPainter({
    required this.borderColor,
    required this.borderWidth,
    required this.borderRadius,
    required this.borderLength,
    required this.cutOutRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke;

    final r = borderRadius;
    final l = borderLength;
    final rect = cutOutRect;

    // Top left
    canvas.drawLine(rect.topLeft, rect.topLeft + Offset(l, 0), paint);
    canvas.drawLine(rect.topLeft, rect.topLeft + Offset(0, l), paint);
    // Top right
    canvas.drawLine(rect.topRight, rect.topRight + Offset(-l, 0), paint);
    canvas.drawLine(rect.topRight, rect.topRight + Offset(0, l), paint);
    // Bottom left
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + Offset(l, 0), paint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + Offset(0, -l), paint);
    // Bottom right
    canvas.drawLine(rect.bottomRight, rect.bottomRight + Offset(-l, 0), paint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight + Offset(0, -l), paint);

    // Optionally, draw rounded rectangle for the cutout
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r));
    canvas.drawRRect(rrect, paint..color = borderColor.withOpacity(0.3));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}