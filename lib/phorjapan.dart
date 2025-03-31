import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unique_identifier/unique_identifier.dart';
import 'webview.dart';
import 'japanFolder/webviewJP.dart';
import 'api_service.dart';
import 'japanFolder/api_serviceJP.dart';

class PhOrJpScreen extends StatelessWidget {
  Future<void> _setPreference(String value, BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('phorjp', value);

    try {
      String? deviceId = await UniqueIdentifier.serial;
      if (deviceId == null) {
        _showLoginDialog(context);
        return;
      }

      dynamic response;

      if (value == 'ph') {
        final apiService = ApiService();
        response = await apiService.checkDeviceId(deviceId);
      } else if (value == 'jp') {
        final apiServiceJP = ApiServiceJP();
        response = await apiServiceJP.checkDeviceId(deviceId);
      }

      if (response['success'] == true) {
        if (value == 'ph') {
          _navigateWithTransition(context, SoftwareWebViewScreen(linkID: 3));
        } else if (value == 'jp') {
          _navigateWithTransition(context, SoftwareWebViewScreenJP(linkID: 3));
        }
      } else {
        _showLoginDialog(context);
      }
    } catch (e) {
      _showLoginDialog(context);
    }
  }

  void _showLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Login Required"),
          content: Text("Please login to ARK LOG App first"),
          actions: [
            TextButton(
              child: Text("Back"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _navigateWithTransition(BuildContext context, Widget screen) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
        transitionDuration: Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'PH or JP',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _setPreference('ph', context),
                  child: Image.asset(
                    'assets/images/philippines.png',
                    width: 75,
                    height: 75,
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(width: 40),
                GestureDetector(
                  onTap: () => _setPreference('jp', context),
                  child: Image.asset(
                    'assets/images/japan.png',
                    width: 75,
                    height: 75,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}