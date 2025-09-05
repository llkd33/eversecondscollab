import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_app_bar.dart';

class SignupCompleteScreen extends StatefulWidget {
  final String phoneNumber;
  
  const SignupCompleteScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<SignupCompleteScreen> createState() => _SignupCompleteScreenState();
}

class _SignupCompleteScreenState extends State<SignupCompleteScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _agreedToTerms = false;
  bool _agreedToPrivacy = false;
  bool _agreedToMarketing = false;
  
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CommonAppBar(
        title: '회원가입',
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
                  // Welcome Message
                  _WelcomeSection(phoneNumber: widget.phoneNumber),
                  
                  const SizedBox(height: 32),
                  
                  // Name Input
                  _NameInput(
                    controller: _nameController,
                    enabled: !_isLoading,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Terms Agreement
                  _TermsAgreement(
                    agreedToTerms: _agreedToTerms,
                    agreedToPrivacy: _agreedToPrivacy,
                    agreedToMarketing: _agreedToMarketing,
                    onTermsChanged: (value) {
                      setState(() {
                        _agreedToTerms = value;
                      });
                    },
                    onPrivacyChanged: (value) {
                      setState(() {
                        _agreedToPrivacy = value;
                      });
                    },
                    onMarketingChanged: (value) {
                      setState(() {
                        _agreedToMarketing = value;
                      });
                    },
                    onAllChanged: (value) {
                      setState(() {
                        _agreedToTerms = value;
                        _agreedToPrivacy = value;
                        _agreedToMarketing = value;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Submit Button
                  _SubmitButton(
                    onPressed: (_agreedToTerms && _agreedToPrivacy && !_isLoading) 
                        ? _completeSignup 
                        : null,
                    isLoading: _isLoading,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Benefits Info
                  _BenefitsInfo(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  void _completeSignup() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      
      // Simulate signup completion
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          // Show welcome dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => _WelcomeDialog(
              name: _nameController.text,
              onContinue: () {
                Navigator.of(context).pop();
                context.go('/home');
              },
            ),
          );
        }
      });
    }
  }
}

class _WelcomeSection extends StatelessWidget {
  final String phoneNumber;
  
  const _WelcomeSection({required this.phoneNumber});
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green[50],
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle,
            size: 32,
            color: Colors.green[600],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '인증이 완료되었습니다!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.4,
            ),
            children: [
              const TextSpan(text: '회원가입을 완료하려면 이름을 입력해주세요.\n'),
              TextSpan(
                text: phoneNumber,
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(text: '로 가입하시게 됩니다.'),
            ],
          ),
        ),
      ],
    );
  }
}

class _NameInput extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  
  const _NameInput({
    required this.controller,
    required this.enabled,
  });
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '이름',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: TextInputType.name,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: '실명을 입력해주세요',
            prefixIcon: const Icon(Icons.person_outline),
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
              return '이름을 입력해주세요';
            }
            if (value.length < 2) {
              return '이름은 2자 이상이어야 합니다';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              '안전거래를 위해 실명을 사용해주세요',
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

class _TermsAgreement extends StatelessWidget {
  final bool agreedToTerms;
  final bool agreedToPrivacy;
  final bool agreedToMarketing;
  final Function(bool) onTermsChanged;
  final Function(bool) onPrivacyChanged;
  final Function(bool) onMarketingChanged;
  final Function(bool) onAllChanged;
  
  const _TermsAgreement({
    required this.agreedToTerms,
    required this.agreedToPrivacy,
    required this.agreedToMarketing,
    required this.onTermsChanged,
    required this.onPrivacyChanged,
    required this.onMarketingChanged,
    required this.onAllChanged,
  });
  
  @override
  Widget build(BuildContext context) {
    final allAgreed = agreedToTerms && agreedToPrivacy && agreedToMarketing;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          // All Agreement
          InkWell(
            onTap: () => onAllChanged(!allAgreed),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: allAgreed ? AppTheme.primaryColor.withOpacity(0.1) : Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: allAgreed ? AppTheme.primaryColor : Colors.white,
                      border: Border.all(
                        color: allAgreed ? AppTheme.primaryColor : Colors.grey[400]!,
                        width: 2,
                      ),
                    ),
                    child: allAgreed
                        ? const Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '전체 동의하기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          Divider(color: Colors.grey[300]),
          const SizedBox(height: 8),
          
          // Individual Terms
          _TermItem(
            title: '(필수) 이용약관 동의',
            isRequired: true,
            value: agreedToTerms,
            onChanged: onTermsChanged,
            onDetail: () {
              // Show terms
            },
          ),
          const SizedBox(height: 8),
          _TermItem(
            title: '(필수) 개인정보 처리방침 동의',
            isRequired: true,
            value: agreedToPrivacy,
            onChanged: onPrivacyChanged,
            onDetail: () {
              // Show privacy policy
            },
          ),
          const SizedBox(height: 8),
          _TermItem(
            title: '(선택) 마케팅 정보 수신 동의',
            isRequired: false,
            value: agreedToMarketing,
            onChanged: onMarketingChanged,
            onDetail: () {
              // Show marketing terms
            },
          ),
        ],
      ),
    );
  }
}

class _TermItem extends StatelessWidget {
  final String title;
  final bool isRequired;
  final bool value;
  final Function(bool) onChanged;
  final VoidCallback onDetail;
  
  const _TermItem({
    required this.title,
    required this.isRequired,
    required this.value,
    required this.onChanged,
    required this.onDetail,
  });
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: value ? AppTheme.primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: value ? AppTheme.primaryColor : Colors.grey[400]!,
                ),
              ),
              child: value
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.chevron_right,
                size: 20,
                color: Colors.grey[400],
              ),
              onPressed: onDetail,
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  
  const _SubmitButton({
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
          backgroundColor: onPressed != null ? AppTheme.primaryColor : Colors.grey[300],
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
                '가입 완료하기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

class _BenefitsInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.05),
            AppTheme.secondaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.card_giftcard,
                  size: 20,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '회원가입 혜택',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _BenefitItem(
            icon: Icons.trending_up,
            text: '대신팔기 수수료 10% 기본 제공',
          ),
          const SizedBox(height: 8),
          _BenefitItem(
            icon: Icons.inventory_2,
            text: '최대 20개 상품 대신팔기 가능',
          ),
          const SizedBox(height: 8),
          _BenefitItem(
            icon: Icons.security,
            text: '안전거래 수수료 무료 (첫 3회)',
          ),
        ],
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String text;
  
  const _BenefitItem({
    required this.icon,
    required this.text,
  });
  
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppTheme.primaryColor,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}

class _WelcomeDialog extends StatelessWidget {
  final String name;
  final VoidCallback onContinue;
  
  const _WelcomeDialog({
    required this.name,
    required this.onContinue,
  });
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.secondaryColor,
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.celebration,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '환영합니다, $name님!',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '에버세컨즈의 회원이 되신 것을\n진심으로 환영합니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_offer,
                    size: 16,
                    color: Colors.green[700],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '신규 가입 쿠폰 3장 지급 완료',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '시작하기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}