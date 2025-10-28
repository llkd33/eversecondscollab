import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Widget? leading;
  final bool centerTitle;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double elevation;

  const CommonAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBackButton = false,
    this.onBackPressed,
    this.leading,
    this.centerTitle = true,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation = 0,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: actions,
      leading: leading ?? (showBackButton ? _buildBackButton(context) : null),
      centerTitle: centerTitle,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: elevation,
      surfaceTintColor: Colors.transparent,
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios),
      onPressed: onBackPressed ?? () => context.pop(),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// 홈 화면용 특별한 AppBar
class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onSearchPressed;
  final VoidCallback? onAddPressed;

  const HomeAppBar({
    super.key,
    this.onSearchPressed,
    this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          Icon(
            Icons.store,
            color: Theme.of(context).primaryColor,
            size: 28,
          ),
          const SizedBox(width: 8),
          const Text(
            '에버세컨즈',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      centerTitle: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: onSearchPressed ?? () {
            // TODO: 검색 기능 구현
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('검색 기능 준비중입니다')),
            );
          },
        ),
        Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            // 로그인한 사용자만 추가 버튼 표시
            if (!authProvider.isAuthenticated) {
              return const SizedBox.shrink();
            }
            return IconButton(
              icon: const Icon(Icons.add),
              onPressed: onAddPressed ?? () {
                context.push('/product/create');
              },
            );
          },
        ),
        const SizedBox(width: 8),
      ],
      surfaceTintColor: Colors.transparent,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// 채팅 화면용 AppBar
class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onNotificationPressed;

  const ChatAppBar({
    super.key,
    this.onNotificationPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('채팅'),
      actions: [
        IconButton(
          icon: Stack(
            children: [
              const Icon(Icons.notifications_outlined),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 8,
                    minHeight: 8,
                  ),
                ),
              ),
            ],
          ),
          onPressed: onNotificationPressed ?? () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('알림 기능 준비중입니다')),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
      surfaceTintColor: Colors.transparent,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// 내 샵 화면용 AppBar
class ShopAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onSharePressed;

  const ShopAppBar({
    super.key,
    this.onSharePressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('내 샵'),
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined),
          onPressed: onSharePressed ?? () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('샵 링크가 클립보드에 복사되었습니다')),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
      surfaceTintColor: Colors.transparent,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// 프로필 화면용 AppBar
class ProfileAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onSettingsPressed;

  const ProfileAppBar({
    super.key,
    this.onSettingsPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('마이페이지'),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: onSettingsPressed ?? () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('설정 기능 준비중입니다')),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
      surfaceTintColor: Colors.transparent,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}