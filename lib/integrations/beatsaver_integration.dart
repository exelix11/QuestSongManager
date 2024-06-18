import 'dart:io';

import 'package:bsaberquest/integrations/beatsaver_login_page_pc.dart';
import 'package:bsaberquest/integrations/beatsaver_login_page_quest.dart';
import 'package:flutter/material.dart';

class BeatSaverIntegration {
  static Future beginLoginFlow(BuildContext context) async {
    if (Platform.isAndroid) {
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const BeatSaverLoginPageQuest()));
    } else {
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const BeatSaverLoginPagePc()));
    }
  }
}
