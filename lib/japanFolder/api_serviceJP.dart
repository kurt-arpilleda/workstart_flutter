import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';

class ApiService {
  static const List<String> apiUrls = [
    "http://192.168.1.213/",
    "http://220.157.175.232/"
  ];

  static const Duration requestTimeout = Duration(seconds: 2);
  static const int maxRetries = 6;
  static const Duration initialRetryDelay = Duration(seconds: 1);

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
    );
  }

  Future<http.Response> _makeRequest(Uri uri, {Map<String, String>? headers, int retries = maxRetries}) async {
    for (int attempt = 1; attempt <= retries; attempt++) {
      for (String apiUrl in apiUrls) {
        try {
          final fullUri = Uri.parse(apiUrl).resolve(uri.toString());
          final response = await http.get(fullUri, headers: headers).timeout(requestTimeout);
          return response;
        } catch (e) {
          // print("Error accessing $apiUrl on attempt $attempt: $e");
        }
      }
      // If all servers fail, wait for an exponential backoff delay before retrying
      if (attempt < retries) {
        final delay = initialRetryDelay * (1 << (attempt - 1)); // Exponential backoff
        // print("Waiting for ${delay.inSeconds} seconds before retrying...");
        await Future.delayed(delay);
      }
    }
    throw Exception("All API URLs are unreachable after $retries attempts");
  }

  Future<String> fetchSoftwareLink(int linkID) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? idNumber = prefs.getString('IDNumberJP');

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      for (int i = 0; i < apiUrls.length; i++) {
        String apiUrl = apiUrls[i];
        try {
          final uri = Uri.parse("${apiUrl}V4/Others/Kurt/ArkLinkAPI/kurt_fetchLink.php?linkID=$linkID");
          final response = await http.get(uri).timeout(requestTimeout);

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data.containsKey("softwareLink")) {
              String relativePath = data["softwareLink"];
              String fullUrl = Uri.parse(apiUrl).resolve(relativePath).toString();
              if (idNumber != null) {
                fullUrl += "?idNumber=$idNumber";
              }
              return fullUrl;
            } else {
              throw Exception(data["error"]);
            }
          }
        } catch (e) {
          String errorMessage = "Error accessing $apiUrl on attempt $attempt";
          print(errorMessage);
          // _showToast(errorMessage);

          // If the first URL fails and there's another URL to try, show a fallback message
          if (i == 0 && apiUrls.length > 1) {
            // _showToast("Falling back to ${apiUrls[1]}");
          }
        }
      }
      // If all servers fail, wait for an exponential backoff delay before retrying
      if (attempt < maxRetries) {
        final delay = initialRetryDelay * (1 << (attempt - 1)); // Exponential backoff
        String retryMessage = "Waiting for ${delay.inSeconds} seconds before retrying...";
        print(retryMessage);
        // _showToast(retryMessage);
        await Future.delayed(delay);
      }
    }
    String finalError = "All API URLs are unreachable after $maxRetries attempts";
    // _showToast(finalError);
    throw Exception(finalError);
  }
  Future<bool> checkIdNumber(String idNumber) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      for (String apiUrl in apiUrls) {
        try {
          final uri = Uri.parse("${apiUrl}V4/Others/Kurt/ArkLinkAPI/kurt_checkIdNumber.php");
          final response = await http.post(
            uri,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"idNumber": idNumber}),
          ).timeout(requestTimeout);

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data["success"] == true) {
              return true;
            } else {
              throw Exception(data["message"]);
            }
          }
        } catch (e) {
          // print("Error accessing $apiUrl on attempt $attempt: $e");
        }
      }
      // If all servers fail, wait for an exponential backoff delay before retrying
      if (attempt < maxRetries) {
        final delay = initialRetryDelay * (1 << (attempt - 1)); // Exponential backoff
        // print("Waiting for ${delay.inSeconds} seconds before retrying...");
        await Future.delayed(delay);
      }
    }
    throw Exception("Both API URLs are unreachable after $maxRetries attempts");
  }

  Future<Map<String, dynamic>> fetchProfile(String idNumber) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      for (String apiUrl in apiUrls) {
        try {
          final uri = Uri.parse("${apiUrl}V4/Others/Kurt/ArkLinkAPI/kurt_fetchProfile.php?idNumber=$idNumber");
          final response = await http.get(uri).timeout(requestTimeout);

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data["success"] == true) {
              return data;
            } else {
              throw Exception(data["message"]);
            }
          }
        } catch (e) {
          // print("Error accessing $apiUrl on attempt $attempt: $e");
        }
      }
      // If all servers fail, wait for an exponential backoff delay before retrying
      if (attempt < maxRetries) {
        final delay = initialRetryDelay * (1 << (attempt - 1)); // Exponential backoff
        // print("Waiting for ${delay.inSeconds} seconds before retrying...");
        await Future.delayed(delay);
      }
    }
    throw Exception("Both API URLs are unreachable after $maxRetries attempts");
  }

  Future<void> updateLanguageFlag(String idNumber, int languageFlag) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      for (String apiUrl in apiUrls) {
        try {
          final uri = Uri.parse("${apiUrl}V4/Others/Kurt/ArkLinkAPI/kurt_updateLanguage.php");
          final response = await http.post(
            uri,
            body: {
              'idNumber': idNumber,
              'languageFlag': languageFlag.toString(),
            },
          ).timeout(requestTimeout);

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data["success"] == true) {
              return;
            } else {
              throw Exception(data["message"]);
            }
          }
        } catch (e) {
          // print("Error accessing $apiUrl on attempt $attempt: $e");
        }
      }
      // If all servers fail, wait for an exponential backoff delay before retrying
      if (attempt < maxRetries) {
        final delay = initialRetryDelay * (1 << (attempt - 1)); // Exponential backoff
        // print("Waiting for ${delay.inSeconds} seconds before retrying...");
        await Future.delayed(delay);
      }
    }
    throw Exception("Both API URLs are unreachable after $maxRetries attempts");
  }
}