// // import 'dart:async';
// // import 'dart:typed_data';
// // import 'package:flutter/material.dart';
// // import 'package:flutter/services.dart';
// // import 'package:camera/camera.dart';
// // import 'package:zxing2/qrcode.dart';
// // import 'package:vibration/vibration.dart';
// // import 'package:shared_preferences/shared_preferences.dart';
// //
// // // import your overlay from your previous code if needed
// // // import 'barcode_scanner_screen.dart' show CustomScannerOverlay;
// //
// // class Zxing2BarcodeScannerScreen extends StatefulWidget {
// //   const Zxing2BarcodeScannerScreen({Key? key}) : super(key: key);
// //
// //   @override
// //   State<Zxing2BarcodeScannerScreen> createState() => _Zxing2BarcodeScannerScreenState();
// // }
// //
// // class _Zxing2BarcodeScannerScreenState extends State<Zxing2BarcodeScannerScreen> {
// //   CameraController? _cameraController;
// //   bool _isDetecting = false;
// //   bool _screenOpened = false;
// //   int _currentLanguageFlag = 1;
// //   String _phOrJp = "ph";
// //   String? _lastScannedCode;
// //   int _consecutiveScanCount = 0;
// //   Timer? _scanResetTimer;
// //   final int _requiredConsecutiveScans = 3;
// //   bool _torchEnabled = false;
// //   CameraDescription? _camera;
// //   CameraLensDirection _cameraFacing = CameraLensDirection.back;
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     _loadPreferences();
// //     _initCamera();
// //   }
// //
// //   Future<void> _loadPreferences() async {
// //     final prefs = await SharedPreferences.getInstance();
// //     setState(() {
// //       _phOrJp = prefs.getString('phorjp') ?? "ph";
// //       if (_phOrJp == "ph") {
// //         _currentLanguageFlag = prefs.getInt('languageFlag') ?? 1;
// //       } else {
// //         _currentLanguageFlag = prefs.getInt('languageFlagJP') ?? 1;
// //       }
// //     });
// //   }
// //
// //   Future<void> _initCamera() async {
// //     final cameras = await availableCameras();
// //     _camera = cameras.firstWhere(
// //           (c) => c.lensDirection == _cameraFacing,
// //       orElse: () => cameras.first,
// //     );
// //     _cameraController = CameraController(
// //       _camera!,
// //       ResolutionPreset.medium,
// //       enableAudio: false,
// //     );
// //     await _cameraController!.initialize();
// //     await _cameraController!.startImageStream(_processCameraImage);
// //     setState(() {});
// //   }
// //
// //   void _processCameraImage(CameraImage image) async {
// //     if (_isDetecting || _screenOpened) return;
// //     _isDetecting = true;
// //
// //     try {
// //       // Convert YUV to grayscale for ZXing
// //       final WriteBuffer allBytes = WriteBuffer();
// //       for (final Plane plane in image.planes) {
// //         allBytes.putUint8List(plane.bytes);
// //       }
// //       final bytes = allBytes.done().buffer.asUint8List();
// //
// //       final width = image.width;
// //       final height = image.height;
// //
// //       // ZXing expects luminance (Y) plane only
// //       final luminance = image.planes[0].bytes;
// //
// //       final source = RGBLuminanceSource(
// //         width,
// //         height,
// //         Int32List.fromList(_yPlaneToRgb(luminance, width, height)), // <-- fix
// //       );
// //       final bitmap = BinaryBitmap(HybridBinarizer(source));
// //       final reader = QRCodeReader();
// //
// //       Result? result;
// //       try {
// //         result = reader.decode(bitmap);
// //       } catch (_) {}
// //
// //       if (result != null && result.text.isNotEmpty) {
// //         _processScannedCode(result.text);
// //       }
// //     } catch (_) {}
// //     _isDetecting = false;
// //   }
// //
// //   // Helper to convert Y plane to grayscale RGB
// //   List<int> _yPlaneToRgb(Uint8List yPlane, int width, int height) {
// //     final List<int> rgb = List.filled(width * height, 0);
// //     for (int i = 0; i < width * height; i++) {
// //       final y = yPlane[i];
// //       rgb[i] = (0xFF << 24) | (y << 16) | (y << 8) | y;
// //     }
// //     return rgb;
// //   }
// //
// //   void _processScannedCode(String code) {
// //     _scanResetTimer?.cancel();
// //
// //     if (_lastScannedCode == code) {
// //       _consecutiveScanCount++;
// //     } else {
// //       _lastScannedCode = code;
// //       _consecutiveScanCount = 1;
// //     }
// //
// //     _scanResetTimer = Timer(const Duration(milliseconds: 500), () {
// //       _consecutiveScanCount = 0;
// //       _lastScannedCode = null;
// //     });
// //
// //     if (_consecutiveScanCount >= _requiredConsecutiveScans) {
// //       _scanResetTimer?.cancel();
// //       _screenOpened = true;
// //       _foundBarcode(code);
// //     }
// //   }
// //
// //   void _foundBarcode(String code) async {
// //     if (await Vibration.hasVibrator() ?? false) {
// //       Vibration.vibrate(duration: 200);
// //     }
// //     SystemSound.play(SystemSoundType.click);
// //     if (mounted) {
// //       Navigator.of(context).pop(code);
// //     }
// //   }
// //
// //   Future<void> _toggleTorch() async {
// //     if (_cameraController == null) return;
// //     _torchEnabled = !_torchEnabled;
// //     await _cameraController!.setFlashMode(
// //       _torchEnabled ? FlashMode.torch : FlashMode.off,
// //     );
// //     setState(() {});
// //   }
// //
// //   Future<void> _switchCamera() async {
// //     if (_cameraController == null) return;
// //     _cameraFacing = _cameraFacing == CameraLensDirection.back
// //         ? CameraLensDirection.front
// //         : CameraLensDirection.back;
// //     await _cameraController?.dispose();
// //     _cameraController = null;
// //     setState(() {});
// //     await _initCamera();
// //   }
// //
// //   String get _titleText => _currentLanguageFlag == 2
// //       ? "バーコードスキャン"
// //       : "Scan Barcode";
// //
// //   String get _positionBarcodeText => _currentLanguageFlag == 2
// //       ? "バーコードをフレーム内に配置してスキャンしてください"
// //       : "Position the barcode within the frame to scan";
// //
// //   String get _flashOnTooltip => _currentLanguageFlag == 2
// //       ? "フラッシュオン"
// //       : "Flash on";
// //
// //   String get _flashOffTooltip => _currentLanguageFlag == 2
// //       ? "フラッシュオフ"
// //       : "Flash off";
// //
// //   String get _frontCameraTooltip => _currentLanguageFlag == 2
// //       ? "フロントカメラ"
// //       : "Front camera";
// //
// //   String get _rearCameraTooltip => _currentLanguageFlag == 2
// //       ? "リアカメラ"
// //       : "Rear camera";
// //
// //   @override
// //   void dispose() {
// //     _scanResetTimer?.cancel();
// //     _cameraController?.dispose();
// //     super.dispose();
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       backgroundColor: Colors.black,
// //       appBar: AppBar(
// //         backgroundColor: Colors.transparent,
// //         elevation: 0,
// //         leading: IconButton(
// //           icon: Icon(Icons.arrow_back, color: Colors.white),
// //           onPressed: () => Navigator.of(context).pop(),
// //           tooltip: _currentLanguageFlag == 2 ? "戻る" : "Back",
// //         ),
// //         title: Text(
// //           _titleText,
// //           style: TextStyle(
// //             color: Colors.white,
// //             fontSize: _currentLanguageFlag == 2 ? 18.0 : 20.0,
// //           ),
// //         ),
// //       ),
// //       body: Stack(
// //         children: [
// //           if (_cameraController != null && _cameraController!.value.isInitialized)
// //             CameraPreview(_cameraController!),
// //           // You can reuse your CustomScannerOverlay from barcode_scanner_screen.dart
// //           // CustomScannerOverlay(
// //           //   borderColor: Colors.red,
// //           //   borderRadius: 10,
// //           //   borderLength: 30,
// //           //   borderWidth: 10,
// //           //   cutOutWidth: 280,
// //           //   cutOutHeight: 140,
// //           // ),
// //           // Or use a simple placeholder overlay:
// //           Center(
// //             child: Container(
// //               width: 280,
// //               height: 140,
// //               decoration: BoxDecoration(
// //                 border: Border.all(color: Colors.red, width: 4),
// //                 borderRadius: BorderRadius.circular(10),
// //               ),
// //             ),
// //           ),
// //           Positioned(
// //             bottom: 100,
// //             left: 0,
// //             right: 0,
// //             child: Container(
// //               padding: const EdgeInsets.all(16),
// //               child: Text(
// //                 _positionBarcodeText,
// //                 style: TextStyle(
// //                   color: Colors.white,
// //                   fontSize: 16,
// //                   fontWeight: FontWeight.bold,
// //                 ),
// //                 textAlign: TextAlign.center,
// //               ),
// //             ),
// //           ),
// //           Positioned(
// //             bottom: 40,
// //             left: 0,
// //             right: 0,
// //             child: Row(
// //               mainAxisAlignment: MainAxisAlignment.center,
// //               children: [
// //                 // Torch button
// //                 Container(
// //                   decoration: BoxDecoration(
// //                     color: Colors.black.withOpacity(0.5),
// //                     shape: BoxShape.circle,
// //                   ),
// //                   child: IconButton(
// //                     icon: Icon(
// //                       _torchEnabled ? Icons.flash_on : Icons.flash_off,
// //                       color: Colors.white,
// //                       size: 32,
// //                     ),
// //                     onPressed: _toggleTorch,
// //                     tooltip: _torchEnabled ? _flashOffTooltip : _flashOnTooltip,
// //                   ),
// //                 ),
// //                 SizedBox(width: 40),
// //                 // Camera switch button
// //                 Container(
// //                   decoration: BoxDecoration(
// //                     color: Colors.black.withOpacity(0.5),
// //                     shape: BoxShape.circle,
// //                   ),
// //                   child: IconButton(
// //                     icon: Icon(
// //                       _cameraFacing == CameraLensDirection.back
// //                           ? Icons.camera_front
// //                           : Icons.camera_rear,
// //                       color: Colors.white,
// //                       size: 32,
// //                     ),
// //                     onPressed: _switchCamera,
// //                     tooltip: _cameraFacing == CameraLensDirection.back
// //                         ? _frontCameraTooltip
// //                         : _rearCameraTooltip,
// //                   ),
// //                 ),
// //               ],
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }
//
// import 'dart:async';
// import 'dart:io';
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
//   final int _requiredConsecutiveScans = 2; // Reduced to 2
//   double _confidenceLevel = 1.0; // Always show 100%
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
//       controller?.start();
//     } else if (state == AppLifecycleState.paused) {
//       controller?.stop();
//     }
//   }
//
//   Future<void> _checkPermissions() async {
//     final status = await Permission.camera.request();
//     setState(() {
//       _isPermissionGranted = status.isGranted;
//       _errorMessage = status.isGranted ? '' : 'Camera permission is required to scan barcodes';
//     });
//
//     if (_isPermissionGranted) {
//       _initializeController();
//     }
//   }
//
//   void _initializeController() {
//     controller = MobileScannerController(
//       detectionSpeed: DetectionSpeed.normal,
//       facing: _isFrontCamera ? CameraFacing.front : CameraFacing.back,
//       torchEnabled: _torchEnabled,
//     );
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
//     // Always show high confidence
//     setState(() {
//       _confidenceLevel = _consecutiveScanCount >= _requiredConsecutiveScans ? 1.0 :
//       (_consecutiveScanCount / _requiredConsecutiveScans) * 0.9 + 0.1;
//     });
//
//     _scanResetTimer = Timer(const Duration(milliseconds: 500), () {
//       _consecutiveScanCount = 0;
//       _lastScannedCode = null;
//       setState(() {
//         _confidenceLevel = 0.1; // Reset confidence
//       });
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
//       await SystemSound.play(SystemSoundType.click);
//     } catch (e) {
//       print("Error playing sound: $e");
//     }
//
//     if (mounted) {
//       Navigator.of(context).pop(code);
//     }
//   }
//
//   Future<void> _toggleTorch() async {
//     await controller?.toggleTorch();
//     setState(() {
//       _torchEnabled = !_torchEnabled;
//     });
//   }
//
//   Future<void> _switchCamera() async {
//     await controller?.switchCamera();
//     setState(() {
//       _isFrontCamera = !_isFrontCamera;
//     });
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
//   @override
//   Widget build(BuildContext context) {
//     if (!_isPermissionGranted) {
//       return Scaffold(
//         appBar: AppBar(
//           title: Text(_titleText),
//         ),
//         body: Center(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 _currentLanguageFlag == 2
//                     ? "カメラのアクセス許可が必要です"
//                     : "Camera permission is required",
//                 style: TextStyle(fontSize: 18),
//               ),
//               SizedBox(height: 20),
//               ElevatedButton(
//                 onPressed: _checkPermissions,
//                 child: Text(
//                   _currentLanguageFlag == 2 ? "許可する" : "Grant Permission",
//                 ),
//               ),
//             ],
//           ),
//         ),
//       );
//     }
//
//     if (_errorMessage.isNotEmpty) {
//       return Scaffold(
//         appBar: AppBar(
//           title: Text(_titleText),
//         ),
//         body: Center(
//           child: Text(_errorMessage),
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
//           // The scanner widget
//           controller != null
//               ? MobileScanner(
//             controller: controller!,
//             onDetect: (capture) {
//               final barcodes = capture.barcodes;
//               if (barcodes.isEmpty) return;
//
//               final barcode = barcodes.first;
//               if (barcode.rawValue == null) return;
//
//               _processScannedCode(barcode.rawValue!);
//             },
//           )
//               : Center(child: CircularProgressIndicator()),
//
//           // Scanning overlay
//           CustomScannerOverlay(
//             borderColor: Colors.red,
//             borderWidth: 3,
//             borderRadius: 10,
//             borderLength: 30,
//             cutOutWidth: 280,
//             cutOutHeight: 140,
//             scanningLineEnabled: true,
//             confidenceLevel: _confidenceLevel,
//             accuracyText: _accuracyText,
//           ),
//
//           // Instruction text
//           Positioned(
//             top: 16,
//             left: 0,
//             right: 0,
//             child: Text(
//               _positionBarcodeText,
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 16,
//                 shadows: [
//                   Shadow(
//                     offset: Offset(1, 1),
//                     blurRadius: 3,
//                     color: Colors.black.withOpacity(0.5),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//
//           // Bottom controls
//           Positioned(
//             bottom: 24,
//             left: 0,
//             right: 0,
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 Container(
//                   decoration: BoxDecoration(
//                     color: Colors.black.withOpacity(0.5),
//                     shape: BoxShape.circle,
//                   ),
//                   child: IconButton(
//                     icon: Icon(
//                       _torchEnabled ? Icons.flash_on : Icons.flash_off,
//                       color: Colors.white,
//                     ),
//                     onPressed: _toggleTorch,
//                     tooltip: _torchEnabled ? _flashOnTooltip : _flashOffTooltip,
//                   ),
//                 ),
//                 Container(
//                   decoration: BoxDecoration(
//                     color: Colors.black.withOpacity(0.5),
//                     shape: BoxShape.circle,
//                   ),
//                   child: IconButton(
//                     icon: Icon(
//                       _isFrontCamera ? Icons.camera_front : Icons.camera_rear,
//                       color: Colors.white,
//                     ),
//                     onPressed: _switchCamera,
//                     tooltip: _isFrontCamera ? _frontCameraTooltip : _rearCameraTooltip,
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
//         // Semi-transparent background
//         ColorFiltered(
//           colorFilter: ColorFilter.mode(
//             Colors.black.withOpacity(0.5),
//             BlendMode.srcOut,
//           ),
//           child: Stack(
//             children: [
//               Container(
//                 decoration: BoxDecoration(
//                   color: Colors.black,
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
//
//         // Corner overlays
//         Center(
//           child: Container(
//             height: widget.cutOutHeight,
//             width: widget.cutOutWidth,
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(widget.borderRadius),
//             ),
//             child: Stack(
//               children: [
//                 Positioned(
//                   top: 0,
//                   left: 0,
//                   child: CustomPaint(
//                     size: Size(widget.borderLength, widget.borderLength),
//                     painter: CornerPainter(
//                       borderColor: widget.borderColor,
//                       borderWidth: widget.borderWidth,
//                       cornerSide: CornerSide.topLeft,
//                     ),
//                   ),
//                 ),
//                 Positioned(
//                   top: 0,
//                   right: 0,
//                   child: CustomPaint(
//                     size: Size(widget.borderLength, widget.borderLength),
//                     painter: CornerPainter(
//                       borderColor: widget.borderColor,
//                       borderWidth: widget.borderWidth,
//                       cornerSide: CornerSide.topRight,
//                     ),
//                   ),
//                 ),
//                 Positioned(
//                   bottom: 0,
//                   left: 0,
//                   child: CustomPaint(
//                     size: Size(widget.borderLength, widget.borderLength),
//                     painter: CornerPainter(
//                       borderColor: widget.borderColor,
//                       borderWidth: widget.borderWidth,
//                       cornerSide: CornerSide.bottomLeft,
//                     ),
//                   ),
//                 ),
//                 Positioned(
//                   bottom: 0,
//                   right: 0,
//                   child: CustomPaint(
//                     size: Size(widget.borderLength, widget.borderLength),
//                     painter: CornerPainter(
//                       borderColor: widget.borderColor,
//                       borderWidth: widget.borderWidth,
//                       cornerSide: CornerSide.bottomRight,
//                     ),
//                   ),
//                 ),
//
//                 // Scanning line
//                 if (widget.scanningLineEnabled)
//                   Positioned(
//                     top: _animation.value * widget.cutOutHeight,
//                     left: 0,
//                     child: Container(
//                       width: widget.cutOutWidth,
//                       height: 2,
//                       decoration: BoxDecoration(
//                         gradient: LinearGradient(
//                           colors: [
//                             Colors.red.withOpacity(0),
//                             Colors.red.withOpacity(0.8),
//                             Colors.red.withOpacity(0),
//                           ],
//                           stops: [0.0, 0.5, 1.0],
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
//
//         // Confidence indicator at top of screen
//         Positioned(
//           top: 50,
//           left: 0,
//           right: 0,
//           child: Center(
//             child: Container(
//               width: 240,
//               padding: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
//               decoration: BoxDecoration(
//                 color: Colors.black.withOpacity(0.7),
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Text(
//                     widget.accuracyText,
//                     style: TextStyle(color: Colors.white, fontSize: 14),
//                   ),
//                   SizedBox(height: 6),
//                   ClipRRect(
//                     borderRadius: BorderRadius.circular(10),
//                     child: LinearProgressIndicator(
//                       value: widget.confidenceLevel,
//                       backgroundColor: Colors.grey[700],
//                       valueColor: AlwaysStoppedAnimation<Color>(
//                         _getConfidenceColor(widget.confidenceLevel),
//                       ),
//                       minHeight: 10,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
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
//
//
//
//
