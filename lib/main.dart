import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(const MinisinRCapp());
}

class MinisinRCapp extends StatelessWidget {
  const MinisinRCapp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Minisin RC App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 187, 1, 1)),
      ),
      home: const TelaDeControle(),
    );
  }
}


class TelaDeControle extends StatefulWidget {
  const TelaDeControle({super.key});

  @override
  State<TelaDeControle> createState() => _TelaDeControleState();
}

class _TelaDeControleState extends State<TelaDeControle> {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _servoCharacteristic;
  
  // Usando os valores do seu código C++
  double _servoPosicao = 170; 
  bool _isConnecting = false;

  // COLOQUE AQUI OS MESMOS UUIDS DO SEU C++
  final String SERVICE_UUID = "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad";
  final String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  @override
  void initState() {
    super.initState();
    _scanAndConnect();
  }

  void _scanAndConnect() async {
    setState(() => _isConnecting = true);

    // Começa a escanear
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

    // Fica ouvindo os resultados
    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        // Procura pelo nome que definimos no ESP32
        if (r.device.advName == "minisumo" || r.device.platformName == "minisumo") {
          FlutterBluePlus.stopScan();
          _device = r.device;
          
          await _device!.connect(license: License.free);
          _discoverServices();
          break;
        }
      }
    });
  }

  void _discoverServices() async {
    if (_device == null) return;

    List<BluetoothService> services = await _device!.discoverServices();
    for (BluetoothService service in services) {
      if (service.uuid.toString() == SERVICE_UUID) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.uuid.toString() == CHARACTERISTIC_UUID) {
            setState(() {
              _servoCharacteristic = characteristic;
              _isConnecting = false;
            });
          }
        }
      }
    }
  }

  void _enviarPosicaoServo(double valor) async {
    if (_servoCharacteristic != null) {
      // Envia o valor como uma lista contendo 1 byte (convertido para int)
      await _servoCharacteristic!.write([valor.toInt()], withoutResponse: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Controle do robô')),
      body: Center(
        child: _isConnecting
            ? const CircularProgressIndicator() // Mostra carregando enquanto conecta
            : _servoCharacteristic == null
                ? const Text('Nenhum robo foi encontrado. Ligue o ESP32.')
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Posição do Servo', style: TextStyle(fontSize: 24)),
                      Text('${_servoPosicao.toInt()}°', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                      Slider(
                        value: _servoPosicao,
                        min: 0, // O seu inicioServo do C++
                        max: 250, // O seu máximo do C++
                        onChanged: (novoValor) {
                          setState(() {
                            _servoPosicao = novoValor;
                          });
                          _enviarPosicaoServo(novoValor); // Envia para o ESP32
                        },
                      ),
                    ],
                  ),
      ),
    );
  }
}