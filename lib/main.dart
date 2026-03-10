import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() => runApp(const MaterialApp(home: BLEWriteApp()));

// 1. Classe para organizar seus comandos no código
class BleCommand {
  final String name;
  final String serviceUuid;
  final String charUuid;
  final String tipo; // para adicionar alguns parametros que são float e bool

  BleCommand({required this.name, required this.serviceUuid, required this.charUuid, this.tipo = "int8"});
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
    BleCommand(name: "servo posicão", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "aff04f40-41ab-493c-925d-37f4b2d92325"),

    BleCommand(name: "Servo inicial", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "31296a63-d6ce-4daf-a4a8-0f4d59907071"),

    BleCommand(name: "Servo Ativado (0 ou 1)", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "01f0d89c-ed13-46db-98b3-e93d485fdc74",  tipo: "bool"),

    BleCommand(name: "giro45 Anti Horario", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "aed55e60-5927-4d22-ad1c-c2135096df70"),

    BleCommand(name: "giro45 Horario", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "17748c8a-2d2e-4a18-8054-6dd6db805d61"),

    BleCommand(name: "giro 90 Anti Horario", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "c238b3c8-27eb-455a-9eb7-26162b538a45"),

    BleCommand(name: "giro 90 Horario", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "48e04e0d-f49c-4d1f-b3c1-51cdd10cbd65"),

    BleCommand(name: "arco anti-Horario/ 10", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "ebd8a9e4-085a-41ed-bd4f-0e46cbd1c4b3"),

    BleCommand(name: "arco Horario / 10", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "866001fe-5690-4e56-96fc-ce17687f0d5d"),
    
    BleCommand(name: "arco shikiri anti-horario", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "7a2a2932-c806-4068-a3e3-e78e640a2a07"),

    BleCommand(name: "arco shikiri horario", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "3d0ac383-e16a-4e42-870d-f2a859efe8c0"),

    BleCommand(name: "Arco borda anti-horario", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid:  "7d049e22-20f6-4e01-b018-7e8fcf8ac91b"),

    BleCommand(name: "Arco borda horario", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid:  "7bd3ee6f-c6a8-4591-852a-93af450cb940"),

    BleCommand(name: "zigzag anti-horario", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid:  "65f2b4cc-cb29-4464-8695-f7d929fe3a79"),

    BleCommand(name: "zigzag horario", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid:  "22533c8f-130d-4775-8870-d4229cfd272d"),

    BleCommand(name: "zigzag shikiri anti-horario", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid:  "ab9a4df9-74a5-4f4c-bfd2-4e1c7d40ba74"),

    BleCommand(name: "zigzag shikiri horario", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid:  "6e21271d-e8e9-4365-afad-66ebd5af0f28"),

    BleCommand(name: "zigzag borda horario", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid:  "adbfa60f-3068-4cfb-b0c4-382977d1dc23"),

    BleCommand(name: "zigzag borda anti-horario", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid:  "f7ad38dd-acb1-4a53-baec-6aa279f9f35b"),


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