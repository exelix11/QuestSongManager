import 'dart:io';

import 'package:bsaberquest/integrations/beatsaver_login_page_pc.dart';
import 'package:flutter/material.dart';

class BeatSaverIntegration {
  static void beginLoginFlow(BuildContext context) {
    if (Platform.isAndroid) {
      throw Exception("Not implemented");
    } else {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => BeatSaverLoginPagePc()));
    }
  }
}
