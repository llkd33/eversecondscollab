import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isLoading = false;
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    // 카카오 SDK 초기화는 main.dart에서 처리됨
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeInOut),
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
    ));
    
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryColor.withOpacity(0.1),
              Colors.white,
            ],
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
                        onLongPress: _openDevTools,
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
                                      color: AppTheme.primaryColor.withOpacity(0.3),
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
                
                // Phone + Password Login Section
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        // Phone field
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: '전화번호 (010-1234-5678)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Password field
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: '비밀번호',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (_isLoading) return;
                              final phone = _phoneController.text.trim();
                              final normalizedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
                              final password = _passwordController.text;
                              if (phone.isEmpty || password.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('전화번호와 비밀번호를 입력해주세요')),
                                );
                                return;
                              }
                              setState(() => _isLoading = true);
                              final authProvider = context.read<AuthProvider>();
                              final ok = await authProvider.signInWithPhonePassword(
                                phone: normalizedPhone,
                                password: password,
                              );
                              setState(() => _isLoading = false);
                              if (ok && mounted) {
                                context.go('/');
                              } else if (mounted && authProvider.errorMessage != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(authProvider.errorMessage!)),
                                );
                              }
                            },
                            child: const Text('로그인'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => context.push('/signup'),
                            child: const Text('회원가입'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Phone Login Button (Primary)
                        // Kakao login remains below as SSO option
                        
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
                        
                        // Test account (local session) — full access without real account
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton(
                            onPressed: () async {
                              if (_isLoading) return;
                              final auth = context.read<AuthProvider>();
                              setState(() => _isLoading = true);
                              final ok = await auth.signInWithTestAccount();
                              setState(() => _isLoading = false);
                              if (ok && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('테스트 모드로 둘러보기 시작')),
                                );
                                context.go('/');
                              } else if (mounted && auth.errorMessage != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(auth.errorMessage!)),
                                );
                              }
                            },
                            child: const Text('테스트 계정으로 보기'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Browse as guest
                        TextButton(
                          onPressed: () {
                            // 로그인 없이 홈으로 이동
                            context.go('/');
                          },
                        child: Text(
                          '둘러보기',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                        // 테스트 로그인 제거
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
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
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
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
    
    try {
      // TODO: 카카오 로그인 연동. 현재는 가입 단계로 이동
      if (mounted) Navigator.pop(context);
      if (mounted) context.push('/signup/kakao');
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        String errorMessage = '카카오 로그인 중 오류가 발생했습니다.';
        
        // 에러 타입별 메시지 처리
        if (e.toString().contains('카카오 SDK가 설정되지 않았습니다')) {
          errorMessage = '카카오 로그인이 설정되지 않았습니다. 관리자에게 문의해주세요.';
        } else if (e.toString().contains('이메일 정보가 필요합니다')) {
          errorMessage = '카카오 계정에서 이메일을 공개로 설정해주세요.';
        } else if (e.toString().contains('닉네임 정보가 필요합니다')) {
          errorMessage = '카카오 계정에 닉네임을 설정해주세요.';
        }
        
        _showErrorDialog(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

  void _showPhoneVerificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('전화번호 인증 필요'),
        content: const Text(
          '안전한 거래를 위해 전화번호 인증이 필요합니다.\n'
          '전화번호 인증을 진행하시겠습니까?'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/home'); // 나중에 인증하기
            },
            child: const Text('나중에'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/phone-auth');
            },
            child: const Text('인증하기'),
          ),
        ],
      ),
    );
  }

  // Developer tools: create/sign-in test account in Supabase
  void _openDevTools() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Developer Tools'),
          content: const Text('테스트 계정(010-9999-0001 / test1234)을 Supabase에 생성/로그인합니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_isLoading) return;
                Navigator.pop(context); // close dialog
                await _runDevCreateTest();
              },
              child: const Text('실행'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _runDevCreateTest() async {
    setState(() => _isLoading = true);
    final auth = AuthService();
    try {
      final user = await auth.signInOrCreateTestUser();
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('테스트 계정 준비 완료 (Supabase)')), 
        );
        // Navigate home; AuthProvider will react to auth state change
        context.go('/');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('테스트 계정 처리 결과가 비어있습니다.')), 
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('테스트 계정 처리 실패: $e')),
      );
    }
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String text;
  
  const _FeatureChip({
    required this.icon,
    required this.text,
  });
  
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
          Icon(
            icon,
            size: 14,
            color: AppTheme.primaryColor,
          ),
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
