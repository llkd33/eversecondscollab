import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// 네트워크 연결 상태 관리 서비스
class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  bool _isConnected = true;
  bool _isInitialized = false;
  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];
  
  /// 현재 연결 상태
  bool get isConnected => _isConnected;
  
  /// 연결 타입 상태
  List<ConnectivityResult> get connectionStatus => _connectionStatus;
  
  /// 초기화 여부
  bool get isInitialized => _isInitialized;
  
  /// 연결 타입 문자열
  String get connectionTypeString {
    if (_connectionStatus.contains(ConnectivityResult.wifi)) {
      return 'WiFi';
    } else if (_connectionStatus.contains(ConnectivityResult.mobile)) {
      return '모바일 데이터';
    } else if (_connectionStatus.contains(ConnectivityResult.ethernet)) {
      return '이더넷';
    } else {
      return '연결 안됨';
    }
  }
  
  /// 연결 상태 아이콘
  String get connectionIcon {
    if (_connectionStatus.contains(ConnectivityResult.wifi)) {
      return '📶';
    } else if (_connectionStatus.contains(ConnectivityResult.mobile)) {
      return '📱';
    } else if (_connectionStatus.contains(ConnectivityResult.ethernet)) {
      return '🌐';
    } else {
      return '❌';
    }
  }

  /// 서비스 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // 초기 연결 상태 확인
      _connectionStatus = await _connectivity.checkConnectivity();
      _isConnected = !_connectionStatus.contains(ConnectivityResult.none);
      
      // 연결 상태 변화 리스너 설정
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _updateConnectionStatus,
        onError: (error) {
          print('❌ 연결 상태 모니터링 오류: $error');
        },
      );
      
      _isInitialized = true;
      print('🌐 ConnectivityService 초기화 완료: ${connectionTypeString}');
      notifyListeners();
    } catch (e) {
      print('❌ ConnectivityService 초기화 실패: $e');
      _isConnected = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// 연결 상태 업데이트
  void _updateConnectionStatus(List<ConnectivityResult> result) {
    final previousStatus = _isConnected;
    _connectionStatus = result;
    _isConnected = !result.contains(ConnectivityResult.none);
    
    if (previousStatus != _isConnected) {
      if (_isConnected) {
        print('✅ 인터넷 연결 복구됨: ${connectionTypeString}');
        _onConnectionRestored();
      } else {
        print('❌ 인터넷 연결 끊어짐');
        _onConnectionLost();
      }
      
      notifyListeners();
    }
  }

  /// 연결 복구 시 처리
  void _onConnectionRestored() {
    // 오프라인 큐에 저장된 작업들 처리
    _processOfflineQueue();
  }

  /// 연결 끊어짐 시 처리
  void _onConnectionLost() {
    // 필요한 경우 진행 중인 작업들 중단 처리
  }

  /// 오프라인 큐 처리 (향후 확장 가능)
  void _processOfflineQueue() {
    // TODO: 오프라인 상태에서 저장된 작업들을 처리
    print('🔄 오프라인 큐 처리 시작');
  }

  /// 네트워크 상태 강제 체크
  Future<bool> checkConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      final wasConnected = _isConnected;
      _connectionStatus = result;
      _isConnected = !result.contains(ConnectivityResult.none);
      
      if (wasConnected != _isConnected) {
        notifyListeners();
      }
      
      return _isConnected;
    } catch (e) {
      print('❌ 연결 상태 체크 실패: $e');
      return false;
    }
  }

  /// WiFi 연결 여부
  bool get isWiFiConnected => _connectionStatus.contains(ConnectivityResult.wifi);
  
  /// 모바일 데이터 연결 여부
  bool get isMobileConnected => _connectionStatus.contains(ConnectivityResult.mobile);
  
  /// 느린 연결인지 확인 (모바일 데이터)
  bool get isSlowConnection => isMobileConnected && !isWiFiConnected;

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

/// 네트워크 연결 상태 제공하는 프로바이더
class ConnectivityProvider extends ChangeNotifier {
  final ConnectivityService _connectivityService = ConnectivityService();
  
  ConnectivityProvider() {
    _connectivityService.addListener(_onConnectivityChanged);
    _connectivityService.initialize();
  }
  
  void _onConnectivityChanged() {
    notifyListeners();
  }
  
  bool get isConnected => _connectivityService.isConnected;
  bool get isInitialized => _connectivityService.isInitialized;
  String get connectionType => _connectivityService.connectionTypeString;
  String get connectionIcon => _connectivityService.connectionIcon;
  bool get isWiFiConnected => _connectivityService.isWiFiConnected;
  bool get isMobileConnected => _connectivityService.isMobileConnected;
  bool get isSlowConnection => _connectivityService.isSlowConnection;
  
  Future<bool> checkConnection() => _connectivityService.checkConnection();
  
  @override
  void dispose() {
    _connectivityService.removeListener(_onConnectivityChanged);
    super.dispose();
  }
}