import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_router.dart';

/// 세션 상태를 모니터링하고 사용자에게 알림을 제공하는 위젯
class SessionMonitor extends StatefulWidget {
  final Widget child;
  final int warningMinutes; // 만료 경고 시간 (분)
  
  const SessionMonitor({
    super.key,
    required this.child,
    this.warningMinutes = 5,
  });

  @override
  State<SessionMonitor> createState() => _SessionMonitorState();
}

class _SessionMonitorState extends State<SessionMonitor> {
  bool _hasShownWarning = false;
  
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // 인증되지 않은 사용자는 모니터링하지 않음
        if (!authProvider.isAuthenticated) {
          return widget.child;
        }
        
        // 세션 만료 시간 확인
        final expiryMinutes = authProvider.getSessionExpiryMinutes();
        
        // 세션이 만료된 경우
        if (expiryMinutes != null && expiryMinutes <= 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showSessionExpiredDialog(context, authProvider);
          });
        }
        // 세션 만료 경고
        else if (expiryMinutes != null && 
                 expiryMinutes <= widget.warningMinutes && 
                 !_hasShownWarning) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showSessionWarningDialog(context, authProvider, expiryMinutes);
          });
        }
        
        return widget.child;
      },
    );
  }
  
  void _showSessionWarningDialog(BuildContext context, AuthProvider authProvider, int minutes) {
    _hasShownWarning = true;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('세션 만료 경고'),
            ],
          ),
          content: Text(
            '세션이 ${minutes}분 후에 만료됩니다.\n계속 사용하시려면 세션을 연장해주세요.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // 세션 연장하지 않고 계속 사용
              },
              child: const Text('나중에'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await authProvider.refreshSession();
                  _hasShownWarning = false; // 세션 연장 후 경고 플래그 리셋
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('세션이 연장되었습니다.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('세션 연장 실패: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('세션 연장'),
            ),
          ],
        );
      },
    );
  }
  
  void _showSessionExpiredDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('세션 만료'),
            ],
          ),
          content: const Text(
            '보안을 위해 세션이 만료되었습니다.\n다시 로그인해주세요.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await authProvider.signOut();

                final rootContext = AppRouter.navigatorKey.currentContext;
                if (rootContext != null && rootContext.mounted) {
                  GoRouter.of(rootContext).go('/login');
                } else if (context.mounted) {
                  GoRouter.of(context).go('/login');
                }
              },
              child: const Text('다시 로그인'),
            ),
          ],
        );
      },
    );
  }
}

/// 세션 상태를 표시하는 인디케이터 위젯
class SessionStatusIndicator extends StatelessWidget {
  const SessionStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (!authProvider.isAuthenticated) {
          return const SizedBox.shrink();
        }
        
        final expiryMinutes = authProvider.getSessionExpiryMinutes();
        
        if (expiryMinutes == null) {
          return const SizedBox.shrink();
        }
        
        Color indicatorColor;
        IconData indicatorIcon;
        
        if (expiryMinutes <= 0) {
          indicatorColor = Colors.red;
          indicatorIcon = Icons.error;
        } else if (expiryMinutes <= 5) {
          indicatorColor = Colors.orange;
          indicatorIcon = Icons.warning;
        } else if (expiryMinutes <= 15) {
          indicatorColor = Colors.yellow;
          indicatorIcon = Icons.access_time;
        } else {
          return const SizedBox.shrink();
        }
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: indicatorColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: indicatorColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                indicatorIcon,
                size: 16,
                color: indicatorColor,
              ),
              const SizedBox(width: 4),
              Text(
                '${expiryMinutes}분',
                style: TextStyle(
                  fontSize: 12,
                  color: indicatorColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
