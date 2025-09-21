import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  final String? redirectPath;

  const LoginScreen({super.key, this.redirectPath});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isLoading = false;
  bool _hasNavigatedAfterSignIn = false;

  @override
  void initState() {
    super.initState();
    // 카카오 SDK 초기화는 main.dart에서 처리됨

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeInOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    _maybeRedirectAfterLogin(authProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.primaryColor.withOpacity(0.1), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(flex: 1),

                // Logo and Title Section
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      // Animated Logo
                      // Hidden Dev: long-press logo to open dev tools
                      GestureDetector(
                        onLongPress: null,
                        child: TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 800),
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryColor.withOpacity(
                                        0.3,
                                      ),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.storefront,
                                  size: 60,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      Text(
                        '에버세컨즈',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[900],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Subtitle with gradient
                      ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.secondaryColor,
                          ],
                        ).createShader(bounds),
                        child: const Text(
                          '대신팔기로 더 많은 수익을!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Features
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _FeatureChip(icon: Icons.security, text: '안전거래'),
                          const SizedBox(width: 12),
                          _FeatureChip(icon: Icons.bolt, text: '빠른정산'),
                          const SizedBox(width: 12),
                          _FeatureChip(icon: Icons.trending_up, text: '수수료혜택'),
                        ],
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 2),

                // Kakao Login Section
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        const Text(
                          '카카오 계정으로만 로그인할 수 있습니다.',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        // Kakao Login Button
                        _LoginButton(
                          onPressed: () {
                            _handleKakaoLogin();
                          },
                          backgroundColor: const Color(0xFFFEE500),
                          foregroundColor: Colors.black87,
                          icon: Image.asset(
                            'assets/icons/kakao_icon.png',
                            width: 24,
                            height: 24,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.message, size: 20);
                            },
                          ),
                          text: '카카오로 로그인',
                          isElevated: false,
                        ),

                        const SizedBox(height: 24),

                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () {
                            context.go('/');
                          },
                          child: Text(
                            '로그인 없이 둘러보기',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(flex: 1),

                // Terms and Privacy
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      Text(
                        '계속 진행하면 다음에 동의하는 것으로 간주됩니다',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              // Show terms
                            },
                            child: Text(
                              '이용약관',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          Text(
                            ' • ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              // Show privacy policy
                            },
                            child: Text(
                              '개인정보처리방침',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _maybeRedirectAfterLogin(AuthProvider authProvider) {
    if (_hasNavigatedAfterSignIn) return;
    if (!authProvider.isAuthenticated || authProvider.currentUser == null) {
      return;
    }

    _hasNavigatedAfterSignIn = true;
    final target =
        (widget.redirectPath != null && widget.redirectPath!.trim().isNotEmpty)
        ? widget.redirectPath!
        : '/';

    Future.microtask(() {
      if (!mounted) return;
      context.go(target);
    });
  }

  void _handleKakaoLogin() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              '카카오 로그인 중...',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );

    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.signInWithKakao(
        redirectPath: widget.redirectPath,
      );

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('카카오 로그인 페이지로 이동합니다.')));
      } else if (mounted && authProvider.errorMessage != null) {
        _showErrorDialog(_getKakaoErrorMessage(authProvider.errorMessage!));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        _showErrorDialog(_getKakaoErrorMessage(e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getKakaoErrorMessage(String error) {
    if (error.contains('카카오 SDK가 설정되지 않았습니다')) {
      return '카카오 로그인이 설정되지 않았습니다. 관리자에게 문의해주세요.';
    } else if (error.contains('이메일 정보가 필요합니다')) {
      return '카카오 계정에서 이메일을 공개로 설정해주세요.';
    } else if (error.contains('닉네임 정보가 필요합니다')) {
      return '카카오 계정에 닉네임을 설정해주세요.';
    } else if (error.contains('카카오 로그인이 취소되었습니다')) {
      return '로그인이 취소되었습니다.';
    } else if (error.contains('카카오 인증에 실패했습니다')) {
      return '카카오 인증에 실패했습니다. 다시 시도해주세요.';
    }
    return '카카오 로그인 중 오류가 발생했습니다.';
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그인 실패'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final Widget icon;
  final String text;
  final bool isElevated;

  const _LoginButton({
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.text,
    required this.isElevated,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: isElevated
          ? ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: backgroundColor,
                foregroundColor: foregroundColor,
                elevation: 2,
                shadowColor: backgroundColor.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(width: 12),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                backgroundColor: backgroundColor,
                foregroundColor: foregroundColor,
                side: BorderSide(color: Colors.grey[300]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(width: 12),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
