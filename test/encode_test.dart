import 'package:bsaberquest/download_manager/oauth_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var original = "test_encoded-string/0987654321";
  var enc = BeatSaverOauthConfig.encode("test_encoded-string/0987654321");

  print(enc);
  print(BeatSaverOauthConfig.encode(enc));

  assert(BeatSaverOauthConfig.encode(enc) == (original));
}
