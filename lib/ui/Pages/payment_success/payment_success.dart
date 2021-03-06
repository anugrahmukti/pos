import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity/connectivity.dart';
import 'package:esc_pos_bluetooth/esc_pos_bluetooth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_basic/flutter_bluetooth_basic.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:urawai_pos/core/Models/orderList.dart';
import 'package:urawai_pos/core/Models/transaction.dart';
import 'package:urawai_pos/core/Models/users.dart';
import 'package:urawai_pos/core/Provider/orderList_provider.dart';
import 'package:urawai_pos/core/Provider/postedOrder_provider.dart';
import 'package:urawai_pos/core/Services/connectivity_service.dart';
import 'package:urawai_pos/core/Services/firebase_auth.dart';
import 'package:urawai_pos/core/Services/firestore_service.dart';
import 'package:urawai_pos/core/Services/printer_service.dart';
import 'package:urawai_pos/ui/Widgets/costum_DialogBox.dart';
import 'package:urawai_pos/ui/Widgets/costum_button.dart';
import 'package:urawai_pos/ui/Widgets/footer_OrderList.dart';
import 'package:urawai_pos/ui/utils/constans/formatter.dart';
import 'package:urawai_pos/ui/utils/constans/utils.dart';
import 'package:urawai_pos/ui/utils/functions/paymentHelpers.dart';
import 'package:urawai_pos/ui/utils/functions/routeGenerator.dart';

class PaymentSuccess extends StatefulWidget {
  final String orderID;

  PaymentSuccess({
    @required this.orderID,
  });

  @override
  _PaymentSuccessState createState() => _PaymentSuccessState();
}

class _PaymentSuccessState extends State<PaymentSuccess> {
  final locatorAuth = GetIt.I<FirebaseAuthentication>();
  final locatorFureStore = GetIt.I<FirestoreServices>();

  final ConnectivityService _connectivityService = ConnectivityService();
  bool _isNetworkDisconnected;
  static const int BLUETOOTH_DISCONNECTED = 10;
  int bluetoothStatus;
  BluetoothManager bluetoothManager = BluetoothManager.instance;

  String _shopName = '';
  TransactionOrder _dataTransactionOrder;

  @override
  void initState() {
    super.initState();

    bluetoothManager.state.listen((status) {
      bluetoothStatus = status;
    });

    _connectivityService.networkStatusController.stream
        .listen((connectionStatus) {
      if (connectionStatus == ConnectivityResult.none)
        _isNetworkDisconnected = true;
      else
        _isNetworkDisconnected = false;
    });

    locatorAuth.currentUserXXX.then((data) {
      _shopName = data.shopName;
      _doPrinting(_shopName);
    });

    Hive.openBox<TransactionOrder>('TransactionBox');
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _onTransactionComplete(context),
      child: SafeArea(
        child: Scaffold(
          body: Container(
            child: Row(
              children: <Widget>[
                SizedBox(width: 10),
                //LEFT SIDE

                Expanded(
                  flex: 2,
                  child: Container(
                    // color: Colors.yellow,
                    child: _buildLeftContentTransaction(),
                  ),
                ),

                //RIGHSIDE
                Expanded(
                    flex: 2,
                    child: Container(
                      child: Column(
                        children: <Widget>[
                          SizedBox(height: 20),
                          Container(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: <Widget>[
                                Text(
                                  'Koneksi Bluetooth:',
                                  style: kPriceTextStyle,
                                ),
                                SizedBox(width: 10),
                                StreamBuilder<int>(
                                    stream: bluetoothManager.state,
                                    builder: (context, snapshot) {
                                      if (snapshot.hasError)
                                        return Flexible(
                                          child: Text(snapshot.error.toString(),
                                              style: kPriceTextStyle),
                                        );
                                      if (!snapshot.hasData ||
                                          snapshot.connectionState ==
                                              ConnectionState.waiting)
                                        return Text(
                                          'Loading...',
                                          style: kPriceTextStyle,
                                        );

                                      return snapshot.data ==
                                              BLUETOOTH_DISCONNECTED
                                          ? Text('Tidak Aktif',
                                              style: kPriceTextStyle)
                                          : Text(
                                              'Aktif',
                                              style: kPriceTextStyle,
                                            );
                                    }),
                                SizedBox(width: 10),
                              ],
                            ),
                          ),
                          SizedBox(height: 20),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(
                                Icons.check_circle_outline,
                                size: MediaQuery.of(context).size.width * 0.15,
                                color: Colors.green,
                              ),
                              Text(
                                'Pembayaran Berhasil',
                                style: TextStyle(fontSize: 25),
                              ),
                              SizedBox(height: 20),
                              Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Column(
                                  children: <Widget>[
                                    CostumButton.squareButtonSmall(
                                      'Cetak Kwitansi',
                                      prefixIcon: Icons.print,
                                      onTap: () =>
                                          printStruckWithFeedback(_shopName),
                                    ),
                                    SizedBox(height: 10),
                                    CostumButton.squareButtonSmall(
                                      'Selesai',
                                      prefixIcon: Icons.done,
                                      borderColor: Colors.green,
                                      onTap: () =>
                                          _onTransactionComplete(context),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  StreamBuilder<ConnectivityResult> _buildLeftContentTransaction() {
    return StreamBuilder<ConnectivityResult>(
        stream: ConnectivityService().networkStatusController.stream,
        builder: (builder, snapshot) {
          if (!snapshot.hasData ||
              snapshot.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator());

          return snapshot.data == ConnectivityResult.none
              ? FutureBuilder<TransactionOrder>(
                  future: _getTransactionOrderOffline(widget.orderID),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData ||
                        snapshot.connectionState == ConnectionState.waiting)
                      return Center(child: CircularProgressIndicator());

                    return _buildDetailTransactionFromHiveDb(snapshot.data);
                  },
                )
              : FutureBuilder(
                  future: locatorAuth.currentUserXXX,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData ||
                        snapshot.connectionState == ConnectionState.waiting)
                      return Center(child: CircularProgressIndicator());

                    return _buildDetailTransactionFromFirestore();
                  });
        });
  }

  Future<bool> _doPrinting(String shopName) async {
    var printer = await PrinterService.loadPrinterDevice();

    //* App Still connected to the Internet
    if (_isNetworkDisconnected == false) {
      var _dataPrinting =
          await locatorFureStore.getDocumentByID(_shopName, widget.orderID);

      if (_dataPrinting.data != null) {
        _dataTransactionOrder = TransactionOrder.fromJson(_dataPrinting.data);
      } else {
        print('Tidak ada Data');
      }
    }
    //* App Disconnected from Internet
    else {
      await Hive.openBox<TransactionOrder>('TransactionOrder');
      var transactionBox = Hive.box<TransactionOrder>('TransactionOrder');
      _dataTransactionOrder = transactionBox.get(widget.orderID);
    }

    //* Print if printer has set and bluetooth is active
    if (printer.name != null && bluetoothStatus != BLUETOOTH_DISCONNECTED) {
      PrinterService.printStruck(
        printer: PrinterBluetooth(printer),
        shopName: shopName,
        dataTransaction: _dataTransactionOrder,
      );
      return true;
    } else {
      return false;
    }
  }

  Future<void> printStruckWithFeedback(String shopName) async {
    bool result = await _doPrinting(shopName);

    if (result == false) {
      CostumDialogBox.showDialogInformation(
        context: context,
        title: 'Informasi',
        contentText:
            'Printer Tidak terhubung. \n??? Periksa Koneksi Bluetooth. \n??? Printer belum diset pada pengaturan',
        icon: Icons.bluetooth_disabled,
        iconColor: Colors.blue,
        onTap: () => Navigator.pop(context),
      );
    }
  }

  Future<void> _onTransactionComplete(BuildContext context) {
    //reset variable
    Provider.of<PostedOrderProvider>(context, listen: false)
        .resetFinalPayment();
    Provider.of<OrderListProvider>(context, listen: false).resetFinalPayment();
    Provider.of<OrderListProvider>(context, listen: false).resetOrderList();

    //Navigate to Main Page
    Navigator.pushReplacementNamed(context, RouteGenerator.kRoutePOSPage);

    return null;
  }

  Future<TransactionOrder> _getTransactionOrderOffline(String orderID) async {
    await Hive.openBox<TransactionOrder>('TransactionOrder');
    var transactionBox = Hive.box<TransactionOrder>('TransactionOrder');
    return transactionBox.get(orderID);
  }

  Widget _buildDetailTransactionFromHiveDb(TransactionOrder dataTransaction) {
    int totalOrder = (dataTransaction.itemList.fold(0, (prev, element) {
      return prev + element.quantity;
    }));

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
            border: Border.all(
          width: 1.5,
          color: Colors.grey,
        )),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                FutureBuilder<Users>(
                    future: locatorAuth.currentUserXXX,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData ||
                          snapshot.connectionState == ConnectionState.waiting)
                        return Text(
                          'Loading...',
                          style: kPriceTextStyle,
                        );

                      return Text(_shopName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ));
                    }),
                Divider(
                  thickness: 2,
                ),
                _buildInfoHeader('Order ID: ', dataTransaction.id),
                _buildInfoHeader(
                    'Tanggal: ', Formatter.dateFormat(dataTransaction.date)),
                _buildInfoHeader('Metode Pembayaran:',
                    PaymentHelper.getPaymentType(dataTransaction.paymentType)),
                _buildInfoHeader('Jumlah Pesanan:', totalOrder.toString()),
                Divider(
                  thickness: 2,
                )
              ],
            ),
            Expanded(
              child: ListView.builder(
                  itemCount: dataTransaction.itemList.length,
                  itemBuilder: (context, index) {
                    OrderList itemList = dataTransaction.itemList[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 5.0, horizontal: 5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Expanded(
                            child: Container(
                              child: Row(
                                children: <Widget>[
                                  AutoSizeText(
                                    'x${itemList.quantity}',
                                    style: kPriceTextStyle,
                                  ),
                                  SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      itemList.productName,
                                      style: kPriceTextStyle,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              alignment: Alignment.centerRight,
                              child: AutoSizeText(
                                Formatter.currencyFormat(
                                    itemList.price * itemList.quantity),
                                style: kPriceTextStyle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
            ),
            FooterOrderList(
              dicount: dataTransaction.discount,
              grandTotal: dataTransaction.grandTotal,
              subtotal: dataTransaction.subtotal,
              vat: dataTransaction.vat,
            ),
            Divider(
              thickness: 2,
            ),
            Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: _buildInfoHeader('Pembayaran',
                      Formatter.currencyFormat(dataTransaction.tender)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        'Kembali',
                        style: kPriceTextStyle,
                      ),
                      Text(
                        dataTransaction.paymentType.toString() ==
                                'PaymentType.CASH'
                            ? Formatter.currencyFormat(dataTransaction.change)
                            : 'Rp. 0',
                        style: kPriceTextStyle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTransactionFromFirestore() {
    return FutureBuilder<DocumentSnapshot>(
        future: locatorFureStore.getDocumentByID(_shopName, widget.orderID),
        builder: (context, document) {
          if (!document.hasData ||
              document.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator());

          if (document.data == null) {
            print(document);
            return Center(child: Text('Tidak Ada data..'));
          } else if (document.data.data != null) {
            var dataTransaction = TransactionOrder.fromJson(document.data.data);

            int totalOrder = (dataTransaction.itemList.fold(0, (prev, element) {
              return prev + element.quantity;
            }));

            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                    border: Border.all(
                  width: 1.5,
                  color: Colors.grey,
                )),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(_shopName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            )),
                        Divider(
                          thickness: 2,
                        ),
                        _buildInfoHeader('Order ID: ', dataTransaction.id),
                        _buildInfoHeader('Tanggal: ',
                            Formatter.dateFormat(dataTransaction.date)),
                        _buildInfoHeader(
                            'Metode Pembayaran:',
                            PaymentHelper.getPaymentType(
                                dataTransaction.paymentType)),
                        _buildInfoHeader(
                            'Jumlah Pesanan:', totalOrder.toString()),
                        Divider(
                          thickness: 2,
                        )
                      ],
                    ),
                    Expanded(
                      child: ListView.builder(
                          itemCount: dataTransaction.itemList.length,
                          itemBuilder: (context, index) {
                            OrderList itemList =
                                dataTransaction.itemList[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 5.0, horizontal: 5),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Expanded(
                                    child: Container(
                                      child: Row(
                                        children: <Widget>[
                                          AutoSizeText(
                                            'x${itemList.quantity}',
                                            style: kPriceTextStyle,
                                          ),
                                          SizedBox(width: 5),
                                          Flexible(
                                            child: Text(
                                              itemList.productName,
                                              style: kPriceTextStyle,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      alignment: Alignment.centerRight,
                                      child: AutoSizeText(
                                        Formatter.currencyFormat(
                                            itemList.price * itemList.quantity),
                                        style: kPriceTextStyle,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                    ),
                    FooterOrderList(
                      dicount: dataTransaction.discount,
                      grandTotal: dataTransaction.grandTotal,
                      subtotal: dataTransaction.subtotal,
                      vat: dataTransaction.vat,
                    ),
                    Divider(
                      thickness: 2,
                    ),
                    Column(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: _buildInfoHeader('Pembayaran',
                              Formatter.currencyFormat(dataTransaction.tender)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                'Kembali',
                                style: kPriceTextStyle,
                              ),
                              Text(
                                dataTransaction.paymentType.toString() ==
                                        'PaymentType.CASH'
                                    ? Formatter.currencyFormat(
                                        dataTransaction.change)
                                    : 'Rp. 0',
                                style: kPriceTextStyle,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(height: 20),
              Text('Order ID: ${widget.orderID}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  )),
              Text('Referensi: ${_dataTransactionOrder.referenceOrder}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  )),
              Text(
                  'Total Bayar:' +
                      Formatter.currencyFormat(
                          _dataTransactionOrder.grandTotal),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  )),
              SizedBox(height: 20),
              Text(
                  'Transaksi ini Telah disimpan dalam mode Offline.' +
                      '\n Silahkan Lakukan Sinkronisasi \nPada halaman Pengaturan.',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  )),
            ],
          );
        });
  }

  Widget _buildInfoHeader(String fieldName, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          fieldName,
          style: kPriceTextStyle,
        ),
        SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            style: kPriceTextStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
