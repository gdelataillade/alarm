import 'package:shared_preferences/shared_preferences.dart';

class SharedPreference {
  static late SharedPreferences prefs;

  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
  }

  static Future<void> setLoopAudio(bool value) async {
    await prefs.setBool('loop', value);
  }

  static bool getLoopAudio() {
    return prefs.getBool('loop') ?? false;
  }

  static Future<void> setAudioAssets(String value) async {
    await prefs.setString('audioAssets', value);
  }

  static String getAudioAssets() {
    return prefs.getString('audioAssets') ?? '';
  }
}
