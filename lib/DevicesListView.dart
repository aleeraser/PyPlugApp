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
  final List<Map<String, String>> _devicesList = List(); //[{'addr': null, 'macAddr': null, 'port': null}];

  void _discoverDevices() {
    _devicesList.clear();

    final Function onDataCallback = (String addr, String macAddr, String port) {
      setState(() {
        var device = {'addr': addr, 'macAddr': macAddr, 'port': port};
        _devicesList.add(device);
      });
    };

    // TODO: ripeti il broadcast 3-4 volte per ovviare alla perdita di pacchetti, e aggiungi la richiesta a 192.168.4.1

    // Future.delayed(const Duration(milliseconds: 200), () {
    //   _sh.broadcast(onDataCallback: onDataCallback);
    // });

    _sh.broadcast(onDataCallback: onDataCallback);
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
            onPressed: () => _discoverDevices(),
          ),
        ],
        title: const Text('Devices'),
        centerTitle: true,
      ),
      body: Center(
        child: _devicesList.length == 0
            ? Column(
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

                  Widget title = Text('Unknown device');
                  Widget subtitle = Text('Missing address and/or port');
                  Function onTap;

                  if (deviceID != null && addr != null && port != null) {
                    if (_persistanceHandler.get(deviceID) == null) {
                      debugPrint('New device \'$deviceID\' with address: $addr, port: $port ');
                    }

                    _persistanceHandler.setForDevice(deviceID, 'address', addr);
                    _persistanceHandler.setForDevice(deviceID, 'port', port);

                    if (_persistanceHandler.getFromDevice(deviceID, 'device_name') == null) {
                      isNew = true;
                    }

                    title = Text(_persistanceHandler.getFromDevice(deviceID, 'device_name') != null ? _persistanceHandler.getFromDevice(deviceID, 'device_name') : 'Socket Device');
                    subtitle = Text('Network address: $addr:$port');
                    onTap = () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (BuildContext context) => DeviceDetailsView(
                                deviceID: deviceID,
                              )));
                    };
                  }

                  return Padding(
                    padding: const EdgeInsets.only(left: 20, top: 5, bottom: 5),
                    child: ListTile(
                      title: title,
                      subtitle: subtitle,
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
      ),
      // backgroundColor: COLOR_ON,
    );
  }
}
