// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:vibration/vibration.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:permission_handler/permission_handler.dart';
//
// class FlutterBarcodeScannerScreen extends StatefulWidget {
//   const FlutterBarcodeScannerScreen({Key? key}) : super(key: key);
//
//   @override
//   State<FlutterBarcodeScannerScreen> createState() => _FlutterBarcodeScannerScreenState();
// }
//
// class _FlutterBarcodeScannerScreenState extends State<FlutterBarcodeScannerScreen> {
//   bool _scanStarted = false;
//   int _currentLanguageFlag = 1;
//   String _phOrJp = "ph";
//   String? _error;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadPreferences();
//   }
//
//   Future<void> _loadPreferences() async {
//     final prefs = await SharedPreferences.getInstance();
//     _phOrJp = prefs.getString('phorjp') ?? "ph";
//     if (_phOrJp == "ph") {
//       _currentLanguageFlag = prefs.getInt('languageFlag') ?? 1;
//     } else {
//       _currentLanguageFlag = prefs.getInt('languageFlagJP') ?? 1;
//     }
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _startBarcodeScan();
//     });
//     setState(() {});
//   }
//
//   Future<void> _startBarcodeScan() async {
//     if (_scanStarted) return;
//     _scanStarted = true;
//
//     // Only support Android/iOS
//     if (!(Platform.isAndroid || Platform.isIOS)) {
//       setState(() {
//         _error = _currentLanguageFlag == 2
//             ? "この機能はこのプラットフォームではサポートされていません"
//             : "Barcode scanning is not supported on this platform.";
//       });
//       return;
//     }
//
//     // Request camera permission
//     var status = await Permission.camera.request();
//     if (!status.isGranted) {
//       setState(() {
//         _error = _currentLanguageFlag == 2
//             ? "カメラの権限が必要です"
//             : "Camera permission is required.";
//       });
//       return;
//     }
//
//     String barcodeScanRes;
//     try {
//       barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
//         "#ff6666",
//         _currentLanguageFlag == 2 ? "キャンセル" : "Cancel",
//         true,
//         ScanMode.BARCODE,
//       );
//     } on PlatformException {
//       barcodeScanRes = '';
//     }
//     if (!mounted) return;
//     if (barcodeScanRes != '-1' && barcodeScanRes.isNotEmpty) {
//       _foundBarcode(barcodeScanRes);
//     } else {
//       Navigator.of(context).pop();
//     }
//   }
//
//   void _foundBarcode(String code) async {
//     if (await Vibration.hasVibrator() ?? false) {
//       Vibration.vibrate(duration: 200);
//     }
//     SystemSound.play(SystemSoundType.click);
//     if (mounted) {
//       Navigator.of(context).pop(code);
//     }
//   }
//
//   String get _titleText => _currentLanguageFlag == 2
//       ? "バーコードスキャン"
//       : "Scan Barcode";
//
//   @override
//   Widget build(BuildContext context) {
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
//       body: _error != null
//           ? Center(
//         child: Text(
//           _error!,
//           style: TextStyle(color: Colors.red, fontSize: 16),
//           textAlign: TextAlign.center,
//         ),
//       )
//           : const SizedBox.shrink(),
//     );
//   }
// }