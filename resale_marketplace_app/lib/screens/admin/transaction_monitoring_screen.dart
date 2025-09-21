import 'package:flutter/material.dart';

class TransactionMonitoringScreen extends StatelessWidget {
  const TransactionMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('거래 모니터링'),
        centerTitle: true,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '거래 모니터링 대시보드는 아직 구현되지 않았습니다.\n'
            '필요한 통계/목록 요구사항을 명확히 한 뒤 실제 데이터 모델에 맞춰 개발해주세요.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
