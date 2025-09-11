// import 'dart:async';
// import 'dart:io';
// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:mobile_scanner/mobile_scanner.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:vibration/vibration.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// class BarcodeScannerScreen2 extends StatefulWidget {
//   const BarcodeScannerScreen2({Key? key}) : super(key: key);
//
//   @override
//   State<BarcodeScannerScreen2> createState() => _BarcodeScannerScreenState();
// }
//
// class _BarcodeScannerScreenState extends State<BarcodeScannerScreen2> with WidgetsBindingObserver {
//   MobileScannerController? controller;
//   bool _isPermissionGranted = false;
//   bool _screenOpened = false;
//   String _errorMessage = '';
//   bool _processingBarcode = false;
//
//   // Barcode detection settings
//   String? _lastScannedCode;
//   int _consecutiveScanCount = 0;
//   Timer? _scanResetTimer;
//   final int _requiredConsecutiveScans = 2;
//   double _confidenceLevel = 0.33;
//
//   // Light detection
//   bool _hasGoodLighting = true;
//
//   // Scan window
//   Rect? _scanWindow;
//   final double _cutOutWidth = 280.0;
//   final double _cutOutHeight = 140.0;
//
//   // UI control
//   bool _torchEnabled = false;
//   bool _isFrontCamera = false;
//   int _currentLanguageFlag = 1; // Default to English
//   String _phOrJp = "ph"; // Default to ph
//
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//     _loadPreferences();
//     _checkPermissions();
//   }
//
//   Future<void> _loadPreferences() async {
//     final prefs = await SharedPreferences.getInstance();
//     setState(() {
//       _phOrJp = prefs.getString('phorjp') ?? "ph";
//       if (_phOrJp == "ph") {
//         _currentLanguageFlag = prefs.getInt('languageFlag') ?? 1;
//       } else {
//         _currentLanguageFlag = prefs.getInt('languageFlagJP') ?? 1;
//       }
//     });
//   }
//
//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     controller?.dispose();
//     _scanResetTimer?.cancel();
//     super.dispose();
//   }
//
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     if (state == AppLifecycleState.resumed) {
//       if (_isPermissionGranted && controller == null) {
//         _initializeController();
//       }
//     } else if (state == AppLifecycleState.paused) {
//       controller?.stop();
//     }
//   }
//
//   Future<void> _checkPermissions() async {
//     final status = await Permission.camera.request();
//     setState(() {
//       _isPermissionGranted = status.isGranted;
//       _errorMessage = status.isDenied || status.isPermanentlyDenied
//           ? _currentLanguageFlag == 2
//           ? 'カメラの権限が必要です'
//           : 'Camera permission is required'
//           : '';
//     });
//
//     if (_isPermissionGranted) {
//       // Use a slight delay to ensure the widget is built before initializing
//       await Future.delayed(const Duration(milliseconds: 100));
//       _initializeController();
//     }
//   }
//
//   void _calculateScanWindow(BuildContext context) {
//     if (_scanWindow != null) return;
//
//     final Size screenSize = MediaQuery.of(context).size;
//     final double screenWidth = screenSize.width;
//     final double screenHeight = screenSize.height;
//
//     // Calculate the center of the screen
//     final double centerX = screenWidth / 2;
//     final double centerY = screenHeight / 2;
//
//     // Calculate the top-left corner of the scan window
//     final double left = centerX - (_cutOutWidth / 2);
//     final double top = centerY - (_cutOutHeight / 2);
//
//     // Create the scan window rect
//     _scanWindow = Rect.fromLTWH(
//         left,
//         top,
//         _cutOutWidth,
//         _cutOutHeight
//     );
//   }
//
//   void _initializeController() {
//     if (controller != null) return;
//
//     try {
//       controller = MobileScannerController(
//         facing: _isFrontCamera ? CameraFacing.front : CameraFacing.back,
//         torchEnabled: _torchEnabled,
//         formats: BarcodeFormat.values,
//         // Use balanced detection mode for better accuracy with light variations
//         detectionSpeed: DetectionSpeed.normal,
//         detectionTimeoutMs: 1000,
//         returnImage: false,
//       );
//
//       // Use a delayed start to ensure everything is properly set up
//       Future.delayed(const Duration(milliseconds: 200), () {
//         if (mounted && controller != null) {
//           controller!.start();
//         }
//       });
//
//       setState(() {});
//     } catch (e) {
//       setState(() {
//         _errorMessage = 'Failed to initialize scanner: ${e.toString()}';
//       });
//     }
//   }
//
//   void _analyzeImageLighting(BarcodeCapture capture) {
//     if (capture.image == null) {
//       _hasGoodLighting = true;
//       return;
//     }
//
//     // Simple brightness detection based on image data
//     try {
//       final image = capture.image!;
//       final bytes = image.bytes;
//
//       // Sample some pixels to determine brightness
//       // For efficiency, we'll sample just a few points
//       int totalBrightness = 0;
//       int sampleCount = 0;
//
//       for (int i = 0; i < bytes.length; i += bytes.length ~/ 100) {
//         if (i + 2 < bytes.length) {
//           // Average RGB values (assuming format is RGB)
//           int pixelBrightness = (bytes[i] + bytes[i + 1] + bytes[i + 2]) ~/ 3;
//           totalBrightness += pixelBrightness;
//           sampleCount++;
//         }
//       }
//
//       if (sampleCount > 0) {
//         int avgBrightness = totalBrightness ~/ sampleCount;
//         _hasGoodLighting = avgBrightness > 40 && avgBrightness < 215;
//       }
//     } catch (e) {
//       _hasGoodLighting = true; // Default to assuming good lighting on error
//     }
//   }
//
//   bool _isBarcodeInScanWindow(Barcode barcode, Size imageSize) {
//     if (_scanWindow == null || barcode.corners == null || barcode.corners!.isEmpty) {
//       return true; // If we can't determine, accept the barcode
//     }
//
//     // Get the size of the preview
//     final previewSize = MediaQuery.of(context).size;
//
//     // Calculate scale factors
//     final double scaleX = previewSize.width / imageSize.width;
//     final double scaleY = previewSize.height / imageSize.height;
//
//     // Check if at least 3 corners are inside the scan window
//     int cornersInside = 0;
//     for (final corner in barcode.corners!) {
//       // Scale the corner position to match the screen coordinates
//       final screenX = corner.x * scaleX;
//       final screenY = corner.y * scaleY;
//
//       if (_scanWindow!.contains(Offset(screenX, screenY))) {
//         cornersInside++;
//       }
//     }
//
//     // Consider barcode inside if at least 3 corners are inside
//     return cornersInside >= 3;
//   }
//
//   void _onBarcodeDetected(BarcodeCapture capture) {
//     if (_processingBarcode || _screenOpened) return;
//
//     // Analyze lighting conditions
//     _analyzeImageLighting(capture);
//
//     // Get image size for scan window calculations
//     final imageSize = capture.image != null
//         ? Size(capture.image!.width.toDouble(), capture.image!.height.toDouble())
//         : Size(1, 1);
//
//     for (final barcode in capture.barcodes) {
//       if (barcode.rawValue == null) continue;
//
//       // Only process barcodes inside the scan window
//       if (!_isBarcodeInScanWindow(barcode, imageSize)) continue;
//
//       // Process the barcode
//       _processScannedCode(barcode.rawValue!);
//       break;
//     }
//   }
//
//   void _processScannedCode(String code) {
//     _scanResetTimer?.cancel();
//
//     if (_lastScannedCode == code) {
//       _consecutiveScanCount++;
//     } else {
//       _lastScannedCode = code;
//       _consecutiveScanCount = 1;
//     }
//
//     // Calculate confidence based on multiple factors
//     double lightingFactor = _hasGoodLighting ? 1.0 : 0.7;
//     double confidenceBase = min(0.33 * _consecutiveScanCount, 1.0);
//
//     setState(() {
//       _confidenceLevel = _consecutiveScanCount >= _requiredConsecutiveScans ?
//       1.0 : (confidenceBase * lightingFactor);
//     });
//
//     _scanResetTimer = Timer(const Duration(milliseconds: 500), () {
//       if (mounted) {
//         setState(() {
//           _consecutiveScanCount = 0;
//           _lastScannedCode = null;
//           _confidenceLevel = 0.33;
//         });
//       }
//     });
//
//     if (_consecutiveScanCount >= _requiredConsecutiveScans) {
//       _scanResetTimer?.cancel();
//       _foundBarcode(code);
//     }
//   }
//
//   void _foundBarcode(String code) async {
//     if (_processingBarcode || _screenOpened) return;
//
//     _processingBarcode = true;
//     _screenOpened = true;
//
//     if (await Vibration.hasVibrator() ?? false) {
//       Vibration.vibrate(duration: 200);
//     }
//
//     try {
//       HapticFeedback.mediumImpact();
//     } catch (_) {}
//
//     if (mounted) {
//       Navigator.of(context).pop(code);
//     }
//   }
//
//   Future<void> _toggleTorch() async {
//     try {
//       await controller?.toggleTorch();
//       setState(() {
//         _torchEnabled = !_torchEnabled;
//       });
//     } catch (e) {
//       print('Error toggling torch: $e');
//     }
//   }
//
//   Future<void> _switchCamera() async {
//     try {
//       await controller?.switchCamera();
//       setState(() {
//         _isFrontCamera = !_isFrontCamera;
//       });
//     } catch (e) {
//       print('Error switching camera: $e');
//     }
//   }
//
//   // Localized text getters
//   String get _titleText => _currentLanguageFlag == 2
//       ? "バーコードスキャン"
//       : "Scan Barcode";
//
//   String get _positionBarcodeText => _currentLanguageFlag == 2
//       ? "バーコードをフレーム内に配置してスキャンしてください"
//       : "Position the barcode within the frame to scan";
//
//   String get _flashOnTooltip => _currentLanguageFlag == 2
//       ? "フラッシュオン"
//       : "Flash on";
//
//   String get _flashOffTooltip => _currentLanguageFlag == 2
//       ? "フラッシュオフ"
//       : "Flash off";
//
//   String get _frontCameraTooltip => _currentLanguageFlag == 2
//       ? "フロントカメラ"
//       : "Front camera";
//
//   String get _rearCameraTooltip => _currentLanguageFlag == 2
//       ? "リアカメラ"
//       : "Rear camera";
//
//   String get _scanningText => _currentLanguageFlag == 2
//       ? "スキャン中..."
//       : "Scanning...";
//
//   String get _detectedBarcodeText => _currentLanguageFlag == 2
//       ? "検出されたバーコード"
//       : "Detected Barcode";
//
//   String get _accuracyText => _currentLanguageFlag == 2
//       ? "精度"
//       : "Accuracy";
//
//   String get _lightingText => _currentLanguageFlag == 2
//       ? _hasGoodLighting ? "照明: 良好" : "照明: 改善が必要"
//       : _hasGoodLighting ? "Lighting: Good" : "Lighting: Needs improvement";
//
//   @override
//   Widget build(BuildContext context) {
//     // Calculate scan window when building
//     _calculateScanWindow(context);
//
//     if (!_isPermissionGranted) {
//       return Scaffold(
//         backgroundColor: Colors.black,
//         body: Center(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 _errorMessage,
//                 style: TextStyle(color: Colors.white),
//               ),
//               SizedBox(height: 16),
//               ElevatedButton(
//                 onPressed: _checkPermissions,
//                 child: Text(_currentLanguageFlag == 2 ? "権限を要求" : "Request Permission"),
//               ),
//             ],
//           ),
//         ),
//       );
//     }
//
//     if (_errorMessage.isNotEmpty) {
//       return Scaffold(
//         backgroundColor: Colors.black,
//         body: Center(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 _errorMessage,
//                 style: TextStyle(color: Colors.white),
//               ),
//               SizedBox(height: 16),
//               ElevatedButton(
//                 onPressed: () {
//                   setState(() {
//                     _errorMessage = '';
//                   });
//                   _initializeController();
//                 },
//                 child: Text(_currentLanguageFlag == 2 ? "再試行" : "Retry"),
//               ),
//             ],
//           ),
//         ),
//       );
//     }
//
//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         leading: IconButton(
//           icon: Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () => Navigator.of(context).pop(),
//           tooltip: _currentLanguageFlag == 2 ? "戻る" : "Back",
//         ),
//         title: Text(
//           _titleText,
//           style: TextStyle(
//             color: Colors.white,
//             fontSize: _currentLanguageFlag == 2 ? 18.0 : 20.0,
//           ),
//         ),
//       ),
//       body: Stack(
//         children: [
//           if (controller != null)
//             MobileScanner(
//               controller: controller,
//               onDetect: _onBarcodeDetected,
//               scanWindow: _scanWindow,
//               overlay: CustomScannerOverlay(
//                 borderColor: Colors.red,
//                 borderWidth: 3.0,
//                 borderRadius: 10.0,
//                 borderLength: 30.0,
//                 cutOutWidth: _cutOutWidth,
//                 cutOutHeight: _cutOutHeight,
//                 scanningLineEnabled: true,
//                 confidenceLevel: _confidenceLevel,
//                 accuracyText: _accuracyText,
//               ),
//             ),
//           if (controller == null)
//             Center(
//               child: CircularProgressIndicator(
//                 color: Colors.white,
//               ),
//             ),
//           Positioned(
//             bottom: 130,
//             left: 0,
//             right: 0,
//             child: Container(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 children: [
//                   Text(
//                     _positionBarcodeText,
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                     ),
//                     textAlign: TextAlign.center,
//                   ),
//                   SizedBox(height: 8),
//                   Text(
//                     _lightingText,
//                     style: TextStyle(
//                       color: _hasGoodLighting ? Colors.green : Colors.yellow,
//                       fontSize: 14,
//                     ),
//                     textAlign: TextAlign.center,
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           Positioned(
//             bottom: 40,
//             left: 0,
//             right: 0,
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 // Torch button
//                 Container(
//                   decoration: BoxDecoration(
//                     color: Colors.black.withOpacity(0.5),
//                     shape: BoxShape.circle,
//                   ),
//                   child: IconButton(
//                     icon: Icon(
//                       _torchEnabled ? Icons.flash_on : Icons.flash_off,
//                       color: Colors.white,
//                       size: 32,
//                     ),
//                     onPressed: _toggleTorch,
//                     tooltip: _torchEnabled ? _flashOffTooltip : _flashOnTooltip,
//                   ),
//                 ),
//                 SizedBox(width: 40),
//                 // Camera switch button
//                 Container(
//                   decoration: BoxDecoration(
//                     color: Colors.black.withOpacity(0.5),
//                     shape: BoxShape.circle,
//                   ),
//                   child: IconButton(
//                     icon: Icon(
//                       _isFrontCamera ? Icons.camera_rear : Icons.camera_front,
//                       color: Colors.white,
//                       size: 32,
//                     ),
//                     onPressed: _switchCamera,
//                     tooltip: _isFrontCamera ? _rearCameraTooltip : _frontCameraTooltip,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class CustomScannerOverlay extends StatefulWidget {
//   final Color borderColor;
//   final double borderWidth;
//   final double borderRadius;
//   final double borderLength;
//   final double cutOutWidth;
//   final double cutOutHeight;
//   final bool scanningLineEnabled;
//   final double confidenceLevel;
//   final String accuracyText;
//
//   const CustomScannerOverlay({
//     Key? key,
//     required this.borderColor,
//     required this.borderWidth,
//     required this.borderRadius,
//     required this.borderLength,
//     required this.cutOutWidth,
//     required this.cutOutHeight,
//     this.scanningLineEnabled = true,
//     this.confidenceLevel = 1.0,
//     this.accuracyText = "Accuracy",
//   }) : super(key: key);
//
//   @override
//   State<CustomScannerOverlay> createState() => _CustomScannerOverlayState();
// }
//
// class _CustomScannerOverlayState extends State<CustomScannerOverlay>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _animationController;
//   late Animation<double> _animation;
//
//   @override
//   void initState() {
//     super.initState();
//     _animationController = AnimationController(
//       duration: const Duration(seconds: 1),
//       vsync: this,
//     );
//
//     _animation = Tween<double>(begin: 0, end: 1).animate(_animationController)
//       ..addListener(() {
//         setState(() {});
//       });
//
//     _animationController.repeat(reverse: true);
//   }
//
//   @override
//   void dispose() {
//     _animationController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       children: [
//         ColorFiltered(
//           colorFilter: ColorFilter.mode(
//             Colors.black.withOpacity(0.5),
//             BlendMode.srcOut,
//           ),
//           child: Stack(
//             children: [
//               Container(
//                 decoration: BoxDecoration(
//                   color: Colors.transparent,
//                   backgroundBlendMode: BlendMode.dstOut,
//                 ),
//               ),
//               Center(
//                 child: Container(
//                   height: widget.cutOutHeight,
//                   width: widget.cutOutWidth,
//                   decoration: BoxDecoration(
//                     color: Colors.red,
//                     borderRadius: BorderRadius.circular(widget.borderRadius),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         Center(
//           child: Container(
//             width: widget.cutOutWidth,
//             height: widget.cutOutHeight,
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(widget.borderRadius),
//             ),
//             child: Stack(
//               clipBehavior: Clip.none,
//               children: [
//                 Positioned(
//                   top: -widget.borderWidth / 2,
//                   left: -widget.borderWidth / 2,
//                   child: CustomPaint(
//                     size: Size(widget.borderLength + widget.borderWidth, widget.borderLength + widget.borderWidth),
//                     painter: CornerPainter(
//                       borderColor: widget.borderColor,
//                       borderWidth: widget.borderWidth,
//                       cornerSide: CornerSide.topLeft,
//                     ),
//                   ),
//                 ),
//                 Positioned(
//                   top: -widget.borderWidth / 2,
//                   right: -widget.borderWidth / 2,
//                   child: CustomPaint(
//                     size: Size(widget.borderLength + widget.borderWidth, widget.borderLength + widget.borderWidth),
//                     painter: CornerPainter(
//                       borderColor: widget.borderColor,
//                       borderWidth: widget.borderWidth,
//                       cornerSide: CornerSide.topRight,
//                     ),
//                   ),
//                 ),
//                 Positioned(
//                   bottom: -widget.borderWidth / 2,
//                   left: -widget.borderWidth / 2,
//                   child: CustomPaint(
//                     size: Size(widget.borderLength + widget.borderWidth, widget.borderLength + widget.borderWidth),
//                     painter: CornerPainter(
//                       borderColor: widget.borderColor,
//                       borderWidth: widget.borderWidth,
//                       cornerSide: CornerSide.bottomLeft,
//                     ),
//                   ),
//                 ),
//                 Positioned(
//                   bottom: -widget.borderWidth / 2,
//                   right: -widget.borderWidth / 2,
//                   child: CustomPaint(
//                     size: Size(widget.borderLength + widget.borderWidth, widget.borderLength + widget.borderWidth),
//                     painter: CornerPainter(
//                       borderColor: widget.borderColor,
//                       borderWidth: widget.borderWidth,
//                       cornerSide: CornerSide.bottomRight,
//                     ),
//                   ),
//                 ),
//                 if (widget.scanningLineEnabled)
//                   Positioned(
//                     top: _animation.value * widget.cutOutHeight,
//                     left: 0,
//                     child: Container(
//                       width: widget.cutOutWidth,
//                       height: 1.5,
//                       decoration: BoxDecoration(
//                         gradient: LinearGradient(
//                           colors: [
//                             Colors.transparent,
//                             widget.borderColor.withOpacity(0.7),
//                             widget.borderColor.withOpacity(0.9),
//                             widget.borderColor.withOpacity(0.7),
//                             Colors.transparent,
//                           ],
//                           stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
//                           begin: Alignment.centerLeft,
//                           end: Alignment.centerRight,
//                         ),
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ),
//         Positioned(
//           bottom: 16,
//           left: 0,
//           right: 0,
//           child: Column(
//             children: [
//               Text(
//                 "${widget.accuracyText}: ${(widget.confidenceLevel * 100).toInt()}%",
//                 style: TextStyle(
//                   color: _getConfidenceColor(widget.confidenceLevel),
//                   fontWeight: FontWeight.bold,
//                   fontSize: 16,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//               SizedBox(height: 8),
//               Container(
//                 width: 200,
//                 height: 10,
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(5),
//                   color: Colors.grey.withOpacity(0.3),
//                 ),
//                 child: FractionallySizedBox(
//                   alignment: Alignment.centerLeft,
//                   widthFactor: widget.confidenceLevel,
//                   child: Container(
//                     decoration: BoxDecoration(
//                       borderRadius: BorderRadius.circular(5),
//                       color: _getConfidenceColor(widget.confidenceLevel),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
//
//   // Get a color based on confidence level
//   Color _getConfidenceColor(double confidence) {
//     if (confidence < 0.3) return Colors.red;
//     if (confidence < 0.7) return Colors.orange;
//     return Colors.green;
//   }
// }
//
// enum CornerSide { topLeft, topRight, bottomLeft, bottomRight }
//
// class CornerPainter extends CustomPainter {
//   final Color borderColor;
//   final double borderWidth;
//   final CornerSide cornerSide;
//
//   CornerPainter({
//     required this.borderColor,
//     required this.borderWidth,
//     required this.cornerSide,
//   });
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     final Paint paint = Paint()
//       ..color = borderColor
//       ..strokeWidth = borderWidth
//       ..style = PaintingStyle.stroke;
//
//     final Path path = Path();
//
//     switch (cornerSide) {
//       case CornerSide.topLeft:
//         path.moveTo(0, size.height / 2);
//         path.lineTo(0, 0);
//         path.lineTo(size.width / 2, 0);
//         break;
//       case CornerSide.topRight:
//         path.moveTo(size.width / 2, 0);
//         path.lineTo(size.width, 0);
//         path.lineTo(size.width, size.height / 2);
//         break;
//       case CornerSide.bottomLeft:
//         path.moveTo(0, size.height / 2);
//         path.lineTo(0, size.height);
//         path.lineTo(size.width / 2, size.height);
//         break;
//       case CornerSide.bottomRight:
//         path.moveTo(size.width / 2, size.height);
//         path.lineTo(size.width, size.height);
//         path.lineTo(size.width, size.height / 2);
//         break;
//     }
//
//     canvas.drawPath(path, paint);
//   }
//
//   @override
//   bool shouldRepaint(CustomPainter oldDelegate) => false;
// }