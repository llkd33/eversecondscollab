import 'package:flutter/material.dart';

class PhoneAuthScreen extends StatelessWidget {
  const PhoneAuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('휴대폰 인증')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '휴대폰 인증 기능은 현재 제공하지 않습니다.\n카카오 로그인을 이용해주세요.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
