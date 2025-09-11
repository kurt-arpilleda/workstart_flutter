import 'package:flutter/material.dart';
import 'webview.dart';
import 'phorjapan.dart';
import 'japanFolder/webviewJP.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unique_identifier/unique_identifier.dart';
import 'api_service.dart';
import 'japanFolder/api_serviceJP.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //New Vincent Code Start = July 14, 2025
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  //New Vincent Code End = July 14, 2025
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? phOrJp = prefs.getString('phorjp');
  String? deviceId = await UniqueIdentifier.serial;
  ApiService.setupHttpOverrides();
  ApiServiceJP.setupHttpOverrides();
  String initialRoute = '/phorjapan'; // Default route

  if (phOrJp == null) {
    initialRoute = '/phorjapan';
  } else if (deviceId != null) {
    try {
      dynamic response;

      if (phOrJp == "ph") {
        final apiService = ApiService();
        response = await apiService.checkDeviceId(deviceId);
      } else if (phOrJp == "jp") {
        final apiServiceJP = ApiServiceJP();
        response = await apiServiceJP.checkDeviceId(deviceId);
      }

      if (response['success'] == true) {
        if (phOrJp == "ph") {
          initialRoute = '/webView';
        } else if (phOrJp == "jp") {
          initialRoute = '/webViewJP';
        }
      }
    } catch (e) {
      print("Error checking device ID: $e");
    }
  }

  runApp(MyApp(initialRoute: initialRoute));
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  MyApp({required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Work Start & Finish',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: initialRoute,
      routes: {
        '/phorjapan': (context) => PhOrJpScreen(),
        '/webView': (context) => SoftwareWebViewScreen(linkID: 3),
        '/webViewJP': (context) => SoftwareWebViewScreenJP(linkID: 3),
      },
    );
  }
}