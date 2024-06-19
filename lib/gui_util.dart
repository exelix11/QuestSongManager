import 'package:bsaberquest/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class GuiUtil {
  static Future<String?> textInputDialog(BuildContext context, String prompt,
      {String? defaultValue}) async {
    final TextEditingController controller = TextEditingController();
    if (defaultValue != null) {
      controller.text = defaultValue;
    }
    return showDialog<String?>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(prompt),
          content: TextField(
            controller: controller,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(controller.text);
              },
            ),
          ],
        );
      },
    );
  }

  static Future<Future<T>?> loadingDialog<T>(
      BuildContext context, String message, Future<T> future) async {
    return showDialog<Future<T>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(message),
          content: FutureBuilder(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                if (snapshot.hasError) {
                  App.showToast(snapshot.error.toString());
                }

                // Schedule a pop to happen after the toast
                SchedulerBinding.instance.addPostFrameCallback((_) {
                  Navigator.of(context).pop();
                });
              }
              return const Center(
                  child: SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator()));
            },
          ),
        );
      },
    );
  }

  static Future<bool?> confirmChoice(
      BuildContext context, String title, String content) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                Text(content),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Yes'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  static Future longTextDialog(
      BuildContext context, String title, String message) {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Text(message),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  static EdgeInsets defaultViewPadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600; // Change this value as needed
    final padding = isLargeScreen ? 40.0 : 10.0;
    return EdgeInsets.only(left: padding, right: padding);
  }
}
