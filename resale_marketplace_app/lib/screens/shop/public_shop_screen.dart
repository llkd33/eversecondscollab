import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/product_model.dart';
import '../../models/shop_model.dart';
import '../../services/shop_service.dart';
import '../../widgets/product_card.dart';

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
  List<ProductModel> _ownProducts = [];
  List<ProductModel> _resaleProducts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadShop();
  }

  Future<void> _loadShop() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('🔍 Public Shop 로딩 시작: shareUrl="${widget.shareUrl}"');
      
      final shop = await _shopService.getShopByShareUrl(widget.shareUrl);
      if (shop == null) {
        print('❌ Shop을 찾을 수 없음: shareUrl="${widget.shareUrl}"');
        
        // shareUrl 형식이 잘못된 경우 다른 방법으로 시도
        // shop-752d63dbd622-jzs4zu 같은 형식에서 뒤 접미사 제거해서 재시도
        if (widget.shareUrl.startsWith('shop-') && widget.shareUrl.contains('-')) {
          final parts = widget.shareUrl.split('-');
          if (parts.length >= 3) {
            final baseShareUrl = '${parts[0]}-${parts[1]}'; // shop-752d63dbd622
            print('🔄 Base shareUrl로 재시도: "$baseShareUrl"');
            final shopRetry = await _shopService.getShopByShareUrl(baseShareUrl);
            if (shopRetry != null) {
              print('✅ Base shareUrl로 샵 발견: ${shopRetry.id}');
              final results = await Future.wait<List<ProductModel>>([
                _shopService.getShopProducts(shopRetry.id),
                _shopService.getShopResaleProducts(shopRetry.id),
              ]);

              if (!mounted) return;

              setState(() {
                _shop = shopRetry;
                _ownProducts = results[0];
                _resaleProducts = results[1];
              });
              return;
            }
          }
        }
        
        throw Exception('상점을 찾을 수 없습니다. 링크가 올바른지 확인해주세요.');
      }

      print('✅ Shop 발견: ${shop.id}');

      final results = await Future.wait<List<ProductModel>>([
        _shopService.getShopProducts(shop.id),
        _shopService.getShopResaleProducts(shop.id),
      ]);

      if (!mounted) return;

      setState(() {
        _shop = shop;
        _ownProducts = results[0];
        _resaleProducts = results[1];
      });
      
      print('✅ Public Shop 로딩 완료: ${_ownProducts.length}개 상품, ${_resaleProducts.length}개 대신팔기');
    } catch (e, stackTrace) {
      print('❌ 공개 샵 로딩 실패: $e');
      print('스택 트레이스: $stackTrace');
      if (!mounted) return;
      setState(() {
        _errorMessage = '샵 정보를 불러오지 못했습니다.\n링크를 확인하고 다시 시도해주세요.\n\n오류: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadShop,
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_shop == null) {
      return const Scaffold(
        body: Center(child: Text('상점을 찾을 수 없습니다')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_shop!.name),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareShop,
            tooltip: '샵 공유',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadShop,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildShopHeader(context),
            _buildProductSection(
              context,
              title: '판매 상품',
              products: _ownProducts,
              emptyMessage: '판매중인 상품이 없습니다',
            ),
            _buildProductSection(
              context,
              title: '대신팔기 상품',
              products: _resaleProducts,
              emptyMessage: '대신팔기 상품이 없습니다',
              badgeColor: Colors.green,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildShopHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
            Theme.of(context).colorScheme.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.storefront,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _shop!.name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_ownProducts.length + _resaleProducts.length}개의 상품을 판매중이에요',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[700],
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_shop!.description != null && _shop!.description!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              _shop!.description!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductSection(
    BuildContext context, {
    required String title,
    required List<ProductModel> products,
    required String emptyMessage,
    Color? badgeColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (badgeColor ?? Theme.of(context).colorScheme.primary)
                      .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${products.length}개',
                  style: TextStyle(
                    fontSize: 12,
                    color: badgeColor ?? Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (products.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey[500]),
                  const SizedBox(height: 8),
                  Text(
                    emptyMessage,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (context, index) {
                final product = products[index];
                return ProductCard(
                  product: product,
                  onTap: () => context.push('/product/detail/${product.id}'),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _shareShop() async {
    if (_shop?.shareUrl == null || _shop!.shareUrl!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('샵 링크를 생성할 수 없습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final webLink = 'https://app.everseconds.com/shop/${_shop!.shareUrl}';
    final appLink = 'resale://shop/${_shop!.shareUrl}';
    final message = '${_shop!.name}의 샵을 확인해보세요!\n\n앱에서 보기: $appLink\n웹에서 보기: $webLink';

    try {
      await Share.share(
        message,
        subject: '${_shop!.name} 샵 공유',
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: webLink));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공유가 지원되지 않아 웹 링크를 복사했습니다')),
      );
    }
  }
}
