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
    _sh.broadcast(onDataCallback: (String addr, String macAddr, String port) {
      setState(() {
        var device = {'addr': addr, 'macAddr': macAddr, 'port': port};
        _devicesList.add(device);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
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

                  Widget title = Text('Unknown device');
                  Widget subtitle = Text('Missing address and/or port');
                  Function onTap;

                  if (deviceID != null && addr != null && port != null) {
                    if (_persistanceHandler.get(deviceID) == null) {
                      debugPrint('Inserting device \'$deviceID\' with address: $addr, port: $port ');
                      _persistanceHandler.setForDevice(deviceID, 'device_name', 'Socket Device');
                    }
                    _persistanceHandler.setForDevice(deviceID, 'address', addr);
                    _persistanceHandler.setForDevice(deviceID, 'port', port);

                    title = Text(_persistanceHandler.getFromDevice(deviceID, 'device_name'));
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
                    ),
                  );
                },
              ),
      ),
      // backgroundColor: COLOR_ON,
    );
  }
}
