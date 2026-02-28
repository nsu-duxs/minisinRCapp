import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';

void main() => runApp(const MaterialApp(home: BLEApp()));

class BLEApp extends StatefulWidget {
  const BLEApp({super.key});

  @override
  _BLEAppState createState() => _BLEAppState();
}

class _BLEAppState extends State<BLEApp> {
  List<ScanResult> scanResults = [];
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    // Monitorar o estado do Bluetooth
    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        print("Bluetooth está ligado!");
      }
    });
  }

  // Iniciar Escaneamento
  void startScan() async {
    setState(() => isScanning = true);
    
    // Escaneia por 5 segundos
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        scanResults = results;
      });
    });

    await FlutterBluePlus.isScanning.where((val) => val == false).first;
    setState(() => isScanning = false);
  }

  // Conectar ao Dispositivo
  void connectToDevice(BluetoothDevice device) async {
    await device.connect(license: License.free);
    print("Conectado a ${device.platformName}");

    // Descobrir Serviços
    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      print("Serviço encontrado: ${service.uuid}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Flutter BLE Connect")),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: isScanning ? null : startScan,
            child: Text(isScanning ? "Escaneando..." : "Buscar Servidor BLE"),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: scanResults.length,
              itemBuilder: (context, index) {
                final data = scanResults[index];
                return ListTile(
                  title: Text(data.device.platformName.isEmpty ? "Dispositivo Desconhecido" : data.device.platformName),
                  subtitle: Text(data.device.remoteId.toString()),
                  trailing: ElevatedButton(
                    onPressed: () => connectToDevice(data.device),
                    child: const Text("Conectar"),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}