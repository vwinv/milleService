//import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class Cookies {
  static var prefs;

  void newInstance() async {
    prefs ??= await SharedPreferences.getInstance();
  }

  void myUsercookies(String user, String id) {
    prefs!.setString("user", user);
    prefs!.setString("id", id);
  }

  void saveToken(String token) {
    prefs!.setString("token", token);
  }

  void saveRToken(String token) {
    prefs!.setString("Rtoken", token);
  }

  Future<String?> getMyToken() async {
    return prefs!.getString("token");
  }

  Future<String?> getMyRToken() async {
    return prefs!.getString("Rtoken");
  }

  Future<String?> getMyuserCookies() async {
    return prefs!.getString("user");
  }

  void removeCookie() {
    prefs!.clear();
  }
}
