import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

/// 인증이 필요한 화면을 보호하는 가드 위젯
/// 로그인되지 않은 사용자는 로그인 화면으로 리디렉션
class AuthGuard extends StatelessWidget {
  final Widget child;
  final String? redirectPath;
  final bool allowGuest;
  final List<String>? requiredRoles; // 필요한 권한 목록
  final bool requireVerification; // 인증 확인 필요 여부
  
  const AuthGuard({
    super.key,
    required this.child,
    this.redirectPath,
    this.allowGuest = false,
    this.requiredRoles,
    this.requireVerification = false,
  });
  
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // 게스트 허용 모드
        if (allowGuest) {
          return child;
        }
        
        // 인증 확인
        if (!authProvider.isAuthenticated) {
          return _buildLoginRequiredScreen(context);
        }
        
        // 세션 유효성 확인
        if (!authProvider.isSessionValid()) {
          return _buildSessionExpiredScreen(context);
        }
        
        // 인증 확인 필요 여부 체크
        if (requireVerification && authProvider.currentUser?.isVerified != true) {
          return _buildVerificationRequiredScreen(context);
        }
        
        // 권한 확인
        if (requiredRoles != null && requiredRoles!.isNotEmpty) {
          final userRole = authProvider.currentUser?.role ?? '';
          if (!requiredRoles!.contains(userRole)) {
            return _buildAccessDeniedScreen(context, userRole);
          }
        }
        
        return child;
      },
    );
  }
  
  Widget _buildLoginRequiredScreen(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 24),
              const Text(
                '로그인이 필요합니다',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '이 기능을 사용하려면 로그인해주세요',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // 현재 경로를 저장하고 로그인 화면으로 이동
                    final currentPath = GoRouterState.of(context).uri.toString();
                    context.push('/login?redirect=$currentPath');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '로그인하기',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Test view: local session with full access
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    final auth = context.read<AuthProvider>();
                    final ok = await auth.signInWithTestAccount();
                    if (ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('테스트 모드로 둘러보기 시작')),
                      );
                      // Stay on current screen, it will rebuild with auth
                    } else if (auth.errorMessage != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(auth.errorMessage!)),
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('테스트 계정으로 보기'),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  context.go('/');
                },
                child: Text(
                  '홈으로 돌아가기',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSessionExpiredScreen(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.access_time,
                size: 80,
                color: Colors.orange[400],
              ),
              const SizedBox(height: 24),
              const Text(
                '세션이 만료되었습니다',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '보안을 위해 세션이 만료되었습니다.\n다시 로그인해주세요.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final authProvider = context.read<AuthProvider>();
                    await authProvider.signOut();
                    context.go('/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '다시 로그인',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildVerificationRequiredScreen(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 80,
                color: Colors.blue[400],
              ),
              const SizedBox(height: 24),
              const Text(
                '인증이 필요합니다',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '이 기능을 사용하려면 전화번호 인증이 필요합니다.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    context.push('/phone-auth?verification=true');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '인증하기',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  context.go('/');
                },
                child: Text(
                  '홈으로 돌아가기',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildAccessDeniedScreen(BuildContext context, String userRole) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.block,
                size: 80,
                color: Colors.red[400],
              ),
              const SizedBox(height: 24),
              const Text(
                '접근 권한이 없습니다',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '현재 권한($userRole)으로는 이 기능에 접근할 수 없습니다.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    context.go('/');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '홈으로 돌아가기',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 조건부 인증 가드
/// 특정 조건에 따라 인증 필요 여부를 결정
class ConditionalAuthGuard extends StatelessWidget {
  final Widget child;
  final Widget guestWidget;
  final bool Function()? customCondition;
  
  const ConditionalAuthGuard({
    super.key,
    required this.child,
    required this.guestWidget,
    this.customCondition,
  });
  
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // 커스텀 조건이 있으면 우선 적용
        if (customCondition != null && customCondition!()) {
          return child;
        }
        
        // 인증 여부에 따라 위젯 선택
        if (authProvider.isAuthenticated) {
          return child;
        } else {
          return guestWidget;
        }
      },
    );
  }
}

/// 인증 필요 액션 버튼
/// 로그인하지 않은 사용자가 클릭시 로그인 유도
class AuthRequiredButton extends StatelessWidget {
  final VoidCallback onAuthenticated;
  final Widget child;
  final ButtonStyle? style;
  final String? loginMessage;
  
  const AuthRequiredButton({
    super.key,
    required this.onAuthenticated,
    required this.child,
    this.style,
    this.loginMessage,
  });
  
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        return ElevatedButton(
          onPressed: () {
            if (authProvider.isAuthenticated) {
              onAuthenticated();
            } else {
              _showLoginDialog(context);
            }
          },
          style: style,
          child: child,
        );
      },
    );
  }
  
  void _showLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('로그인 필요'),
          content: Text(
            loginMessage ?? '이 기능을 사용하려면 로그인이 필요합니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                final auth = context.read<AuthProvider>();
                final ok = await auth.signInWithTestAccount();
                Navigator.of(context).pop();
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('테스트 모드로 둘러보기 시작')),
                  );
                } else if (auth.errorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(auth.errorMessage!)),
                  );
                }
              },
              child: const Text('테스트 계정으로 보기'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                final currentPath = GoRouterState.of(context).uri.toString();
                context.push('/login?redirect=$currentPath');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: const Text(
                '로그인',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 인증 상태에 따른 가시성 제어 위젯
class AuthVisibility extends StatelessWidget {
  final Widget child;
  final bool showWhenAuthenticated;
  final Widget? placeholder;
  
  const AuthVisibility({
    super.key,
    required this.child,
    this.showWhenAuthenticated = true,
    this.placeholder,
  });
  
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final shouldShow = showWhenAuthenticated 
            ? authProvider.isAuthenticated 
            : !authProvider.isAuthenticated;
        
        if (shouldShow) {
          return child;
        } else {
          return placeholder ?? const SizedBox.shrink();
        }
      },
    );
  }
}

/// 관리자 전용 가드 위젯
class AdminGuard extends StatelessWidget {
  final Widget child;
  final Widget? fallback;
  
  const AdminGuard({
    super.key,
    required this.child,
    this.fallback,
  });
  
  @override
  Widget build(BuildContext context) {
    return AuthGuard(
      requiredRoles: const ['관리자'], // Korean role name
      child: child,
    );
  }
}

/// 권한별 가시성 제어 위젯
class RoleVisibility extends StatelessWidget {
  final Widget child;
  final List<String> allowedRoles;
  final Widget? placeholder;
  
  const RoleVisibility({
    super.key,
    required this.child,
    required this.allowedRoles,
    this.placeholder,
  });
  
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (!authProvider.isAuthenticated) {
          return placeholder ?? const SizedBox.shrink();
        }
        
        final userRole = authProvider.currentUser?.role ?? '';
        final hasPermission = allowedRoles.contains(userRole);
        
        if (hasPermission) {
          return child;
        } else {
          return placeholder ?? const SizedBox.shrink();
        }
      },
    );
  }
}
