import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/shop_model.dart';
import '../../services/shop_service.dart';
import '../../widgets/safe_network_image.dart';

class PublicShopScreen extends StatefulWidget {
  final String shareUrl;
  
  const PublicShopScreen({
    Key? key,
    required this.shareUrl,
  }) : super(key: key);

  @override
  State<PublicShopScreen> createState() => _PublicShopScreenState();
}

class _PublicShopScreenState extends State<PublicShopScreen> {
  final ShopService _shopService = ShopService();
  ShopModel? _shop;
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadShopByUrl();
  }

  Future<void> _loadShopByUrl() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Extract shop ID from share URL
      final shopId = _extractShopIdFromUrl(widget.shareUrl);
      if (shopId == null) {
        throw Exception('잘못된 공유 링크입니다');
      }

      final shop = await _shopService.getShopById(shopId);
      if (shop != null) {
        setState(() {
          _shop = shop;
        });

        // Load shop products
        final products = await _shopService.getShopProducts(shopId);
        setState(() {
          _products = products.map((p) => p.toJson()).toList();
        });
      } else {
        throw Exception('상점을 찾을 수 없습니다');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String? _extractShopIdFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    
    final pathSegments = uri.pathSegments;
    final shopIndex = pathSegments.indexOf('shop');
    if (shopIndex != -1 && shopIndex < pathSegments.length - 1) {
      return pathSegments[shopIndex + 1];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadShopByUrl,
                child: Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    if (_shop == null) {
      return Scaffold(
        body: Center(
          child: Text('상점을 찾을 수 없습니다'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_shop!.name),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shop header
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.store,
                    size: 80,
                    color: Theme.of(context).primaryColor,
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _shop!.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (_shop!.description != null) ...[
                          SizedBox(height: 8),
                          Text(
                            _shop!.description!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            Divider(),
            
            // Products grid
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '판매 상품',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: 16),
                  _products.isEmpty
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Text(
                              '등록된 상품이 없습니다',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        )
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            final product = _products[index];
                            final images = product['images'] as List<dynamic>?;
                            final firstImage = images?.isNotEmpty == true
                                ? images![0]['image_url']
                                : null;
                            
                            return Card(
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: SafeNetworkImage(
                                      imageUrl: firstImage,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product['title'] ?? '',
                                          style: Theme.of(context).textTheme.bodyMedium,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          '₩${product['price'] ?? 0}',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
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