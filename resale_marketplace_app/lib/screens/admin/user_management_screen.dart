import 'package:flutter/material.dart';

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('사용자 관리'),
        centerTitle: true,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '관리자 사용자 관리 화면은 아직 구현되지 않았습니다.\n'
            '필요 시 실제 데이터 모델에 맞춰 기능을 재구성해주세요.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
