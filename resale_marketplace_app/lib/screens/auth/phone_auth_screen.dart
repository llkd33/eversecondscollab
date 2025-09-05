import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import 'dart:async';

class PhoneAuthScreen extends StatefulWidget {
  final bool isSignup;
  
  const PhoneAuthScreen({
    super.key,
    this.isSignup = false,
  });

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  
  bool _isOtpSent = false;
  bool _isLoading = false;
  bool _isNewUser = false;
  int _remainingSeconds = 0;
  Timer? _timer;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _timer?.cancel();
    super.dispose();
  }
  
  void _startTimer() {
    _remainingSeconds = 180; // 3분
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }
  
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
  
  String _formatPhoneNumber(String value) {
    // 숫자만 추출
    final numbers = value.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (numbers.length <= 3) {
      return numbers;
    } else if (numbers.length <= 7) {
      return '${numbers.substring(0, 3)}-${numbers.substring(3)}';
    } else if (numbers.length <= 11) {
      return '${numbers.substring(0, 3)}-${numbers.substring(3, 7)}-${numbers.substring(7)}';
    }
    
    return '${numbers.substring(0, 3)}-${numbers.substring(3, 7)}-${numbers.substring(7, 11)}';
  }
  
  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.isSignup ? '회원가입' : '전화번호 로그인',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Section
                if (!_isOtpSent) ...[
                  const Text(
                    '전화번호를 입력해주세요',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '인증번호를 SMS로 발송해드립니다',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ] else ...[
                  const Text(
                    '인증번호를 입력해주세요',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      children: [
                        TextSpan(
                          text: _formatPhoneNumber(_phoneController.text),
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const TextSpan(text: '로 발송된 인증번호를 입력해주세요'),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 32),
                
                // Input Section
                if (!_isOtpSent) ...[
                  // Phone Number Input
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 13,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _PhoneNumberFormatter(),
                    ],
                    decoration: InputDecoration(
                      hintText: '010-1234-5678',
                      prefixIcon: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '🇰🇷 +82',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      counterText: '',
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                ] else ...[
                  // OTP Input
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      hintText: '인증번호 6자리',
                      prefixIcon: const Icon(Icons.lock_outline),
                      counterText: '',
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                      suffixIcon: _remainingSeconds > 0
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _formatTime(_remainingSeconds),
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                  
                  // Name input for new users
                  if (_isNewUser) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: '이름 (선택사항)',
                        prefixIcon: const Icon(Icons.person_outline),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppTheme.primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 12),
                  
                  // Resend Button
                  if (_remainingSeconds == 0)
                    TextButton(
                      onPressed: _isLoading ? null : _sendOTP,
                      child: Text(
                        '인증번호 재전송',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
                
                const SizedBox(height: 24),
                
                // Action Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _getButtonEnabled() && !_isLoading
                        ? _isOtpSent ? _verifyOTP : _sendOTP
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _isOtpSent 
                                ? (_isNewUser ? '가입하기' : '로그인')
                                : '인증번호 받기',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                
                // Error Message
                if (authProvider.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            authProvider.errorMessage!,
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const Spacer(),
                
                // Terms
                Text(
                  '계속 진행하면 이용약관 및 개인정보처리방침에\n동의하는 것으로 간주됩니다',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  bool _getButtonEnabled() {
    if (!_isOtpSent) {
      // 전화번호가 11자리인지 확인 (하이픈 제외)
      final numbers = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
      return numbers.length == 11 && numbers.startsWith('010');
    } else {
      // OTP가 6자리인지 확인
      return _otpController.text.length == 6;
    }
  }
  
  Future<void> _sendOTP() async {
    final authProvider = context.read<AuthProvider>();
    authProvider.clearError();
    
    setState(() {
      _isLoading = true;
    });
    
    final phone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final success = await authProvider.sendOTP(phone);
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (success) {
          _isOtpSent = true;
          _isNewUser = widget.isSignup;
          _startTimer();
        }
      });
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('인증번호가 발송되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
  
  Future<void> _verifyOTP() async {
    final authProvider = context.read<AuthProvider>();
    authProvider.clearError();
    
    setState(() {
      _isLoading = true;
    });
    
    final phone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final success = await authProvider.verifyOTP(
      phone: phone,
      otp: _otpController.text,
      name: _isNewUser && _nameController.text.isNotEmpty 
          ? _nameController.text.trim() 
          : null,
    );
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      
      if (success) {
        _timer?.cancel();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isNewUser 
                  ? '회원가입이 완료되었습니다!' 
                  : '로그인되었습니다!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        
        // 리디렉션 파라미터 확인
        final redirect = GoRouterState.of(context).uri.queryParameters['redirect'];
        if (redirect != null && redirect.isNotEmpty) {
          context.go(redirect);
        } else {
          context.go('/');
        }
      }
    }
  }
}

// 전화번호 포맷터
class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (newText.length <= 3) {
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    } else if (newText.length <= 7) {
      final formatted = '${newText.substring(0, 3)}-${newText.substring(3)}';
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    } else if (newText.length <= 11) {
      final formatted = '${newText.substring(0, 3)}-${newText.substring(3, 7)}-${newText.substring(7)}';
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    
    return oldValue;
  }
}