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
  
  // A lista dos que aparecem na tela
  List<ScanResult> _robosEncontrados = []; 
  
  // ADICIONE ESTA LINHA AQUI: A lista dos que você deslizou para apagar
  final List<String> _robosIgnorados = [];

  double _servoPosicao = 170; 
  bool _isScanning = false;

  
  final String serviceUuid = "41a490f5-ce95-4ada-b8f5-9c63ff4e61ad";
  
  final String characteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

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

    FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          // LISTA TUDO! Sem filtro de nome, sem filtro de ignorados.
          // Se o ESP32 estiver ligado, ele TEM que aparecer aqui, 
          // mesmo que o nome apareça como "Unknown Device".
          _robosEncontrados = results; 
        });
      }
    });

    // Varredura de 4 segundos sem restrições
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

    if (mounted) setState(() => _isScanning = false);
  }

  void _conectarAoRobo(BluetoothDevice roboEscolhido) async {
    await FlutterBluePlus.stopScan(); 
    
    setState(() {
      _device = roboEscolhido;
    });

    try {
      // Adicionamos um timeout de 7 segundos. Se o Android travar, ele desiste.
      await _device!.connect(timeout: const Duration(seconds: 7), license: License.free);
      _discoverServices();
    } catch (e) {
      print("Falha ao conectar: $e");
      _desconectar(); // Volta para a tela inicial em caso de erro
    }
  }

void _discoverServices() async {
    if (_device == null) return;

    print("=== INICIANDO RAIO-X DOS UUIDS ===");

    try {
      List<BluetoothService> services = await _device!.discoverServices();
      bool encontrou = false;

      for (BluetoothService s in services) {
        print("Serviço encontrado no ESP32: ${s.uuid}"); // Imprime o Serviço real
        
        for (BluetoothCharacteristic c in s.characteristics) {
          print("  -> Característica encontrada: ${c.uuid}"); // Imprime a Característica real
          
          if (c.uuid.toString().toLowerCase() == characteristicUuid.toLowerCase()) {
            setState(() {
              _servoCharacteristic = c;
            });
            encontrou = true;
          }
        }
      }

      if (!encontrou) {
        print("❌ ABORTANDO: O Flutter procurava por '$characteristicUuid', mas o ESP32 não tem ele!");
        _desconectar(); // É AQUI QUE O ANDROID ESTAVA DESCONECTANDO!
      } else {
        print("✅ SUCESSO! Característica encontrada e vinculada.");
      }

    } catch (e) {
      print("Erro no Raio-X: $e");
      _desconectar();
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