import 'dart:io';

import 'package:bluetooth_print/bluetooth_print.dart';
import 'package:bluetooth_print/bluetooth_print_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:velocity_x/velocity_x.dart';

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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  final BluetoothPrint bluetoothPrint = BluetoothPrint.instance;
  BluetoothDevice? _selectedDevice;
  var options = InAppWebViewSettings(
    useHybridComposition: true,
    useShouldOverrideUrlLoading: true,
    javaScriptEnabled: true,
  );
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => initBluetooth());
  }

  @override
  void dispose() {
    bluetoothPrint.disconnect();
    super.dispose();
  }

  Future<void> initBluetooth() async {
    bluetoothPrint.startScan(timeout: const Duration(seconds: 4));

    bool isConnected = await bluetoothPrint.isConnected ?? false;

    bluetoothPrint.state.listen((state) {
      print('******************* cur device status: $state');

      switch (state) {
        case BluetoothPrint.CONNECTED:
          setState(() {
            _connected = true;
          });
          break;
        case BluetoothPrint.DISCONNECTED:
          setState(() {
            _connected = false;
          });
          break;
        default:
          break;
      }
    });

    if (!mounted) return;

    if (isConnected) {
      print('connected');
      setState(() {
        _connected = true;
      });
    }
  }

  _showPrinterList() async {
    await Get.dialog(
      Dialog(
        child: VStack(
          [
            StreamBuilder<List<BluetoothDevice>>(
              initialData: const [],
              stream: bluetoothPrint.scanResults,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.none ||
                    snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator(
                    color: Vx.amber500,
                  ).centered();
                }
                if (!snapshot.hasData) {
                  return ListTile(
                    title: 'No devices detected.'.text.black.make(),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: snapshot.data?.length ?? 0,
                  itemBuilder: (context, index) {
                    final device = snapshot.data?[index];
                    return ListTile(
                      onTap: () async {
                        try {
                          setState(() {
                            _selectedDevice = device;
                          });
                          if (Get.isDialogOpen!) {
                            Get.back();
                          }
                        } catch (e) {
                          Get.snackbar('Error', e.toString());
                        }
                      },
                      title:
                          '${device?.name ?? ''} ${device?.connected == true ? '(Connected)' : ''}'
                              .text
                              .black
                              .make(),
                      subtitle: (device?.address ?? '').text.black.make(),
                      trailing: _selectedDevice != null &&
                              _selectedDevice!.address == device?.address
                          ? const Icon(
                              Icons.check,
                              color: Colors.green,
                            )
                          : null,
                    );
                  },
                );
              },
            ).h(100)
          ],
          crossAlignment: CrossAxisAlignment.center,
          alignment: MainAxisAlignment.center,
        ),
      ).box.black.width(350).roundedSM.makeCentered(),
    );
  }

  Map<String, dynamic> _setConfig() {
    return {
      'width': 58,
      'height': 30,
      'gap': 2,
    };
  }

  List<LineText> _setData() {
    List<LineText> list = [];
    list.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'A Title',
        weight: 1,
        align: LineText.ALIGN_CENTER,
        linefeed: 1));
    list.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'this is conent left',
        weight: 0,
        align: LineText.ALIGN_LEFT,
        linefeed: 1));
    list.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'this is conent right',
        align: LineText.ALIGN_RIGHT,
        linefeed: 1));
    list.add(LineText(linefeed: 1));
    list.add(LineText(
        type: LineText.TYPE_BARCODE,
        content: 'A12312112',
        size: 10,
        align: LineText.ALIGN_CENTER,
        linefeed: 1));
    list.add(LineText(linefeed: 1));
    list.add(LineText(
        type: LineText.TYPE_QRCODE,
        content: 'qrcode i',
        size: 10,
        align: LineText.ALIGN_CENTER,
        linefeed: 1));
    list.add(LineText(linefeed: 1));

    return list;
  }

  printReceipt() async {
    try {
      await _showPrinterList();

      if (_selectedDevice?.connected == false) {
        await bluetoothPrint.connect(_selectedDevice!);
      }
      await bluetoothPrint.printReceipt(_setConfig(), _setData());
    } catch (e) {
      Get.snackbar('error', e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () =>
            bluetoothPrint.startScan(timeout: const Duration(seconds: 4)),
        child: Center(
            child: InAppWebView(
          onWebContentProcessDidTerminate: (controller) {
            print('stopped');
          },
          onUpdateVisitedHistory: (controller, url, isReload) {
            if (url?.hasQuery == true) {
              Map<String, String>? params = url?.queryParameters;

              String? nodeId = params?['node-id'];
              if (nodeId == '313:5801') {
                printReceipt();
              }
            }
          },
          initialUrlRequest: URLRequest(
              url: WebUri.uri(Uri.parse(
                  'https://www.figma.com/proto/0PqqYSONnW3eMxD8GRZ4SO/BMT-Digi?node-id=313%3A9960&scaling=scale-down&page-id=147%3A1399&starting-point-node-id=313%3A9960'))),
          initialSettings: options,
        )),
      ),
      // floatingActionButton: StreamBuilder<bool>(
      //   stream: bluetoothPrint.isScanning,
      //   initialData: false,
      //   builder: (c, snapshot) {
      //     if (snapshot.data == true) {
      //       return FloatingActionButton(
      //         onPressed: () => bluetoothPrint.stopScan(),
      //         backgroundColor: Colors.red,
      //         child: const Icon(Icons.stop),
      //       );
      //     } else {
      //       return FloatingActionButton(
      //           child: const Icon(Icons.search),
      //           onPressed: () => printReceipt());
      //     }
      //   },
      // ),
    );
  }
}
