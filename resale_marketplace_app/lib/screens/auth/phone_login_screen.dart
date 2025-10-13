import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_app_bar.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isOtpSent = false;
  bool _isLoading = false;
  bool _isResendEnabled = false;
  int _resendTimer = 0;
  
  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CommonAppBar(
        title: '휴대폰 인증',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    _isOtpSent ? '인증번호 입력' : '휴대폰 번호 입력',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isOtpSent
                        ? '문자로 전송된 6자리 인증번호를 입력해주세요'
                        : '본인 확인을 위해 휴대폰 번호를 입력해주세요',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Phone Number Input
                  if (!_isOtpSent) ...[
                    _PhoneNumberInput(
                      controller: _phoneController,
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 24),
                    _SendOtpButton(
                      onPressed: _isLoading ? null : _sendOtp,
                      isLoading: _isLoading,
                    ),
                  ],
                  
                  // OTP Input
                  if (_isOtpSent) ...[
                    _OtpInput(
                      controller: _otpController,
                      phoneNumber: _phoneController.text,
                      enabled: !_isLoading,
                      onResend: _isResendEnabled ? _resendOtp : null,
                      resendTimer: _resendTimer,
                    ),
                    const SizedBox(height: 24),
                    _VerifyOtpButton(
                      onPressed: _isLoading ? null : _verifyOtp,
                      isLoading: _isLoading,
                    ),
                  ],
                  
                  const SizedBox(height: 40),
                  
                  // Security Notice
                  _SecurityNotice(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  void _sendOtp() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      
      // Simulate OTP sending
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isOtpSent = true;
            _resendTimer = 60;
          });
          
          // Start resend timer
          _startResendTimer();
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('인증번호가 ${_phoneController.text}로 전송되었습니다'),
              backgroundColor: Colors.green,
            ),
          );
        }
      });
    }
  }
  
  void _resendOtp() {
    setState(() {
      _isResendEnabled = false;
      _resendTimer = 60;
    });
    
    // Start resend timer
    _startResendTimer();
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('인증번호가 재전송되었습니다'),
        backgroundColor: Colors.blue,
      ),
    );
  }
  
  void _startResendTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _resendTimer--;
          if (_resendTimer <= 0) {
            _isResendEnabled = true;
          }
        });
        return _resendTimer > 0;
      }
      return false;
    });
  }
  
  void _verifyOtp() {
    if (_otpController.text.length == 6) {
      setState(() {
        _isLoading = true;
      });
      
      // Simulate OTP verification
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          // Check if user exists (simulate)
          bool isNewUser = true; // This would be determined by backend
          
          if (isNewUser) {
            // Navigate to signup completion
            context.push('/signup-complete', extra: _phoneController.text);
          } else {
            // Navigate to home (existing user)
            context.go('/home');
          }
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('6자리 인증번호를 입력해주세요'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _PhoneNumberInput extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  
  const _PhoneNumberInput({
    required this.controller,
    required this.enabled,
  });
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '휴대폰 번호',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
            _PhoneNumberFormatter(),
          ],
          decoration: InputDecoration(
            hintText: '010-0000-0000',
            prefixIcon: const Icon(Icons.phone_android),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '휴대폰 번호를 입력해주세요';
            }
            if (value.replaceAll('-', '').length < 10) {
              return '올바른 휴대폰 번호를 입력해주세요';
            }
            return null;
          },
        ),
      ],
    );
  }
}

class _OtpInput extends StatelessWidget {
  final TextEditingController controller;
  final String phoneNumber;
  final bool enabled;
  final VoidCallback? onResend;
  final int resendTimer;
  
  const _OtpInput({
    required this.controller,
    required this.phoneNumber,
    required this.enabled,
    this.onResend,
    required this.resendTimer,
  });
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '인증번호',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              phoneNumber,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: InputDecoration(
            hintText: '6자리 숫자 입력',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: TextButton(
              onPressed: onResend,
              child: Text(
                resendTimer > 0 ? '재전송 (${resendTimer}초)' : '재전송',
                style: TextStyle(
                  color: resendTimer > 0 ? Colors.grey : AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              '인증번호가 오지 않나요? 스팸 문자함을 확인해주세요',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SendOtpButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  
  const _SendOtpButton({
    this.onPressed,
    required this.isLoading,
  });
  
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                '인증번호 받기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

class _VerifyOtpButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  
  const _VerifyOtpButton({
    this.onPressed,
    required this.isLoading,
  });
  
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                '인증 확인',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

class _SecurityNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.security,
            size: 20,
            color: Colors.blue[700],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '안전한 거래를 위한 본인 인증',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '전화번호는 안전하게 암호화되어 저장되며, 마케팅 목적으로 사용되지 않습니다.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom formatter for phone numbers
class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newText = newValue.text.replaceAll('-', '');
    final buffer = StringBuffer();
    
    for (int i = 0; i < newText.length; i++) {
      if (i == 3 || i == 7) {
        buffer.write('-');
      }
      buffer.write(newText[i]);
    }
    
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}