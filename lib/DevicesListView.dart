import 'dart:async';

import 'package:connectivity/connectivity.dart';
import 'package:flutter/material.dart';

import 'Common.dart';
import 'DeviceDetailsView.dart';
import 'PersistanceHandler.dart';
import 'SocketHandler.dart';

class DevicesListView extends StatefulWidget {
  @override
  _DevicesListViewState createState() => _DevicesListViewState();
}

class _DevicesListViewState extends State<DevicesListView> {
  final PersistanceHandler _persistanceHandler = PersistanceHandler();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SocketHandler _sh = SocketHandler.getInstance();
  final List<Map<String, String>> _devicesList = List();

  bool searching = false;

  Future _discoverDevices() async {
    setState(() {
      searching = true;
    });

    _devicesList.clear();

    var connectivityResult = await (new Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.mobile || connectivityResult == ConnectivityResult.none) {
      showDialog(
          context: context,
          builder: (_) => AlertDialog(
                title: Text('Error'),
                content: Text('You must be connected to a WiFi network.'),
                actions: <Widget>[
                  FlatButton(
                      child: Text(
                        'Close',
                        style: TextStyle(color: Colors.lightBlue[900]),
                      ),
                      onPressed: () {
                        setState(() {
                          searching = false;
                        });
                        Navigator.of(context).pop();
                      }),
                ],
              ));
      setState(() {});
    } else if (connectivityResult == ConnectivityResult.wifi) {
      final Function onDataCallback = (String addr, String macAddr, String port) {
        setState(() {
          var device = {'addr': addr, 'macAddr': macAddr, 'port': port};
          if (!_devicesList.any((element) {
            return element['addr'] == device['addr'] && element['macAddr'] == device['macAddr'] && element['port'] == device['port'];
          })) {
            _devicesList.add(device);
          }
        });
      };

      int broadcastCounter = 0;
      Timer.periodic(Duration(milliseconds: 200), (Timer timer) {
        if (broadcastCounter == 5) {
          timer.cancel();
          setState(() {
            searching = false;
          });
          return;
        }
        broadcastCounter += 1;
        _sh.broadcast(onDataCallback: onDataCallback);
      });
    }
  }

  @override
  void initState() {
    _persistanceHandler.remove('current_device');
    _discoverDevices();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    _devicesList.sort((device1, device2) {
      if (device1['addr'] != null && device2['addr'] != null) {
        // order based on last 8 byte of ip address
        return int.parse(device1['addr'].split('.')[3]).compareTo(int.parse(device2['addr'].split('.')[3]));
      }
      return 0;
    });

    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomPadding: false,
      appBar: AppBar(
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.cancel),
            color: COLOR_ON,
            onPressed: () => PersistanceHandler.getHandler().clear(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            color: COLOR_ON,
            onPressed: searching ? null : () => _discoverDevices(),
          ),
        ],
        title: const Text('Devices'),
        centerTitle: true,
      ),
      body: Stack(
        children: <Widget>[
          searching ? ModalBarrier(dismissible: false, color: Colors.grey[400]) : Container(),
          searching
              ? Center(
                  child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(COLOR_OFF)),
                )
              : Container(),
          Center(
            child: _devicesList.length == 0
                ? searching
                    ? Container()
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          const Text(
                            'No device found.',
                            textAlign: TextAlign.center,
                            style: TextStyle(),
                            textScaleFactor: 1.2,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 20.0),
                            child: Container(
                              width: MediaQuery.of(context).size.width * 1 / 3,
                              height: 45,
                              child: MaterialButton(
                                color: COLOR_OFF,
                                textColor: COLOR_ON,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: <Widget>[
                                    const Text(
                                      'Try again',
                                      textScaleFactor: 1.2,
                                    ),
                                    const Icon(Icons.refresh),
                                  ],
                                ),
                                onPressed: () => _discoverDevices(),
                              ),
                            ),
                          )
                        ],
                      )
                : ListView.builder(
                    itemCount: _devicesList.length * 2,
                    itemBuilder: (context, i) {
                      if ((i).isOdd) return Divider();

                      final String deviceID = _devicesList[(i / 2).truncate()]['macAddr'];
                      final String addr = _devicesList[(i / 2).truncate()]['addr'];
                      final String port = _devicesList[(i / 2).truncate()]['port'];

                      bool isNew = false;

                      String title = 'Unsupported device';
                      String subtitle = 'Missing address and/or port';
                      TextStyle style = TextStyle(color: Colors.grey);
                      Function onTap;

                      if (deviceID != null && addr != null && port != null) {
                        if (_persistanceHandler.get(deviceID) == null) {
                          debugPrint('New device \'$deviceID\' with address: $addr, port: $port ');
                        }

                        _persistanceHandler.setForDevice(deviceID, 'address', addr);
                        _persistanceHandler.setForDevice(deviceID, 'port', port);

                        if (_persistanceHandler.getFromDevice(deviceID, 'device_name') == null) {
                          isNew = true;
                          title = 'Socket Device';
                        } else {
                          title = _persistanceHandler.getFromDevice(deviceID, 'device_name');
                        }

                        subtitle = 'Network address: $addr:$port';
                        style = null;
                        onTap = () {
                          _persistanceHandler.setString('current_device', deviceID);

                          Navigator.of(context)
                              .push(MaterialPageRoute(
                                  builder: (BuildContext context) => DeviceDetailsView(
                                        deviceID: deviceID,
                                      )))
                              .whenComplete(() {
                            _persistanceHandler.remove('current_device');
                            _discoverDevices();
                          });
                        };
                      }

                      return Padding(
                        padding: const EdgeInsets.only(left: 20, top: 5, bottom: 5),
                        child: ListTile(
                          title: Text(
                            title,
                            style: style,
                          ),
                          subtitle: Text(
                            subtitle,
                            style: style,
                          ),
                          onTap: onTap,
                          trailing: isNew
                              ? Icon(
                                  Icons.new_releases,
                                  color: Colors.green[600],
                                )
                              : null,
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }
}
