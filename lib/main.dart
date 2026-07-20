import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const siteUrl = 'https://delhicakes.com';
const apiBase = '$siteUrl/wp-json/wc/store/v1';

void main() => runApp(const DelhiCakesApp());

class DelhiCakesApp extends StatelessWidget {
  const DelhiCakesApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFE91E63);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DelhiCakes',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        scaffoldBackgroundColor: const Color(0xFFFFF8FA),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF2A1720),
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const StoreScreen(),
    );
  }
}

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final searchController = TextEditingController();
  final scrollController = ScrollController();
  List<Product> products = [];
  List<Category> categories = [];
  bool loading = true;
  bool loadingMore = false;
  String? error;
  int page = 1;
  int? categoryId;
  String search = '';

  @override
  void initState() {
    super.initState();
    loadInitial();
    scrollController.addListener(() {
      if (scrollController.position.pixels >
          scrollController.position.maxScrollExtent - 500) {
        loadMore();
      }
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> loadInitial() async {
    setState(() { loading = true; error = null; });
    try {
      final results = await Future.wait([
        StoreApi.fetchCategories(),
        StoreApi.fetchProducts(page: 1),
      ]);
      if (!mounted) return;
      setState(() {
        categories = results[0] as List<Category>;
        products = results[1] as List<Product>;
        page = 1;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { error = e.toString(); loading = false; });
    }
  }

  Future<void> reloadProducts() async {
    setState(() { loading = true; error = null; page = 1; });
    try {
      final result = await StoreApi.fetchProducts(
        page: 1, categoryId: categoryId, search: search);
      if (!mounted) return;
      setState(() { products = result; loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { error = e.toString(); loading = false; });
    }
  }

  Future<void> loadMore() async {
    if (loading || loadingMore) return;
    setState(() => loadingMore = true);
    try {
      final next = await StoreApi.fetchProducts(
        page: page + 1, categoryId: categoryId, search: search);
      if (!mounted) return;
      setState(() {
        if (next.isNotEmpty) { page++; products.addAll(next); }
        loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => loadingMore = false);
    }
  }

  void submitSearch() {
    FocusScope.of(context).unfocus();
    search = searchController.text.trim();
    reloadProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          CircleAvatar(
            backgroundColor: Color(0xFFFFE3EC),
            child: Icon(Icons.cake_rounded, color: Color(0xFFE91E63)),
          ),
          SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('DelhiCakes',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            Text('Cakes & gifts across Delhi NCR',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400)),
          ]),
        ]),
        actions: [
          IconButton(
            onPressed: () => openExternal('$siteUrl/cart/'),
            icon: const Icon(Icons.shopping_bag_outlined),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: reloadProducts,
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverToBoxAdapter(child: hero()),
            SliverToBoxAdapter(child: searchBox()),
            SliverToBoxAdapter(child: categoryStrip()),
            if (loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()))
            else if (error != null)
              SliverFillRemaining(child: errorView())
            else if (products.isEmpty)
              const SliverFillRemaining(
                child: Center(child: Text('No products found.')))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                sliver: SliverGrid.builder(
                  itemCount: products.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: .66,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemBuilder: (_, i) => ProductCard(
                    product: products[i],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductScreen(product: products[i]),
                      ),
                    ),
                  ),
                ),
              ),
            if (loadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget hero() => Container(
    margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        colors: [Color(0xFFE91E63), Color(0xFFFF6F91)]),
    ),
    child: const Row(children: [
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Make every moment sweeter',
            style: TextStyle(
              color: Colors.white, fontSize: 23, fontWeight: FontWeight.w800)),
          SizedBox(height: 7),
          Text('Browse live products from DelhiCakes.com',
            style: TextStyle(color: Colors.white)),
        ],
      )),
      Icon(Icons.celebration_rounded, color: Colors.white, size: 55),
    ]),
  );

  Widget searchBox() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
    child: TextField(
      controller: searchController,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => submitSearch(),
      decoration: InputDecoration(
        hintText: 'Search cakes, flowers and gifts',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          onPressed: submitSearch,
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );

  Widget categoryStrip() {
    final visible = categories
      .where((c) => c.count > 0 && c.name.toLowerCase() != 'uncategorized')
      .take(20).toList();
    return SizedBox(
      height: 54,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('All'),
              selected: categoryId == null,
              onSelected: (_) { categoryId = null; reloadProducts(); },
            ),
          ),
          ...visible.map((c) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(c.name),
              selected: categoryId == c.id,
              onSelected: (_) { categoryId = c.id; reloadProducts(); },
            ),
          )),
        ],
      ),
    );
  }

  Widget errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_rounded, size: 52),
        const SizedBox(height: 12),
        const Text('Products could not be loaded.',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(error ?? '', textAlign: TextAlign.center),
        const SizedBox(height: 14),
        FilledButton(onPressed: loadInitial, child: const Text('Retry')),
      ]),
    ),
  );
}

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  const ProductCard({super.key, required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: InkWell(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Hero(
          tag: 'product-${product.id}',
          child: ProductImage(url: product.image),
        )),
        Padding(
          padding: const EdgeInsets.fromLTRB(11, 10, 11, 4),
          child: Text(product.name, maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(11, 2, 11, 10),
          child: Text(product.formattedPrice,
            style: const TextStyle(
              color: Color(0xFFE91E63),
              fontWeight: FontWeight.w800, fontSize: 16)),
        ),
      ]),
    ),
  );
}

class ProductScreen extends StatelessWidget {
  final Product product;
  const ProductScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Product details')),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.all(12),
      child: FilledButton.icon(
        onPressed: () => openExternal(product.permalink),
        icon: const Icon(Icons.shopping_bag_rounded),
        label: const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Text('Choose options & order'),
        ),
      ),
    ),
    body: ListView(children: [
      AspectRatio(
        aspectRatio: 1,
        child: Hero(
          tag: 'product-${product.id}',
          child: ProductImage(url: product.image),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
        child: Text(product.name,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Text(product.formattedPrice,
          style: const TextStyle(
            color: Color(0xFFE91E63),
            fontWeight: FontWeight.w800, fontSize: 21)),
      ),
      if (product.shortDescription.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
          child: Text(product.shortDescription,
            style: const TextStyle(fontSize: 15, height: 1.45)),
        ),
      const Padding(
        padding: EdgeInsets.fromLTRB(18, 14, 18, 6),
        child: Text('Delivery and customisation',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, 24),
        child: Text(
          'Weight, delivery date, time slot, cake message, image upload and '
          'payment are completed securely on DelhiCakes.com so all existing '
          'WooCommerce options continue to work.',
          style: TextStyle(height: 1.45),
        ),
      ),
    ]),
  );
}

class ProductImage extends StatelessWidget {
  final String url;
  const ProductImage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return Container(
      color: const Color(0xFFFFE9F0),
      child: const Center(
        child: Icon(Icons.cake_outlined, size: 60, color: Color(0xFFE91E63))),
    );
    return Image.network(
      url, fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFFFFE9F0),
        child: const Center(child: Icon(Icons.broken_image_outlined))),
    );
  }
}

class StoreApi {
  static Future<List<Product>> fetchProducts({
    int page = 1, int? categoryId, String search = ''}) async {
    final params = <String, String>{
      'per_page': '20', 'page': '$page', 'orderby': 'date', 'order': 'desc'};
    if (categoryId != null) params['category'] = '$categoryId';
    if (search.isNotEmpty) params['search'] = search;
    final uri = Uri.parse('$apiBase/products').replace(queryParameters: params);
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('Store API error ${response.statusCode}');
    }
    return (jsonDecode(response.body) as List)
      .map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<Category>> fetchCategories() async {
    final uri = Uri.parse('$apiBase/products/categories').replace(
      queryParameters: {
        'per_page': '100', 'orderby': 'count', 'order': 'desc'});
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('Category API error ${response.statusCode}');
    }
    return (jsonDecode(response.body) as List)
      .map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }
}

class Product {
  final int id;
  final String name;
  final String permalink;
  final String image;
  final String formattedPrice;
  final String shortDescription;

  Product({
    required this.id, required this.name, required this.permalink,
    required this.image, required this.formattedPrice,
    required this.shortDescription});

  factory Product.fromJson(Map<String, dynamic> json) {
    final images = (json['images'] as List? ?? []);
    final prices = json['prices'] as Map<String, dynamic>? ?? {};
    final unit = (prices['currency_minor_unit'] as num?)?.toInt() ?? 2;
    final raw = double.tryParse('${prices['price'] ?? 0}') ?? 0;
    final amount = raw / pow10(unit);
    final first = images.isEmpty ? null : images.first as Map<String, dynamic>;
    return Product(
      id: (json['id'] as num).toInt(),
      name: '${json['name'] ?? ''}',
      permalink: '${json['permalink'] ?? siteUrl}',
      image: first == null ? '' : '${first['thumbnail'] ?? first['src'] ?? ''}',
      formattedPrice: '${prices['currency_symbol'] ?? '₹'}${amount.toStringAsFixed(0)}',
      shortDescription: stripHtml('${json['short_description'] ?? ''}'),
    );
  }
}

class Category {
  final int id;
  final String name;
  final int count;
  Category({required this.id, required this.name, required this.count});

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: (json['id'] as num).toInt(),
    name: '${json['name'] ?? ''}',
    count: (json['count'] as num?)?.toInt() ?? 0,
  );
}

Future<void> openExternal(String value) async {
  final uri = Uri.parse(value);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

String stripHtml(String value) => value
  .replaceAll(RegExp(r'<[^>]*>'), ' ')
  .replaceAll('&amp;', '&')
  .replaceAll('&#8377;', '₹')
  .replaceAll(RegExp(r'\s+'), ' ')
  .trim();

double pow10(int value) {
  var result = 1.0;
  for (var i = 0; i < value; i++) result *= 10;
  return result;
}
