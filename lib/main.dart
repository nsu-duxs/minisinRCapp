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
  int booleano = 0; 
  
  // 2. CADASTRE SEUS UUIDS AQUI
  final List<BleCommand> myCommands = [
    // --- BLOCO SERVO (ZORRO) ---
    BleCommand(name: "Servo Posição", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "aff04f40-41ab-493c-925d-37f4b2d92325"),
    BleCommand(name: "Servo Inicial", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "31296a63-d6ce-4daf-a4a8-0f4d59907071"),
    BleCommand(name: "Servo Ativado", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "01f0d89c-ed13-46db-98b3-e93d485fdc74", tipo: "bool"),

    // --- BLOCO VELOCIDADE E MARCHAS ---
    BleCommand(name: "Min PWM", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "ad4291a8-91c5-4922-9ce0-a30f6e59b671"),
    BleCommand(name: "Velocidade Máxima (%)", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "b16d51d4-03d7-45b4-9677-8ffaf5dc13ab"),
    BleCommand(name: "Limite Troca Marcha", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "a69aa49a-1267-4b8a-934d-4336cc1cfbde"),

    // --- BLOCO GIROS (TEMPOS) ---
    BleCommand(name: "Giro 45 Anti-Horário", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "aed55e60-5927-4d22-ad1c-c2135096df70"),
    BleCommand(name: "Giro 45 Horário", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "17748c8a-2d2e-4a18-8054-6dd6db805d61"),
    BleCommand(name: "Giro 90 Anti-Horário", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "c238b3c8-27eb-455a-9eb7-26162b538a45"),
    BleCommand(name: "Giro 90 Horário", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "48e04e0d-f49c-4d1f-b3c1-51cdd10cbd65"),

    // --- BLOCO ARCOS (TEMPOS E VELOCIDADES) ---
    BleCommand(name: "Arco Anti-Horário (Tempo)", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "ebd8a9e4-085a-41ed-bd4f-0e46cbd1c4b3", tipo: "int16"),
    BleCommand(name: "Velo. Esq. Arco Anti (%)", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "00a6431e-b818-45c7-96d2-fb1e4df4a8f8"),
    BleCommand(name: "Arco Horário (Tempo)", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "866001fe-5690-4e56-96fc-ce17687f0d5d", tipo: "int16"),
    BleCommand(name: "Velo. Dir. Arco Hor (%)", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "10a686f0-04a1-4e26-9b64-586bcd9ea8ed"),

    BleCommand(name: "Arco Shikiri Anti (Tempo)", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "7a2a2932-c806-4068-a3e3-e78e640a2a07"),
    BleCommand(name: "Velo. Esq. Shikiri Anti (%)", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "5747facc-26b2-4c6c-84b1-c825f4d918d2"),
    BleCommand(name: "Arco Shikiri Hor (Tempo)", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "3d0ac383-e16a-4e42-870d-f2a859efe8c0"),
    BleCommand(name: "Velo. Dir. Shikiri Hor (%)", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "8df745c5-b4b9-4771-a104-a03ee3b0d83a"),

    BleCommand(name: "Arco Borda Anti (Tempo)", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "7d049e22-20f6-4e01-b018-7e8fcf8ac91b"),
    BleCommand(name: "Arco Borda Hor (Tempo)", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "7bd3ee6f-c6a8-4591-852a-93af450cb940"),

    // --- BLOCO ZIG-ZAG ---
    BleCommand(name: "Zig-Zag Anti-Horário", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "65f2b4cc-cb29-4464-8695-f7d929fe3a79"),
    BleCommand(name: "Zig-Zag Horário", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "22533c8f-130d-4775-8870-d4229cfd272d"),
    BleCommand(name: "Zig-Zag Shikiri Anti", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "ab9a4df9-74a5-4f4c-bfd2-4e1c7d40ba74"),
    BleCommand(name: "Zig-Zag Shikiri Hor", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "6e21271d-e8e9-4365-afad-66ebd5af0f28"),
    BleCommand(name: "Zig-Zag Borda Anti", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "f7ad38dd-acb1-4a53-baec-6aa279f9f35b"),
    BleCommand(name: "Zig-Zag Borda Hor", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "adbfa60f-3068-4cfb-b0c4-382977d1dc23"),

    // --- BLOCO EXTRAS ---
    BleCommand(name: "Controle Agressivo", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "1c96b06e-8c40-4595-98e8-216ff1b31837", tipo: "bool"),
    BleCommand(name: "Tempo Stop Motors", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "2e3ec45b-5ed5-4a25-993b-bba6b90d2d27"),
    BleCommand(name: "Inversão Motores", serviceUuid: "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad", charUuid: "eecc8392-060e-4265-aacb-e52e3ec65d66", tipo: "bool"),
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
    int? val;
    if(selectedCommand.tipo == "int8"){
    val = int.tryParse(_valueController.text);
    if (val == null || val < 0 || val >255) {
      _showMsg("Digite um valor entre 0 e 255");
      return;
    }}
    else if(selectedCommand.tipo == "bool")
    {
      val = booleano;
    }
    else if(selectedCommand.tipo == "int16")
    {
      val = int.tryParse(_valueController.text);
      if(val == null || val<0 || val > 65535)
      {
        _showMsg("Digite um numero entre o e 65535");
        return;
      }
    }
    else{return;}

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

        selectedCommand.tipo == "int8" ? TextField(
          controller: _valueController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: "Valor uint8 (0-255)",
            border: OutlineInputBorder(),
          ),
          ) 
          : selectedCommand.tipo == "bool" ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children:[
              ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              onPressed :() {
                booleano = 1;
              
              },
              child: Text("ativar"),

            ),
              ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              onPressed: () {
                booleano = 0;
              },
              child: Text("desativar"),
              ),
            
            ],
          ) 
          : selectedCommand.tipo == "int16" ?
          TextField(
            controller: _valueController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: ("valor de int16(>255)"),
              border: OutlineInputBorder(),
          ),

          )
          : SizedBox.shrink(),
        
        
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