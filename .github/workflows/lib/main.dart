import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const PerfumeTrackerApp());
}

class PerfumeTrackerApp extends StatelessWidget {
  const PerfumeTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Perfume Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF101014),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF90CAF9),
          surface: Color(0xFF1E1E24),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _queryController = TextEditingController();
  String _apiKey = '';
  bool _loading = false;
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString('gemini_api_key') ?? '';
    });
  }

  Future<void> _saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_api_key', key.trim());
    setState(() {
      _apiKey = key.trim();
    });
  }

  void _showApiKeyDialog() {
    final controller = TextEditingController(text: _apiKey);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('API Key de Gemini'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Pega tu clave de Google AI Studio',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              _saveApiKey(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _searchPerfume() async {
    if (_apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configura tu API Key en el icono de arriba a la derecha.')),
      );
      _showApiKeyDialog();
      return;
    }

    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });

    const systemPrompt = '''
Eres un buscador y comparador de perfumes para México.
Tiendas autorizadas a consultar:
1. mercadolibre.com.mx (Vendedores autorizados: Amora Beauty Market, The Fragrance, Bellaroma, Starlan, Arome México, 100 por ciento original, Mundo Perfumes, CAZANOVA ONLINE, NEXU STORE, AROMICA, MXPERFUM CITY, SOHRELIA PERFUMERÍA, MAMGOS, MR BEST SHOPPING, AROMAIMP, Zona Vip, Alipa Global, Lux Perfumes. Oficiales: Armaf, Afnan, Rasasi, Lattafa, Bharara, French Avenue, Al Haramian, Dumont París. Internacional: KALITY USA, Belmont Usa, Aroma Latina, Versure USA. PROHIBIDO: Protop, Compra Increible).
2. amazon.com.mx (Vendedores: Amazon Mexico, Amora The Beauty Market, Romanza, Arome México, Magna Perfumes, Sohrelia, Top Brands Mx, Demayoreo, GRUPO CAZANOVA, AROMICA, NEXU.STORE, BELLAROMAMX, STARLAN PERFUMES, LUZANI, ALIPA COMERCIALIZADORA).
3. Tiendas web: walmart.com.mx, costco.com.mx, fahorro.com, fragrancenet.mx, amoramarket.com.mx, solofragancias.com.mx, bellaroma.mx, starlanperfumes.com, arome.mx, ufra.com.mx, mundoperfume.com.mx, aromica.mx, sohrelia.com, magnaperfumes.com.

Obtén notas olfativas de Fragrantica.
Devuelve EXCLUSIVAMENTE este JSON:
{
  "perfume": "Nombre y presentación",
  "precios": [
    {"tienda": "Tienda", "precio": "\$000.00 MXN", "url": "https://enlace-directo"}
  ],
  "ficha": {
    "salida": ["nota1", "nota2"],
    "corazon": ["nota1", "nota2"],
    "fondo": ["nota1", "nota2"],
    "longevidad": "x horas",
    "proyeccion": "Moderada/Pesada",
    "resena": "Reseña corta"
  }
}
''';

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\$_apiKey',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "system_instruction": {
            "parts": [{"text": systemPrompt}]
          },
          "contents": [
            {
              "parts": [{"text": 'Perfume "$query"'}]
            }
          ],
          "tools": [
            {"google_search": {}}
          ],
          "generationConfig": {
            "response_mime_type": "application/json"
          }
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final rawText = decoded['candidates'][0]['content']['parts'][0]['text'];
        setState(() {
          _data = jsonDecode(rawText);
        });
      } else {
        setState(() {
          _error = 'Error de conexión: \${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error al procesar: \$e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _openUrl(String? urlStr) async {
    if (urlStr == null || urlStr.isEmpty) return;
    final uri = Uri.tryParse(urlStr);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfume Tracker MX'),
        actions: [
          IconButton(
            icon: const Icon(Icons.key),
            onPressed: _showApiKeyDialog,
            tooltip: 'Configurar Gemini API Key',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    decoration: InputDecoration(
                      hintText: 'Ej. Rave Now Women 100ml',
                      filled: true,
                      fillColor: const Color(0xFF1E1E24),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _searchPerfume(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.search),
                  onPressed: _loading ? null : _searchPerfume,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Rastreando tiendas y precios...'),
                    ],
                  ),
                ),
              ),
            if (_error != null)
              Expanded(
                child: Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
              ),
            if (_data != null)
              Expanded(
                child: ListView(
                  children: [
                    Text(
                      _data!['perfume'] ?? '',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Mejores Precios Encontrados',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                    const SizedBox(height: 8),
                    ...((_data!['precios'] as List? ?? []).map((item) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(item['tienda'] ?? ''),
                          trailing: Text(
                            item['precio'] ?? '',
                            style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          onTap: () => _openUrl(item['url']),
                        ),
                      );
                    })),
                    const SizedBox(height: 16),
                    const Text(
                      'Ficha Técnica (Fragrantica)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                    const SizedBox(height: 8),
                    if (_data!['ficha'] != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Salida: \${(_data!['ficha']['salida'] as List? ?? []).join(", ")}'),
                              const SizedBox(height: 4),
                              Text('Corazón: \${(_data!['ficha']['corazon'] as List? ?? []).join(", ")}'),
                              const SizedBox(height: 4),
                              Text('Fondo: \${(_data!['ficha']['fondo'] as List? ?? []).join(", ")}'),
                              const Divider(height: 20),
                              Text('Longevidad: \${_data!['ficha']['longevidad'] ?? "N/A"}'),
                              Text('Proyección: \${_data!['ficha']['proyeccion'] ?? "N/A"}'),
                              const SizedBox(height: 8),
                              Text(
                                _data!['ficha']['resena'] ?? '',
                                style: const TextStyle(fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
