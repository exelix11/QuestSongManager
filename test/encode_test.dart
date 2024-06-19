// ignore_for_file: avoid_print

import 'package:bsaberquest/download_manager/oauth_config.dart';

void main() {
  var original = "test_encoded-string/0987654321";
  var enc = BeatSaverOauthConfig.encode("test_encoded-string/0987654321");

  print(enc);
  print(BeatSaverOauthConfig.encode(enc));

  assert(BeatSaverOauthConfig.encode(enc) == (original));
}
