import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// --- CONFIGURAÇÕES ---
const String SUPABASE_URL = 'https://ukzkiijpldsjzhpftumk.supabase.co';
const String SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVremtpaWpwbGRzanpocGZ0dW1rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcxMjk4MzksImV4cCI6MjA4MjcwNTgzOX0.KybTo0IPM5atFgwlQ4o4yKcQyC053fv2dXBR08-0TJA';

// SEU NÚMERO DE WHATSAPP (Apenas números, com DDD)
const String TELEFONE_LOJA = '5585996702606'; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: SUPABASE_URL, anonKey: SUPABASE_KEY);
  runApp(const HivizApp());
}

class HivizApp extends StatelessWidget {
  const HivizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hiviz Acessórios',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      home: const VitrinePage(),
    );
  }
}

class VitrinePage extends StatefulWidget {
  const VitrinePage({super.key});

  @override
  State<VitrinePage> createState() => _VitrinePageState();
}

class _VitrinePageState extends State<VitrinePage> {
  // Dados
  List<Map<String, dynamic>> _produtos = [];
  List<String> _categorias = [];
  bool _loading = true;

  // Busca
  String _termoBusca = '';
  final TextEditingController _searchController = TextEditingController();

  // Carrinho
  final List<Map<String, dynamic>> _carrinho = [];
  final Map<int, String> _variacaoSelecionada = {};

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _loading = true);
    final supabase = Supabase.instance.client;

    try {
      final respCat = await supabase.from('categorias').select('nome').order('nome');
      final listaCat = (respCat as List).map((e) => e['nome'] as String).toList();

      final respProd = await supabase.from('produtos').select().order('nome');
      final listaProd = List<Map<String, dynamic>>.from(respProd);

      setState(() {
        _categorias = listaCat;
        _produtos = listaProd;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Erro: $e');
      setState(() => _loading = false);
    }
  }

  void _adicionarAoCarrinho(Map<String, dynamic> produto) {
    List<String> variantes = _parseVariantes(produto['variantes']);
    String? variacaoEscolhida;

    if (variantes.isNotEmpty) {
      variacaoEscolhida = _variacaoSelecionada[produto['id']];
      if (variacaoEscolhida == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Por favor, selecione uma variação."), backgroundColor: Colors.orange),
        );
        return;
      }
    }

    setState(() {
      _carrinho.add({
        'produto': produto,
        'variacao': variacaoEscolhida ?? '',
        'quantidade': 1,
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${produto['nome']} adicionado!"),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _removerDoCarrinho(int index) {
    setState(() {
      _carrinho.removeAt(index);
    });
  }

  double get _totalCarrinho {
    return _carrinho.fold(0.0, (soma, item) {
      return soma + (item['produto']['preco'] as num).toDouble();
    });
  }

  Future<void> _enviarPedidoWhatsApp() async {
    if (_carrinho.isEmpty) return;

    final real = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    StringBuffer msg = StringBuffer();
    msg.writeln("Olá Hiviz! Gostaria de fazer este pedido:");
    msg.writeln("");

    for (var item in _carrinho) {
      final p = item['produto'];
      final v = item['variacao'];
      msg.write("1x *${p['nome']}*");
      if (v != null && v.isNotEmpty) msg.write(" ($v)");
      msg.writeln(" - ${real.format(p['preco'])}");
    }

    msg.writeln("");
    msg.writeln("*Total: ${real.format(_totalCarrinho)}*");
    msg.writeln("------------------------------");
    msg.writeln("Aguardo confirmação!");

    final link = "https://wa.me/$TELEFONE_LOJA?text=${Uri.encodeComponent(msg.toString())}";
    await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
  }

  List<String> _parseVariantes(dynamic raw) {
    if (raw == null || raw.toString().isEmpty) return [];
    return raw.toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Hiviz Acessórios", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart, color: Colors.white),
                onPressed: _abrirCarrinhoModal,
              ),
              if (_carrinho.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text('${_carrinho.length}', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                )
            ],
          )
        ],
      ),
      
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // --- BARRA DE BUSCA ---
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.deepPurple,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() => _termoBusca = val);
                    },
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: "O que você procura hoje?",
                      prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
                      suffixIcon: _termoBusca.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _termoBusca = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                    ),
                  ),
                ),

                // --- LISTA DE GAVETAS ---
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100, top: 10),
                    itemCount: _categorias.length,
                    itemBuilder: (context, index) {
                      final categoria = _categorias[index];
                      
                      // Filtro: Pega produtos da categoria E que batem com a busca
                      final produtosDaCategoria = _produtos.where((p) {
                        final pertenceCategoria = p['categoria'] == categoria;
                        final matchBusca = p['nome'].toString().toLowerCase().contains(_termoBusca.toLowerCase());
                        return pertenceCategoria && matchBusca;
                      }).toList();

                      // Se a categoria ficou vazia por causa da busca, esconde ela
                      if (produtosDaCategoria.isEmpty) return const SizedBox();

                      // Truque para forçar a gaveta a abrir se tiver busca
                      // Usamos uma Key única que muda se tiver busca ou não, forçando rebuild
                      final uniqueKey = PageStorageKey('$categoria-${_termoBusca.isNotEmpty}');

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ExpansionTile(
                          key: uniqueKey, // Mantém estado ou reseta
                          initiallyExpanded: true, // Sempre tenta abrir
                          shape: const Border(),
                          title: Text(
                            categoria,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepPurple),
                          ),
                          leading: const Icon(Icons.category, color: Colors.deepPurple),
                          children: produtosDaCategoria.map((produto) => _buildProdutoItem(produto)).toList(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

      floatingActionButton: _carrinho.isNotEmpty
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FloatingActionButton.extended(
                onPressed: _enviarPedidoWhatsApp,
                backgroundColor: Colors.green,
                icon: const Icon(Icons.chat, color: Colors.white), 
                label: Text(
                  "Finalizar Pedido (${NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(_totalCarrinho)})",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildProdutoItem(Map<String, dynamic> item) {
    final real = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final variantes = _parseVariantes(item['variantes']);
    final estoque = item['estoque'] ?? 0;
    final temEstoque = estoque > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10, left: 10, right: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[100],
                    child: item['imagem_url'] != null
                        ? Image.network(item['imagem_url'], fit: BoxFit.cover)
                        : const Icon(Icons.image_not_supported, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['nome'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(real.format(item['preco']), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w800, fontSize: 18)),
                      const SizedBox(height: 4),
                      Text(
                        temEstoque ? "Estoque: $estoque un" : "Indisponível",
                        style: TextStyle(color: temEstoque ? Colors.grey[600] : Colors.red, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            if (variantes.isNotEmpty && temEstoque) ...[
              const SizedBox(height: 10),
              const Text("Escolha uma opção:", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 5),
              Wrap(
                spacing: 8,
                children: variantes.map((v) {
                  final isSelected = _variacaoSelecionada[item['id']] == v;
                  return ChoiceChip(
                    label: Text(v),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _variacaoSelecionada[item['id']] = selected ? v : '';
                      });
                    },
                    selectedColor: Colors.deepPurple.shade100,
                    labelStyle: TextStyle(color: isSelected ? Colors.deepPurple : Colors.black),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: temEstoque ? () => _adicionarAoCarrinho(item) : null,
                icon: const Icon(Icons.add_shopping_cart, size: 18),
                label: const Text("Adicionar ao Carrinho"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: temEstoque ? Colors.deepPurple : Colors.grey,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _abrirCarrinhoModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: 500,
              child: Column(
                children: [
                  const Text("Seu Carrinho", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Divider(),
                  Expanded(
                    child: _carrinho.isEmpty
                        ? const Center(child: Text("Carrinho vazio 🛒", style: TextStyle(color: Colors.grey, fontSize: 18)))
                        : ListView.builder(
                            itemCount: _carrinho.length,
                            itemBuilder: (context, index) {
                              final item = _carrinho[index];
                              final p = item['produto'];
                              final v = item['variacao'];
                              return ListTile(
                                leading: const Icon(Icons.shopping_bag, color: Colors.deepPurple),
                                title: Text(p['nome']),
                                subtitle: v.isNotEmpty ? Text("Opção: $v") : null,
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    _removerDoCarrinho(index); 
                                    setModalState(() {}); 
                                    setState(() {}); 
                                    if(_carrinho.isEmpty) Navigator.pop(context);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                  if (_carrinho.isNotEmpty) ...[
                    const Divider(),
                    Text("Total: ${NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(_totalCarrinho)}", 
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.chat), 
                        label: const Text("ENVIAR PEDIDO"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.all(15)),
                        onPressed: _enviarPedidoWhatsApp,
                      ),
                    )
                  ]
                ],
              ),
            );
          },
        );
      },
    );
  }
}
