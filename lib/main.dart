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

  double _servoPosicao = 170; 
  bool _isConnecting = false;

  final String SERVICE_UUID = "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad";
  final String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  @override
  void initState() {
    super.initState();
    _scanAndConnect();
  }

  void _scanAndConnect() async {
    // Evita rodar dois scans ao mesmo tempo
    if (_isConnecting) return; 

    setState(() {
      _isConnecting = true;
      _device = null;
      _servoCharacteristic = null;
    });

    // 1. Inicia a varredura no ar (Essencial para BLE)
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

    // 2. Escuta os dispositivos que estão anunciando no ambiente
    var subscription = FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        if (r.advertisementData.advName == "minisumo" || r.device.platformName == "minisumo") {
          
          await FlutterBluePlus.stopScan();
          _device = r.device;
          
          try {
            await _device!.connect(license: License.free);
            _discoverServices();
          } catch (e) {
            print("Erro ao conectar: $e");
            setState(() => _isConnecting = false);
          }
          return; // Sai do loop se encontrou
        }
      }
    });

    // 3. Após 4.5 segundos (tempo do timeout + margem), verifica se achou algo.
    // Se não achou, desliga o loading para mostrar o botão de tentar novamente.
    Future.delayed(const Duration(milliseconds: 4500), () {
      subscription.cancel();
      if (_servoCharacteristic == null) {
        setState(() => _isConnecting = false);
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
      await _servoCharacteristic!.write([valor.toInt()], withoutResponse: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Controle do robô')),
      body: Center(
        child: _isConnecting
            ? const CircularProgressIndicator() 
            : _servoCharacteristic == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Nenhum robô foi encontrado.'),
                      const SizedBox(height: 10),
                      const Text('Ligue o ESP32 e tente novamente.'),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _scanAndConnect, // Botão para tentar conectar de novo
                        icon: const Icon(Icons.bluetooth_searching),
                        label: const Text('Buscar Novamente'),
                      )
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Posição do Servo', style: TextStyle(fontSize: 24)),
                      Text('${_servoPosicao.toInt()}°', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                      Slider(
                        value: _servoPosicao,
                        min: 0, 
                        max: 250, 
                        onChanged: (novoValor) {
                          setState(() {
                            _servoPosicao = novoValor;
                          });
                          _enviarPosicaoServo(novoValor); 
                        },
                      ),
                    ],
                  ),
      ),
    );
  }
}