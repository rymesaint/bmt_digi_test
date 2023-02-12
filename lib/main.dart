import 'dart:io';

import 'package:bmt_digi/controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Permission.bluetoothConnect.request();
  await Permission.bluetoothScan.request();
  await Permission.locationWhenInUse.request();

  if (Platform.isAndroid) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  runApp(
    const GetMaterialApp(
      home: MyApp(),
    ),
  );
}

class MyApp extends GetView<Controller> {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(Controller());
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => controller.webViewController
              .loadUrl(urlRequest: URLRequest(url: controller.webUri)),
          child: Center(
              child: InAppWebView(
            onLoadStart: controller.onLoadStart,
            onUpdateVisitedHistory: controller.onUpdateVisited,
            initialUrlRequest: URLRequest(
              url: controller.webUri,
            ),
            initialSettings: controller.options,
          )),
        ),
      ),
      floatingActionButton: StreamBuilder<bool>(
        stream: controller.bluetoothPrint.isScanning,
        initialData: false,
        builder: (c, snapshot) {
          if (snapshot.data == true) {
            return FloatingActionButton(
              onPressed: () => controller.bluetoothPrint.stopScan(),
              backgroundColor: Colors.red,
              child: const Icon(Icons.stop),
            );
          } else {
            return FloatingActionButton(
                child: const Icon(Icons.cast_connected),
                onPressed: () => controller.connectPrinter());
          }
        },
      ),
    );
  }
}
