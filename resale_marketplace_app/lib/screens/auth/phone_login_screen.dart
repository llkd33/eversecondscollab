import 'package:flutter/material.dart';

class PhoneLoginScreen extends StatelessWidget {
  const PhoneLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('휴대폰 로그인')), 
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '현재는 카카오 로그인을 통해서만 서비스를 이용할 수 있습니다.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
