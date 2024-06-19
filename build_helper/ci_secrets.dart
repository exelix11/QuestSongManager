// Replace CI secrets from env vars in a safe way
// ignore_for_file: avoid_print

import 'dart:io';

void main(List<String> args) {
  final Map<String, String> envVars = Platform.environment;

  var source = envVars['REPLACE_FROM'];
  var target = envVars['REPLACE_TO'];

  if (source == null || target == null) {
    print("REPLACE_FROM and REPLACE_TO must be set");
    exit(1);
  }

  if (args.isEmpty) {
    print("Usage: ci_secrets.dart <file>");
    exit(1);
  }

  var file = File(args[0]);
  if (!file.existsSync()) {
    print("File not found: ${args[0]}");
    exit(1);
  }

  var content = file.readAsStringSync();
  content = content.replaceAll(source, target);
  file.writeAsStringSync(content);
}
