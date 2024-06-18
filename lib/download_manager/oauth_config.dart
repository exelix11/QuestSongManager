class BeatSaverOauthConfig {
  // Filled by build script
  static const String _CLIENT_ID = "######CLIENT_ID######";
  static const String _CLIENT_SECRET = "######CLIENT_SECRET######";
  static const String REDIRECT_URL = "questsongmanager://beatsaver_auth";

  static bool get isConfigured =>
      !_CLIENT_ID.contains("CLIENT_ID") &&
      !_CLIENT_SECRET.contains("CLIENT_SECRET");

  static String encode(String s) {
    const int ascii_start = 0x21;
    const int ascii_end = 0x7D; // 7D so it's even
    const int range = (ascii_end - ascii_start) ~/ 2;
    const int middle = ascii_start + range;
    List<int> map = [];

    for (var char in s.codeUnits) {
      if (char >= ascii_start && char <= ascii_end) {
        if (char > middle) {
          map.add(char - range);
        } else if (char < middle) {
          map.add(char + range);
        }
      } else {
        map.add(char);
      }
    }

    return String.fromCharCodes(map);
  }

  static String get clientId {
    if (!isConfigured) {
      throw Exception("BeatSaverOauthConfig is not configured in this build");
    }

    return encode(_CLIENT_ID);
  }

  static String get clientSecret {
    if (!isConfigured) {
      throw Exception("BeatSaverOauthConfig is not configured in this build");
    }

    return encode(_CLIENT_SECRET);
  }
}
