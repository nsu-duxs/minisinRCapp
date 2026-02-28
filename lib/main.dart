import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';

void main() => runApp(const MaterialApp(home: BLEWriteApp()));

class BLEWriteApp extends StatefulWidget {
  const BLEWriteApp({super.key});

  @override
  _BLEWriteAppState createState() => _BLEWriteAppState();
}

class _BLEWriteAppState extends State<BLEWriteApp> {
  BluetoothDevice? connectedDevice;
  List<ScanResult> scanResults = [];
  bool isScanning = false;
  
  // Controlador para o campo de texto
  final TextEditingController _valueController = TextEditingController();

  // --- COLOQUE SEUS UUIDS AQUI ---
  final String targetServiceUuid = "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad"; // Exemplo
  final String targetCharacteristicUuid = "aff04f40-41ab-493c-925d-37f4b2d92325"; // Exemplo

  @override
  void initState() {
    super.initState();
    // Monitora o estado do Bluetooth
    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        startScan();
      }
    });
  }

  void startScan() async {
    setState(() => isScanning = true);
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    FlutterBluePlus.scanResults.listen((results) {
      setState(() => scanResults = results);
    });
    await FlutterBluePlus.isScanning.where((val) => val == false).first;
    setState(() => isScanning = false);
  }

  Future<void> connectAndDiscover(BluetoothDevice device) async {
    try {
      await device.connect(license: License.free);
      setState(() => connectedDevice = device);
      // O iOS exige a descoberta de serviços logo após a conexão
      await device.discoverServices();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Conectado a ${device.platformName}")),
      );
    } catch (e) {
      print("Erro ao conectar: $e");
    }
  }

  // Método principal para escrever o uint8
  Future<void> sendData() async {
    if (connectedDevice == null) return;

    // Converte o texto para int
    int? val = int.tryParse(_valueController.text);
    
    // Validação de uint8 (0 a 255)
    if (val == null || val < 0 || val > 255) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Insira um número válido entre 0 e 255")),
      );
      return;
    }

    List<BluetoothService> services = await connectedDevice!.discoverServices();
    
    for (var service in services) {
      if (service.uuid.toString().toUpperCase().contains(targetServiceUuid.toUpperCase())) {
        for (var char in service.characteristics) {
          if (char.uuid.toString().toUpperCase().contains(targetCharacteristicUuid.toUpperCase())) {
            
            // Envia o valor como uma lista de 1 byte
            await char.write([val], withoutResponse: false);
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Valor $val enviado com sucesso!")),
            );
            return;
          }
        }
      }
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Característica não encontrada!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("BLE Uint8 Editor")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (connectedDevice == null) ...[
              ElevatedButton(
                onPressed: isScanning ? null : startScan,
                child: Text(isScanning ? "Buscando..." : "Escanear Dispositivos"),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: scanResults.length,
                  itemBuilder: (context, i) => ListTile(
                    title: Text(scanResults[i].device.platformName.isEmpty ? "Desconhecido" : scanResults[i].device.platformName),
                    subtitle: Text(scanResults[i].device.remoteId.toString()),
                    onTap: () => connectAndDiscover(scanResults[i].device),
                  ),
                ),
              ),
            ] else ...[
              Card(
                color: Colors.blue.shade50,
                child: ListTile(
                  title: Text("Conectado a: ${connectedDevice!.platformName}"),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () async {
                      await connectedDevice!.disconnect();
                      setState(() => connectedDevice = null);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _valueController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: "Valor para enviar (0-255)",
                  border: OutlineInputBorder(),
                  hintText: "Ex: 128",
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  onPressed: sendData,
                  child: const Text("ENVIAR PARA O SERVIDOR", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}