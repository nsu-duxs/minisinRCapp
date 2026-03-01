import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() => runApp(const MaterialApp(home: BLEWriteApp()));

// 1. Classe para organizar seus comandos no código
class BleCommand {
  final String name;
  final String serviceUuid;
  final String charUuid;

  BleCommand({required this.name, required this.serviceUuid, required this.charUuid});
}

class BLEWriteApp extends StatefulWidget {
  const BLEWriteApp({super.key});

  @override
  _BLEWriteAppState createState() => _BLEWriteAppState();
}

class _BLEWriteAppState extends State<BLEWriteApp> {
  BluetoothDevice? connectedDevice;
  List<ScanResult> scanResults = [];
  bool isScanning = false;
  
  final TextEditingController _valueController = TextEditingController();
  
  // 2. CADASTRE SEUS UUIDS AQUI
  final List<BleCommand> myCommands = [
    BleCommand(name: "servo", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "aff04f40-41ab-493c-925d-37f4b2d92325"),

    BleCommand(name: "giro45Horario", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "aed55e60-5927-4d22-ad1c-c2135096df70")

    
    // Adicione quantos quiser no mesmo modelo...
  ];

  // Comando selecionado no Dropdown
  late BleCommand selectedCommand;

  @override
  void initState() {
    super.initState();
    selectedCommand = myCommands.first; // Começa com o primeiro da lista
    _startInitialScan();
  }

  void _startInitialScan() async {
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    FlutterBluePlus.scanResults.listen((results) {
      setState(() => scanResults = results);
    });
  }

  // Função para enviar o dado
  Future<void> sendData() async {
    if (connectedDevice == null) return;

    int? val = int.tryParse(_valueController.text);
    if (val == null || val < 0 || val > 255) {
      _showMsg("Digite um valor entre 0 e 255");
      return;
    }

    try {
      List<BluetoothService> services = await connectedDevice!.discoverServices();
      
      // Busca o serviço e a característica selecionados no Dropdown
      for (var s in services) {
        if (s.uuid.toString().toUpperCase().contains(selectedCommand.serviceUuid.toUpperCase())) {
          for (var c in s.characteristics) {
            if (c.uuid.toString().toUpperCase().contains(selectedCommand.charUuid.toUpperCase())) {
              
              await c.write([val], withoutResponse: false);
              _showMsg("Enviado: ${selectedCommand.name} = $val");
              return;
            }
          }
        }
      }
      _showMsg("Erro: UUID não encontrado no hardware!");
    } catch (e) {
      _showMsg("Erro na escrita: $e");
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("BLE Command Center")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: connectedDevice == null ? _buildScanList() : _buildControlPanel(),
      ),
    );
  }

  // Widget da lista de escaneamento
  Widget _buildScanList() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () => _startInitialScan(),
          child: const Text("Escanear Novamente"),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: scanResults.length,
            itemBuilder: (context, i) => ListTile(
              title: Text(scanResults[i].device.platformName.isEmpty ? "Disp. Desconhecido" : scanResults[i].device.platformName),
              onTap: () async {
                await scanResults[i].device.connect(license: License.free);
                setState(() => connectedDevice = scanResults[i].device);
              },
            ),
          ),
        ),
      ],
    );
  }

  // Widget do painel de controle após conectar
  Widget _buildControlPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Conectado a: ${connectedDevice!.platformName}", style: const TextStyle(fontWeight: FontWeight.bold)),
        const Divider(height: 30),
        
        const Text("Escolha o comando:"),
        const SizedBox(height: 8),
        
        // --- DROPDOWN PARA ESCOLHER O COMANDO ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<BleCommand>(
              value: selectedCommand,
              isExpanded: true,
              items: myCommands.map((cmd) {
                return DropdownMenuItem(value: cmd, child: Text(cmd.name));
              }).toList(),
              onChanged: (value) => setState(() => selectedCommand = value!),
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        Text("UUID Alvo: ${selectedCommand.charUuid}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 10),

        TextField(
          controller: _valueController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: "Valor uint8 (0-255)",
            border: OutlineInputBorder(),
          ),
        ),
        
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            onPressed: sendData,
            child: Text("ENVIAR ${selectedCommand.name.toUpperCase()}"),
          ),
        ),
        
        const Spacer(),
        TextButton(
          onPressed: () {
            connectedDevice!.disconnect();
            setState(() => connectedDevice = null);
          },
          child: const Center(child: Text("Desconectar", style: TextStyle(color: Colors.red))),
        )
      ],
    );
  }
}