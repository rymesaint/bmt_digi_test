import 'dart:io';

import 'package:esc_pos_bluetooth/esc_pos_bluetooth.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:velocity_x/velocity_x.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  final PrinterBluetoothManager printerManager = PrinterBluetoothManager();
  List<PrinterBluetooth> _devices = [];
  PrinterBluetooth? _selectedDevice;
  bool _isScanning = false;
  var options = InAppWebViewSettings(
    useHybridComposition: true,
    useShouldOverrideUrlLoading: true,
    javaScriptEnabled: true,
  );

  @override
  void initState() {
    super.initState();

    printerManager.scanResults.listen((printers) async {
      setState(() {
        _devices = printers;
      });
    });
  }

  void _startScanDevices() async {
    try {
      setState(() {
        _devices = [];
        _isScanning = true;
      });
      if (await Permission.bluetoothScan.request() ==
          PermissionStatus.granted) {
        printerManager.startScan(const Duration(seconds: 30));
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      Get.snackbar('Error', e.toString());
    }
  }

  void _stopScanDevices() {
    try {
      setState(() {
        _isScanning = false;
      });
      printerManager.stopScan();
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      Get.snackbar('Error', e.toString());
    }
  }

  ticket(PaperSize paper, CapabilityProfile profile) {
    final Generator generator = Generator(paper, profile);
    List<int> bytes = [];

    bytes += generator.text(
        'Regular: aA bB cC dD eE fF gG hH iI jJ kK lL mM nN oO pP qQ rR sS tT uU vV wW xX yY zZ');
    // bytes += generator.text('Special 1: àÀ èÈ éÉ ûÛ üÜ çÇ ôÔ',
    //     styles: PosStyles(codeTable: PosCodeTable.westEur));
    // bytes += generator.text('Special 2: blåbærgrød',
    //     styles: PosStyles(codeTable: PosCodeTable.westEur));

    bytes += generator.text('Bold text', styles: const PosStyles(bold: true));
    bytes +=
        generator.text('Reverse text', styles: const PosStyles(reverse: true));
    bytes += generator.text('Underlined text',
        styles: const PosStyles(underline: true), linesAfter: 1);
    bytes += generator.text('Align left',
        styles: const PosStyles(align: PosAlign.left));
    bytes += generator.text('Align center',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('Align right',
        styles: const PosStyles(align: PosAlign.right), linesAfter: 1);

    bytes += generator.row([
      PosColumn(
        text: 'col3',
        width: 3,
        styles: const PosStyles(align: PosAlign.center, underline: true),
      ),
      PosColumn(
        text: 'col6',
        width: 6,
        styles: const PosStyles(align: PosAlign.center, underline: true),
      ),
      PosColumn(
        text: 'col3',
        width: 3,
        styles: const PosStyles(align: PosAlign.center, underline: true),
      ),
    ]);

    bytes += generator.text('Text size 200%',
        styles: const PosStyles(
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ));

    return bytes;
  }

  _showPrinterList() async {
    await Get.dialog(
      VStack(
        [
          Builder(builder: (context) {
            return ElevatedButton(
              onPressed:
                  _isScanning == true ? _stopScanDevices : _startScanDevices,
              child: (_isScanning == true ? 'Stop Scanning' : 'Scan Device')
                  .text
                  .make(),
            );
          }),
          10.heightBox,
          (_devices.isEmpty == true)
              ? 'There are no devices available'.text.center.makeCentered()
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _devices.length,
                  itemBuilder: (context, index) {
                    final printer = _devices[index];
                    return ListTile(
                      title: (printer.name ?? '').text.make(),
                      subtitle: (printer.address ?? '').text.make(),
                      onTap: () {
                        setState(() {
                          _selectedDevice = printer;
                        });
                        printReceipt();
                      },
                    );
                  },
                ).h(100)
        ],
        crossAlignment: CrossAxisAlignment.center,
        alignment: MainAxisAlignment.center,
      ).box.white.width(350).roundedSM.makeCentered(),
    );
  }

  printReceipt() async {
    if (_selectedDevice?.name == null) {
      _showPrinterList();
      return;
    }

    printerManager.selectPrinter(_selectedDevice!);

    const PaperSize paper = PaperSize.mm80;
    final profile = await CapabilityProfile.load();

    // TEST PRINT
    // final PosPrintResult res =
    // await printerManager.printTicket(await testTicket(paper));

    // DEMO RECEIPT
    final PosPrintResult res =
        await printerManager.printTicket((await ticket(paper, profile)));

    print(res.msg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
          child: InAppWebView(
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
    );
  }
}
