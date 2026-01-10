import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

// --- CONFIGURAÇÕES GERAIS ---
const String SUPABASE_URL = 'https://ukzkiijpldsjzhpftumk.supabase.co';
const String SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVremtpaWpwbGRzanpocGZ0dW1rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcxMjk4MzksImV4cCI6MjA4MjcwNTgzOX0.KybTo0IPM5atFgwlQ4o4yKcQyC053fv2dXBR08-0TJA';
const String TELEFONE_LOJA = '5585996702606';

// --- 🎨 COMO MUDAR A FONTE DO TÍTULO ---
// Mude 'dancingScript' para outra opção como:
// GoogleFonts.roboto(), GoogleFonts.oswald(), GoogleFonts.lobster(), GoogleFonts.pacifico()
// Dica: Segure CTRL e clique em 'GoogleFonts' para ver a lista.
final TextStyle FONTE_TITULO = GoogleFonts.shrikhand(
  fontSize: 30,
  fontWeight: FontWeight.bold,
  color: Colors.pink,
);

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
        textTheme: GoogleFonts.interTextTheme(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE91E63),
          primary: const Color(0xFFE91E63),
        ),
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        // Correção para versão nova do Flutter
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          color: Colors.white,
        ),
      ),
      home: const VitrinePage(),
    );
  }
}

// ============================================================================
// PAGINA PRINCIPAL (VITRINE)
// ============================================================================
class VitrinePage extends StatefulWidget {
  const VitrinePage({super.key});

  @override
  State<VitrinePage> createState() => _VitrinePageState();
}

class _VitrinePageState extends State<VitrinePage> {
  List<Map<String, dynamic>> _produtos = [];
  List<String> _categorias = [];
  bool _loading = true;
  String _termoBusca = '';
  final TextEditingController _searchController = TextEditingController();
  String? _categoriaAberta;

  // Carrinho Global (simplificado para este arquivo)
  final List<Map<String, dynamic>> _carrinho = [];

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _loading = true);
    final supabase = Supabase.instance.client;

    try {
      // 1. Busca TODAS as Categorias
      final respCat = await supabase.from('categorias').select().order('nome');

      // Cria uma lista APENAS com os nomes das categorias que NÃO estão ocultas
      final categoriasVisiveis = (respCat as List)
      .where((c) => c['oculto'] != true) // Filtra ocultos
      .map((e) => e['nome'] as String)
      .toList();

      // 2. Busca TODOS os Produtos
      final respProd = await supabase.from('produtos').select().order('nome');

      final produtosFiltrados = List<Map<String, dynamic>>.from(respProd).where((p) {
        // Regra 1: O produto não pode estar oculto
        final produtoOculto = p['oculto'] == true;

        // Regra 2: A categoria do produto tem que estar na lista de categorias visíveis
        final categoriaDoProduto = p['categoria'];
        final categoriaEstaVisivel = categoriasVisiveis.contains(categoriaDoProduto);

        // Só passa se NÃO for oculto E a categoria estiver visível
        return !produtoOculto && categoriaEstaVisivel;
      }).toList();

      if (mounted) {
        setState(() {
          _categorias = categoriasVisiveis; // Atualiza a lista de abas
          _produtos = produtosFiltrados;    // Atualiza a lista de produtos
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // --- FUNÇÃO PARA ADICIONAR AO CARRINHO (Vinda da página de detalhes) ---
  void _adicionarItemCarrinho(Map<String, dynamic> item) {
    setState(() {
      _carrinho.add(item);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${item['produto']['nome']} adicionado à sacola!"),
        backgroundColor: Colors.pink,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _removerDoCarrinho(int index) {
    setState(() => _carrinho.removeAt(index));
  }

  double get _totalCarrinho => _carrinho.fold(0, (sum, i) => sum + (i['produto']['preco'] as num).toDouble());

  Future<void> _enviarZap() async {
    if (_carrinho.isEmpty) return;
    final real = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    StringBuffer msg = StringBuffer();
    msg.writeln("Olá *Hiviz Acessórios*!");
    msg.writeln("Quero finalizar meu pedido:");
    msg.writeln("");

    for (var item in _carrinho) {
      final p = item['produto'];
      final v = item['variacao'];
      msg.write("▪ 1x *${p['nome']}*");
      if (v != null && v.isNotEmpty) msg.write(" [$v]");
      msg.writeln(" - ${real.format(p['preco'])}");
    }
    msg.writeln("");
    msg.writeln("*Total: ${real.format(_totalCarrinho)}*");

    final link = "https://wa.me/$TELEFONE_LOJA?text=${Uri.encodeComponent(msg.toString())}";
    await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
  }

  // --- MODAL DO CARRINHO ---
  void _abrirCarrinho() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Sua Sacola", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
                ],
              ),
              const Divider(),
              Expanded(
                child: _carrinho.isEmpty
                ? const Center(child: Text("Sua sacola está vazia.", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                  itemCount: _carrinho.length,
                  itemBuilder: (ctx, idx) {
                    final item = _carrinho[idx];
                    return ListTile(
                      leading: const Icon(Icons.checkroom, color: Colors.pink),
                      title: Text(item['produto']['nome']),
                      subtitle: Text(item['variacao'] ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () {
                          _removerDoCarrinho(idx);
                          setModalState((){});
                          setState((){});
                        },
                      ),
                    );
                  },
                ),
              ),
              if(_carrinho.isNotEmpty) ...[
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total:", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(_totalCarrinho),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.pink))
                  ],
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    onPressed: _enviarZap,
                    child: const Text("FINALIZAR PEDIDO NO WHATSAPP", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // APLICAÇÃO DA FONTE CUSTOMIZÁVEL
        title: Text("Hiviz Acessórios", style: FONTE_TITULO),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_bag_outlined, color: Colors.black, size: 28),
                onPressed: _abrirCarrinho,
              ),
              if (_carrinho.isNotEmpty)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.pink, shape: BoxShape.circle),
                    child: Text('${_carrinho.length}', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                )
            ],
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: _loading
      ? const Center(child: CircularProgressIndicator(color: Colors.pink))
      : Column(
        children: [
          // 1. BARRA DE BUSCA (Mantida)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _termoBusca = v),
              decoration: InputDecoration(
                hintText: "O que você procura?",
                prefixIcon: const Icon(Icons.search, color: Colors.pink),
                suffixIcon: _termoBusca.isNotEmpty
                ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _termoBusca = '');
                  })
                : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none),
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
              ),
            ),
          ),

          // 2. FILTRO DE CATEGORIAS (HORIZONTAL) - A GRANDE MUDANÇA
          // Isso evita carregar tudo de uma vez.
          if (_termoBusca.isEmpty)
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: _categorias.length + 1, // +1 para o botão "Todos"
                itemBuilder: (ctx, i) {
                  // Lógica para o botão "Todos" ser o primeiro
                  final nomeCategoria = i == 0 ? null : _categorias[i - 1];
                  final titulo = i == 0 ? "Todos" : _categorias[i - 1];
                  final isSelected = _categoriaAberta == nomeCategoria;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(titulo),
                      selected: isSelected,
                      selectedColor: Colors.pink,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black),
                        onSelected: (bool selected) {
                          setState(() {
                            // Se clicar no que já tá selecionado ou no "Todos", reseta
                            _categoriaAberta = (i == 0) ? null : nomeCategoria;
                          });
                        },
                    ),
                  );
                },
              ),
            ),

            // 3. GRADE DE PRODUTOS (Lazy Loading Real)
            Expanded(
              child: Builder(builder: (context) {
                // Filtra a lista principal
                final listaFiltrada = _produtos.where((p) {
                  // Filtro de busca
                  if (_termoBusca.isNotEmpty) {
                    final t = _termoBusca.toLowerCase();
                    return p['nome'].toString().toLowerCase().contains(t);
                  }
                  // Filtro de categoria
                  if (_categoriaAberta != null) {
                    return p['categoria'] == _categoriaAberta;
                  }
                  return true; // Mostra tudo se não tiver filtro
                }).toList();

                if (listaFiltrada.isEmpty) {
                  return const Center(
                    child: Text("Nenhum produto encontrado."));
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  // Cache Extent baixo para economizar memória
                  cacheExtent: 100,
                  gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16),
                    itemCount: listaFiltrada.length,
                    itemBuilder: (ctx, i) => _buildCard(listaFiltrada[i]),
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final imgs = item['imagens'] as List? ?? [];
    final imgUrl = imgs.isNotEmpty ? imgs.first.toString() : (item['imagem_url']?.toString() ?? '');
    final estoque = item['estoque'] ?? 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => ProdutoDetalhePage(
            produto: item,
            onAddToCart: _adicionarItemCarrinho
          ),
        ));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // AQUI ESTÁ A MUDANÇA: Usando o widget blindado
                    ImagemSupabase(url: imgUrl),

                    if (estoque <= 0)
                      Container(color: Colors.white.withOpacity(0.7), child: const Center(child: Text("ESGOTADO", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))))
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['nome'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(item['preco']),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.pink, fontSize: 14)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// NOVA TELA DE DETALHES DO PRODUTO (LEVE E OTIMIZADA)
// ============================================================================
class ProdutoDetalhePage extends StatefulWidget {
  final Map<String, dynamic> produto;
  final Function(Map<String, dynamic>) onAddToCart;

  const ProdutoDetalhePage({super.key, required this.produto, required this.onAddToCart});

  @override
  State<ProdutoDetalhePage> createState() => _ProdutoDetalhePageState();
}

class _ProdutoDetalhePageState extends State<ProdutoDetalhePage> {
  String? _variacaoSelecionada;
  int _imagemAtual = 0;

  @override
  Widget build(BuildContext context) {
    final p = widget.produto;
    final imgs = (p['imagens'] as List?)?.map((e) => e.toString()).toList() ?? [];
    if (imgs.isEmpty && p['imagem_url'] != null) imgs.add(p['imagem_url']);

    final variantes = (p['variantes']?.toString().split(',') ?? [])
    .map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    final estoque = p['estoque'] ?? 0;
    final esgotado = estoque <= 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(p['nome'], style: const TextStyle(fontSize: 16, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- CARROSSEL DE IMAGENS ---
                  SizedBox(
                    height: 350,
                    child: imgs.isNotEmpty ? PageView.builder(
                      itemCount: imgs.length,
                      onPageChanged: (idx) => setState(() => _imagemAtual = idx),
                      itemBuilder: (context, index) {
                        // Pede imagem média (800px) para detalhes, não a original gigante
                        final urlGrande = _getSupabaseImage(imgs[index], width: 800);
                        return GestureDetector(
                          onTap: () => _abrirZoom(context, imgs[index]),
                          child: CachedNetworkImage(
                            imageUrl: urlGrande,
                            fit: BoxFit.cover,
                            memCacheWidth: 800, // Limita memória
                            placeholder: (c, u) => const Center(child: CircularProgressIndicator(color: Colors.pink)),
                          ),
                        );
                      },
                    ) : Container(color: Colors.grey[200], child: const Icon(Icons.image_not_supported)),
                  ),
                  // Indicador de Bolinhas
                  if (imgs.length > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: imgs.asMap().entries.map((entry) {
                        return Container(
                          width: 8, height: 8,
                          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _imagemAtual == entry.key ? Colors.pink : Colors.grey.shade300,
                          ),
                        );
                      }).toList(),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // PREÇO E TÍTULO
                          Text(NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(p['preco']),
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.pink)),
                          const SizedBox(height: 10),
                          Text(p['nome'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 20),

                          // VARIANTES
                          if (variantes.isNotEmpty && !esgotado) ...[
                            const Text("Escolha uma opção:", style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              children: variantes.map((v) {
                                final isSel = _variacaoSelecionada == v;
                                return ChoiceChip(
                                  label: Text(v),
                                  selected: isSel,
                                  onSelected: (val) => setState(() => _variacaoSelecionada = val ? v : null),
                                  selectedColor: Colors.pink,
                                  labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // DESCRIÇÃO COMPLETA
                          const Text("Descrição", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text(p['descricao'] ?? "Sem descrição.", style: TextStyle(color: Colors.grey[700], height: 1.5, fontSize: 15)),
                        ],
                      ),
                    )
                ],
              ),
            ),
          ),

          // --- BOTÃO DE AÇÃO (FIXO EMBAIXO) ---
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))]
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: esgotado ? Colors.grey : Colors.black,
                  foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
                onPressed: esgotado ? null : () {
                  if (variantes.isNotEmpty && _variacaoSelecionada == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selecione uma opção acima!")));
                    return;
                  }
                  widget.onAddToCart({
                    'produto': p,
                    'variacao': _variacaoSelecionada,
                    'quantidade': 1
                  });
                  Navigator.pop(context); // Volta pra vitrine
                },
                child: Text(esgotado ? "INDISPONÍVEL" : "ADICIONAR À SACOLA", style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          )
        ],
      ),
    );
  }

  void _abrirZoom(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain, height: double.infinity, width: double.infinity),
            ),
            Positioned(top: 40, right: 20, child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)))
          ],
        ),
      ),
    );
  }
}

// --- 🔥 OTIMIZAÇÃO DE IMAGENS DO SUPABASE ---
// Reduz drasticamente o peso das imagens
// --- ⚡ OTIMIZAÇÃO LEVE (Velocidade vs Tamanho) ---
// --- 🚀 MODO "RAW" (Sem processamento) ---
// --- ⚡ OTIMIZAÇÃO DE IMAGENS ---
String _getSupabaseImage(String url, {required int width}) {
  if (!url.contains('supabase.co')) return url;

  // Tenta consertar URLs com espaços não codificados
  String urlTratada = url;
  if (url.contains(' ')) {
    urlTratada = Uri.encodeFull(url);
  }

  // Monta a URL otimizada
  return '$urlTratada?width=$width&format=webp&quality=60&resize=contain';
}

class ImagemSupabase extends StatefulWidget {
  final String url;
  final double? width;
  final BoxFit fit;

  const ImagemSupabase({
    super.key,
    required this.url,
    this.width,
    this.fit = BoxFit.cover,
  });

  @override
  State<ImagemSupabase> createState() => _ImagemSupabaseState();
}

class _ImagemSupabaseState extends State<ImagemSupabase> {
  // Chave para forçar o recarregamento do widget
  int _retryKey = 0;

  // Controle para saber se já gastamos a "vida extra" automática
  bool _tentativaAutomaticaFeita = false;

  @override
  Widget build(BuildContext context) {
    if (widget.url.isEmpty) return const Icon(Icons.broken_image, color: Colors.grey);

    // Tenta a URL otimizada
    final urlOtimizada = _getSupabaseImage(widget.url, width: 300);

    return CachedNetworkImage(
      key: ValueKey(_retryKey), // Se mudar esse valor, o componente recria do zero
      imageUrl: urlOtimizada,
      fit: widget.fit,
      memCacheWidth: 400,

      // Loading normal
      placeholder: (context, url) => Container(
        color: Colors.grey[100],
        child: const Center(
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.pink)
          )
        ),
      ),

      errorWidget: (context, url, error) {
        // --- AQUI ESTÁ A LÓGICA NOVA ---

        // Se ainda não tentamos recuperar automaticamente...
        if (!_tentativaAutomaticaFeita) {

          // Agendamos o reload para logo após o desenho da tela terminar
          // (Não podemos dar setState direto dentro do build, por isso o addPostFrameCallback)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _tentativaAutomaticaFeita = true; // Marca que já gastou a tentativa
                _retryKey++; // Força o reload
              });
            }
          });

          // Enquanto ele prepara o reload, mostra o loading ainda
          return Container(
            color: Colors.grey[100],
            child: const Center(
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.pink)
              )
            ),
          );
        }

        // --- SE CHEGOU AQUI, É PORQUE A TENTATIVA AUTOMÁTICA FALHOU ---
        // Agora mostramos o botão manual
        return InkWell(
          onTap: () {
            setState(() {
              // Reseta a flag para permitir nova tentativa automática no futuro se quiser
              // ou apenas força o reload manual agora.
              _retryKey++;
            });
          },
          child: Container(
            color: Colors.grey[200],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.refresh, color: Colors.pink),
                SizedBox(height: 4),
                Text("Recarregar", style: TextStyle(fontSize: 10, color: Colors.black54))
              ],
            ),
          ),
        );
      },
    );
  }
}
