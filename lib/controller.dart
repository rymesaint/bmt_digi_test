import 'dart:convert';

import 'package:bluetooth_print/bluetooth_print.dart';
import 'package:bluetooth_print/bluetooth_print_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:velocity_x/velocity_x.dart';

class Controller extends GetxController {
  final BluetoothPrint bluetoothPrint = BluetoothPrint.instance;
  final _selectedDevice = BluetoothDevice().obs;
  final options = InAppWebViewSettings(
    useHybridComposition: true,
    useShouldOverrideUrlLoading: true,
    javaScriptEnabled: true,
  );
  late final InAppWebViewController webViewController;

  final _connected = false.obs;
  final webUri = WebUri.uri(Uri.parse(
      'https://www.figma.com/proto/0PqqYSONnW3eMxD8GRZ4SO/BMT-Digi?node-id=313%3A9960&scaling=scale-down&page-id=147%3A1399&starting-point-node-id=313%3A9960'));

  @override
  void onInit() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _initBluetooth());
    super.onInit();
  }

  _initBluetooth() async {
    bluetoothPrint.startScan(timeout: const Duration(seconds: 4));

    bool isConnected = await bluetoothPrint.isConnected ?? false;

    bluetoothPrint.state.listen((state) {
      debugPrint('******************* cur device status: $state');
      switch (state) {
        case BluetoothPrint.CONNECTED:
          _connected(true);
          Get.snackbar('Info', 'Device connected',
              backgroundColor: Colors.green);
          break;
        case BluetoothPrint.DISCONNECTED:
          _connected(false);
          break;
        default:
          break;
      }
    });
    if (isConnected) {
      _connected(true);
    }
  }

  onLoadStart(InAppWebViewController controller, WebUri? uri) {
    webViewController = controller;
  }

  onUpdateVisited(
      InAppWebViewController controller, WebUri? url, bool? isReload) {
    if (url?.hasQuery == true) {
      Map<String, String>? params = url?.queryParameters;

      String? nodeId = params?['node-id'];
      if (nodeId == '313:5801') {
        printReceipt();
      }
    }
  }

  _connectToDevice() async {
    try {
      if (_selectedDevice.value.address == null) {
        Get.snackbar('Error', 'There are no device selected yet.');
        return;
      }
      var connect = await bluetoothPrint.connect(_selectedDevice.value);
      _connected(connect);
    } catch (e) {
      Get.snackbar('Error', e.toString());
    }
  }

  connectPrinter() async {
    if (_selectedDevice.value.address == null) {
      await _showPrinterList();
      await _connectToDevice();
    } else {
      _connectToDevice();
    }
  }

  printReceipt() async {
    try {
      if (_selectedDevice.value.address == null) {
        throw Exception('There are no device selected yet.');
      }

      if (!_connected.value) {
        await _connectToDevice();
      }

      ByteData data = await rootBundle.load("assets/images/bmt.png");
      List<int> imageBytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      String base64Image = base64Encode(imageBytes);

      Future.delayed(const Duration(milliseconds: 700), () async {
        await bluetoothPrint.printReceipt(_setConfig(), _setData(base64Image));
      });
    } on PlatformException catch (e) {
      Get.snackbar('error', e.toString(), backgroundColor: Colors.red);
    } on Exception catch (e) {
      Get.snackbar('error', e.toString(), backgroundColor: Colors.red);
    }
  }

  Map<String, dynamic> _setConfig() {
    return {
      'width': 58,
      'height': 30,
      'gap': 2,
    };
  }

  List<LineText> _setPrintHeader(String imageBase64) {
    return [
      LineText(
        type: LineText.TYPE_IMAGE,
        content: imageBase64,
        align: LineText.ALIGN_CENTER,
        width: 320,
        height: 320,
        linefeed: 1,
      ),
      LineText(linefeed: 1),
      LineText(
          type: LineText.TYPE_TEXT,
          content: 'Jl. Pondok Kelapa No.123',
          align: LineText.ALIGN_CENTER,
          linefeed: 1),
      LineText(
          type: LineText.TYPE_TEXT,
          content: 'Duren Sawit Jakarta Timur',
          align: LineText.ALIGN_CENTER,
          linefeed: 1),
      LineText(
          type: LineText.TYPE_TEXT,
          content: 'Telp. 021-1234567',
          align: LineText.ALIGN_CENTER,
          linefeed: 1),
    ];
  }

  List<LineText> _setSeparator({bool useNewLine = false}) {
    return [
      LineText(
          type: LineText.TYPE_TEXT,
          content: '--------------------------------',
          linefeed: 1),
      if (useNewLine == true) LineText(linefeed: 1)
    ];
  }

  List<LineText> _setReceiptInfo({
    required String receiptNumber,
    required String cashierName,
    required String date,
  }) {
    return [
      LineText(
          type: LineText.TYPE_TEXT,
          content: 'No #  : $receiptNumber',
          linefeed: 1),
      LineText(
          type: LineText.TYPE_TEXT,
          content: 'Kasir : $cashierName',
          linefeed: 1),
      LineText(
          type: LineText.TYPE_TEXT, content: 'Tanggal : $date', linefeed: 1),
    ];
  }

  List<LineText> _addHeaderItems() {
    return [
      LineText(
          type: LineText.TYPE_TEXT,
          content: 'Nama Barang',
          weight: 1,
          relativeX: 0,
          linefeed: 0),
      LineText(
          type: LineText.TYPE_TEXT,
          content: 'Qty',
          weight: 1,
          relativeX: 240,
          linefeed: 0),
      LineText(
          type: LineText.TYPE_TEXT,
          content: 'Jumlah',
          weight: 1,
          relativeX: 300,
          linefeed: 0),
      LineText(linefeed: 1),
    ];
  }

  List<LineText> _setItem(
      {required String itemName, required int qty, required String amount}) {
    return [
      LineText(
          type: LineText.TYPE_TEXT,
          content: itemName,
          relativeX: 0,
          linefeed: 0),
      LineText(
          type: LineText.TYPE_TEXT,
          content: qty.toString(),
          relativeX: 240,
          linefeed: 0),
      LineText(
          align: LineText.ALIGN_RIGHT,
          type: LineText.TYPE_TEXT,
          content: amount,
          relativeX: 300,
          linefeed: 0),
      LineText(linefeed: 1),
    ];
  }

  List<LineText> _paymentInformation({
    required int totalItem,
    required String totalAmount,
    required String totalPayment,
    required String methodPayment,
    required String change,
  }) {
    return [
      LineText(
          align: LineText.ALIGN_RIGHT,
          type: LineText.TYPE_TEXT,
          content: 'Total Barang : $totalItem',
          linefeed: 1),
      LineText(
          align: LineText.ALIGN_RIGHT,
          type: LineText.TYPE_TEXT,
          content: 'Total Harga : $totalAmount',
          linefeed: 1),
      LineText(
          align: LineText.ALIGN_RIGHT,
          type: LineText.TYPE_TEXT,
          content: 'Total Bayar : $totalPayment',
          linefeed: 1),
      LineText(
          align: LineText.ALIGN_RIGHT,
          type: LineText.TYPE_TEXT,
          content: 'Metode Pembayaran : $methodPayment',
          linefeed: 1),
      LineText(
          align: LineText.ALIGN_RIGHT,
          type: LineText.TYPE_TEXT,
          content: 'Kembali : $change',
          linefeed: 1),
      LineText(linefeed: 1),
      LineText(linefeed: 1),
    ];
  }

  List<LineText> _setFooter() {
    return [
      LineText(
          align: LineText.ALIGN_CENTER,
          type: LineText.TYPE_TEXT,
          content: 'Terima kasih telah berbelanja di BMT Digi.',
          linefeed: 1),
      LineText(
          align: LineText.ALIGN_CENTER,
          type: LineText.TYPE_TEXT,
          content: 'Barang yang sudah dibeli ',
          linefeed: 1),
      LineText(
          align: LineText.ALIGN_CENTER,
          type: LineText.TYPE_TEXT,
          content: 'tidak bisa ditukar atau dikembalikan.',
          linefeed: 1),
      LineText(linefeed: 1),
      LineText(linefeed: 1),
    ];
  }

  List<LineText> _setData(String imageBase64) {
    List<LineText> list = [];
    list.addAll(_setPrintHeader(imageBase64));
    list.addAll(_setSeparator(useNewLine: true));
    list.addAll(_setReceiptInfo(
        receiptNumber: '01.01.2023.0001',
        cashierName: 'Asep Saepudin',
        date: '01 Januari 2023 10:30 WIB'));
    list.addAll(_setSeparator());
    list.addAll(_addHeaderItems());
    list.addAll(_setItem(
        itemName: 'Susu Milo Kaleng\n1.5 Kg', qty: 1, amount: '134.000'));
    list.addAll(
        _setItem(itemName: 'Sari Roti Tawar\n200g', qty: 1, amount: '39.000'));
    list.addAll(_setItem(
        itemName: 'Minyak Goreng Kelapa\nSawit Sania 1L',
        qty: 1,
        amount: '31.000'));
    list.addAll(_setSeparator());
    list.addAll(_paymentInformation(
        totalItem: 3,
        totalAmount: '204.000',
        totalPayment: '300.000',
        methodPayment: 'CASH',
        change: '96.000'));
    list.addAll(_setFooter());
    return list;
  }

  _selectDevice(BluetoothDevice? device) {
    try {
      _selectedDevice(device);
      if (Get.isDialogOpen!) {
        Get.back();
      }
    } catch (e) {
      Get.snackbar('Error', e.toString());
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
                    return Obx(
                      () => ListTile(
                        onTap: () => _selectDevice(device),
                        title:
                            '${device?.name ?? ''} ${device?.connected == true ? '(Connected)' : ''}'
                                .text
                                .black
                                .make(),
                        subtitle: (device?.address ?? '').text.black.make(),
                        trailing:
                            _selectedDevice.value.address == device?.address
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.green,
                                  )
                                : null,
                      ),
                    );
                  },
                );
              },
            ).h(100)
          ],
          crossAlignment: CrossAxisAlignment.center,
          alignment: MainAxisAlignment.center,
        ),
      ).box.black.width(350).height(150).roundedSM.makeCentered(),
    );
  }
}
