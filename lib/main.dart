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
  
  // Lista para guardar os robôs encontrados no scan
  List<ScanResult> _robosEncontrados = []; 

  double _servoPosicao = 170; 
  bool _isScanning = false;

  final String SERVICE_UUID = "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad";
  final String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  @override
  void initState() {
    super.initState();
    _iniciarScan();
  }

  void _iniciarScan() async {
    setState(() {
      _isScanning = true;
      _robosEncontrados.clear();
    });

    // 1. PRIMEIRO: Ligamos o "ouvido" do app para escutar os resultados em tempo real
    FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          // Filtra para mostrar apenas dispositivos que tenham "minisumo" no nome
          _robosEncontrados = results.where((r) {
            String nome = r.advertisementData.advName.isNotEmpty 
                ? r.advertisementData.advName 
                : r.device.platformName;
            return nome.toLowerCase().contains("minisumo");
          }).toList();
        });
      }
    });

    // 2. SEGUNDO: Mandamos a antena começar a procurar de fato
    // O 'await' vai fazer o código pausar aqui por 4 segundos
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

    // 3. TERCEIRO: Os 4 segundos passaram e o scan terminou. 
    // Desligamos a animação de carregamento.
    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  // Nova função chamada quando você clica em um robô da lista
  void _conectarAoRobo(BluetoothDevice roboEscolhido) async {
    await FlutterBluePlus.stopScan(); // Para de procurar
    
    setState(() {
      _isScanning = true; // Mostra carregando enquanto conecta
      _device = roboEscolhido;
    });

    try {
      await _device!.connect(license: License.free);
      _discoverServices();
    } catch (e) {
      print("Erro ao conectar: $e");
      setState(() {
        _device = null;
        _isScanning = false;
      });
      // Opcional: Mostrar um alerta de erro na tela aqui
    }
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
              _isScanning = false; // Terminou de conectar e achar os serviços
            });
          }
        }
      }
    }
  }

  void _desconectar() async {
    if (_device != null) {
      await _device!.disconnect();
    }
    setState(() {
      _device = null;
      _servoCharacteristic = null;
    });
    _iniciarScan(); // Volta a procurar robôs
  }

  void _enviarPosicaoServo(double valor) async {
    if (_servoCharacteristic != null) {
      await _servoCharacteristic!.write([valor.toInt()], withoutResponse: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Controle do robô'),
        actions: [
          // Botão para desconectar e voltar para a lista
          if (_device != null)
            IconButton(
              icon: const Icon(Icons.bluetooth_disabled),
              onPressed: _desconectar,
            ),
        ],
      ),
      // Se não tem dispositivo conectado, mostra a TELA DE LISTA. Se tem, mostra a TELA DE CONTROLE.
      body: _device == null ? _buildTelaDeLista() : _buildTelaDeControle(),
    );
  }

  // TELA 1: A Lista de Dispositivos Encontrados
  Widget _buildTelaDeLista() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _isScanning ? null : _iniciarScan,
            icon: _isScanning 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
              : const Icon(Icons.search),
            label: Text(_isScanning ? 'Buscando robôs...' : 'Buscar Robôs'),
          ),
        ),
        Expanded(
          child: _robosEncontrados.isEmpty && !_isScanning
              ? const Center(child: Text('Nenhum robô encontrado.'))
              : ListView.builder(
                  itemCount: _robosEncontrados.length,
                  itemBuilder: (context, index) {
                    final robo = _robosEncontrados[index].device;
                    final nome = _robosEncontrados[index].advertisementData.advName.isNotEmpty 
                        ? _robosEncontrados[index].advertisementData.advName 
                        : robo.platformName;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const Icon(Icons.memory, color: Color.fromARGB(255, 187, 1, 1)),
                        title: Text(nome.isNotEmpty ? nome : 'Dispositivo Desconhecido'),
                        subtitle: Text(robo.remoteId.toString()), // No Android mostra o MAC, no iOS mostra o UUID
                        trailing: ElevatedButton(
                          onPressed: () => _conectarAoRobo(robo),
                          child: const Text('Conectar'),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // TELA 2: Os Sliders e Controles
  Widget _buildTelaDeControle() {
    if (_servoCharacteristic == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: Column(
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
    );
  }
}