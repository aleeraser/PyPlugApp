# PyPlug App

This application represents the top layer in PyPlug software stack. It is meant to be used in pair with a PyPlug's ESP32 equipped with PyPlug's [firmware implementation](https://github.com/Maldus512/PyPlugESP32). While the role of the ESP is to poll values from the PIC MCU, the role of this application is to provide a user-friendly interface to manage one or more PyPlug devices.

The application has been built using Flutter (version 1.0), an open-source framework create by Google which allows the development of cross-platform native Android and iOS applications with a single code base.
You can find more informations on the [official website](http://flutter.io/).

## Requirements

- Mobile operating system:
  - Android: Jelly Bean (API 16) 4.1 or newer; x86 CPUs are not supported a.t.m.
  - iOS: 8 or newer
- All the devices (the mobile phone and the various PyPlug devices) must be connected to the same (wireless) network.

## Capabilities

The application implements two major functionalities for devices: *dicovery* and *management*.

In *device discovery*, available (and compatible) devices are discovered by the means of a UDP broadcast, with a custom payload, over the (wireless) network. Newly discovered devices are presented with a green badge. Every device is displayed with its current address inside the network, as well as the port it's listening on.

In *device management*, the application provides a visual interface for the commands described in [PyPlugESP32 github page](https://github.com/Maldus512/PyPlugESP32). Every command is sent through a TCP socket. In the settings page it is also possible to configure a periodic *update interval* which, if enabled, allows the application to automatically perform periodic update requests to the device.

An sample screenshot of the interface can be found below:

<img src="/assets/images/samples/sample.png" width="350" alt="application_sample">
