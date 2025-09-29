import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_service.dart';
import '../../services/account_encryption_service.dart';
import '../../theme/app_theme.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final UserService _userService = UserService();
  final AccountEncryptionService _encryptionService =
      AccountEncryptionService();

  bool _isLoading = false;
  bool _showAccountForNormal = false;
  UserModel? _currentUser;

  // 은행 목록
  final List<String> _bankList = [
    'KB국민은행',
    '신한은행',
    '우리은행',
    '하나은행',
    'NH농협은행',
    'IBK기업은행',
    'SC제일은행',
    '씨티은행',
    'KDB산업은행',
    '수협은행',
    '대구은행',
    '부산은행',
    '광주은행',
    '제주은행',
    '전북은행',
    '경남은행',
    '중소기업은행',
    '한국산업은행',
    '우체국예금보험',
    '새마을금고',
    '신협',
    '토스뱅크',
    '카카오뱅크',
    '케이뱅크',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountHolderController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final authProvider = context.read<AuthProvider>();
    _currentUser = authProvider.currentUser;

    if (_currentUser != null) {
      _bankNameController.text = _currentUser!.bankName ?? '';
      _accountHolderController.text = _currentUser!.accountHolder ?? '';
      _showAccountForNormal = _currentUser!.showAccountForNormal;

      // 계좌번호 복호화해서 표시
      if (_currentUser!.hasAccountInfo) {
        try {
          final decryptedAccount = await _encryptionService
              .decryptStoredAccountNumber(_currentUser!.id);
          if (decryptedAccount != null) {
            _accountNumberController.text = decryptedAccount;
          }
        } catch (e) {
          print('계좌번호 복호화 실패: $e');
        }
      }

      setState(() {});
    }
  }

  Future<void> _saveAccountInfo() async {
    if (!_formKey.currentState!.validate() || _currentUser == null) {
      print('❌ 계좌정보 저장 - 유효성 검사 실패');
      return;
    }

    print('🔄 계좌정보 저장 시작');
    print('  - 사용자 ID: ${_currentUser!.id}');
    print('  - 은행명: ${_bankNameController.text.trim()}');
    print('  - 예금주: ${_accountHolderController.text.trim()}');
    print('  - 계좌번호 길이: ${_accountNumberController.text.trim().length}');
    print('  - 일반거래 계좌 공개: $_showAccountForNormal');

    setState(() => _isLoading = true);

    try {
      // 1단계: 계좌번호 암호화 및 저장
      print('🔐 1단계: 계좌번호 암호화 중...');
      final encryptedStored = await _encryptionService
          .encryptAndStoreAccountNumber(
            _currentUser!.id,
            _accountNumberController.text.trim(),
            bankName: _bankNameController.text.trim(),
          );
      if (!encryptedStored) {
        throw Exception('encryptAndStoreAccountNumber 실패');
      }
      print('✅ 1단계: 계좌번호 암호화 완료');

      // 2단계: 사용자 정보 업데이트 (은행명, 예금주 등)
      print('👤 2단계: 사용자 프로필 업데이트 중...');
      final success = await _userService.updateUserProfile(
        userId: _currentUser!.id,
        bankName: _bankNameController.text.trim(),
        accountHolder: _accountHolderController.text.trim(),
        showAccountForNormal: _showAccountForNormal,
      );

      if (!success) {
        throw Exception(
          '사용자 프로필 업데이트 실패 - UserService.updateUserProfile returned false',
        );
      }
      print('✅ 2단계: 사용자 프로필 업데이트 완료');

      if (mounted) {
        // 3단계: AuthProvider 갱신
        print('🔄 3단계: AuthProvider 갱신 중...');
        final authProvider = context.read<AuthProvider>();
        await authProvider.refreshUserProfile();
        print('✅ 3단계: AuthProvider 갱신 완료');

        print('🎉 계좌정보 저장 성공');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('계좌 정보가 저장되었습니다'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e, stackTrace) {
      print('❌ 계좌정보 저장 실패: $e');
      print('스택 트레이스: $stackTrace');
      if (mounted) {
        String errorMessage = '저장 실패';

        // 구체적인 오류 메시지 제공
        if (e.toString().contains('encryptAndStoreAccountNumber')) {
          errorMessage = '계좌번호 암호화 중 오류가 발생했습니다';
        } else if (e.toString().contains('updateUserProfile')) {
          errorMessage = '사용자 정보 업데이트 중 오류가 발생했습니다';
        } else if (e.toString().contains('PostgrestException')) {
          errorMessage = '데이터베이스 연결 문제가 발생했습니다';
        } else {
          errorMessage = '오류: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: '다시 시도',
              textColor: Colors.white,
              onPressed: _saveAccountInfo,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('계좌 정보 설정'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveAccountInfo,
              child: const Text(
                '저장',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 안내 메시지
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue[600],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '계좌 정보 안내',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• 대신판매 수수료 정산을 위해 계좌 정보가 필요합니다\n'
                      '• 계좌 정보는 암호화되어 안전하게 저장됩니다\n'
                      '• 일반 거래시 계좌 공개 여부를 선택할 수 있습니다',
                      style: TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 은행 선택
              const Text(
                '은행명',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _bankNameController.text.isEmpty
                    ? null
                    : _bankNameController.text,
                decoration: InputDecoration(
                  hintText: '은행을 선택하세요',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _bankList.map((bank) {
                  return DropdownMenuItem(value: bank, child: Text(bank));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _bankNameController.text = value ?? '';
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '은행을 선택해주세요';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // 계좌번호
              const Text(
                '계좌번호',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _accountNumberController,
                decoration: InputDecoration(
                  hintText: '계좌번호를 입력하세요 (하이픈 제외)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: const Icon(Icons.security),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(20),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '계좌번호를 입력해주세요';
                  }
                  if (value.length < 8) {
                    return '올바른 계좌번호를 입력해주세요';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // 예금주
              const Text(
                '예금주',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _accountHolderController,
                decoration: InputDecoration(
                  hintText: '예금주명을 입력하세요',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '예금주명을 입력해주세요';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // 계좌 공개 설정
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '일반 거래시 계좌 공개',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '대신판매가 아닌 일반 거래에서 구매자에게 계좌번호를 공개할지 선택하세요',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: _showAccountForNormal,
                      onChanged: (value) {
                        setState(() {
                          _showAccountForNormal = value;
                        });
                      },
                      title: Text(
                        _showAccountForNormal ? '공개함' : '공개하지 않음',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        _showAccountForNormal
                            ? '일반 거래시에도 계좌번호가 공개됩니다'
                            : '대신판매 거래에서만 계좌번호가 사용됩니다',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      activeColor: AppTheme.primaryColor,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
