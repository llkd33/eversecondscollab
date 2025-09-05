import 'package:flutter/material.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  
  List<UserModel> _users = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, active, inactive, suspended
  String _sortBy = 'recent'; // recent, name, transactions
  
  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _checkAdminAccess() async {
    final user = await _authService.getCurrentUser();
    
    if (user == null || !user.isAdmin) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('관리자 권한이 필요합니다'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    await _loadUsers();
  }
  
  Future<void> _loadUsers() async {
    try {
      setState(() => _isLoading = true);
      
      // 실제 구현 시 서비스 메소드 사용
      // 여기서는 예시 데이터 생성
      await Future.delayed(const Duration(seconds: 1));
      
      _users = List.generate(50, (index) {
        return UserModel(
          id: 'user_$index',
          email: 'user$index@example.com',
          name: '사용자$index',
          phone: '010-${1000 + index}-${1000 + index}',
          createdAt: DateTime.now().subtract(Duration(days: index * 2)),
          isAdmin: index == 0,
          isReseller: index % 5 == 0,
          profileImageUrl: null,
          bio: '안녕하세요. 사용자$index입니다.',
          rating: 4.0 + (index % 10) / 10,
          transactionCount: index * 5,
          isSuspended: index % 20 == 0,
        );
      });
      
      _applyFilters();
      
      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading users: $e');
      setState(() => _isLoading = false);
    }
  }
  
  void _applyFilters() {
    _filteredUsers = List.from(_users);
    
    // 필터 적용
    switch (_selectedFilter) {
      case 'active':
        _filteredUsers = _filteredUsers.where((u) => 
          !u.isSuspended && u.transactionCount > 0
        ).toList();
        break;
      case 'inactive':
        _filteredUsers = _filteredUsers.where((u) => 
          !u.isSuspended && u.transactionCount == 0
        ).toList();
        break;
      case 'suspended':
        _filteredUsers = _filteredUsers.where((u) => u.isSuspended).toList();
        break;
    }
    
    // 검색어 적용
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      _filteredUsers = _filteredUsers.where((u) =>
        u.name.toLowerCase().contains(query) ||
        u.email.toLowerCase().contains(query) ||
        u.phone.contains(query)
      ).toList();
    }
    
    // 정렬 적용
    switch (_sortBy) {
      case 'name':
        _filteredUsers.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'transactions':
        _filteredUsers.sort((a, b) => b.transactionCount.compareTo(a.transactionCount));
        break;
      case 'recent':
      default:
        _filteredUsers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
  }
  
  void _onSearchChanged(String value) {
    setState(() {
      _applyFilters();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('사용자 관리'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          // 검색 및 필터
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // 검색창
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: '이름, 이메일, 전화번호로 검색',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  ),
                ),
                const SizedBox(height: 12),
                // 필터 및 정렬
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip(theme, '전체', 'all'),
                            const SizedBox(width: 8),
                            _buildFilterChip(theme, '활성', 'active'),
                            const SizedBox(width: 8),
                            _buildFilterChip(theme, '비활성', 'inactive'),
                            const SizedBox(width: 8),
                            _buildFilterChip(theme, '정지', 'suspended'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.sort),
                      onSelected: (value) {
                        setState(() {
                          _sortBy = value;
                          _applyFilters();
                        });
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'recent',
                          child: Text('최근 가입순'),
                        ),
                        const PopupMenuItem(
                          value: 'name',
                          child: Text('이름순'),
                        ),
                        const PopupMenuItem(
                          value: 'transactions',
                          child: Text('거래 많은순'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 사용자 통계
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '총 ${_filteredUsers.length}명',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_selectedFilter == 'suspended')
                  Text(
                    '정지된 사용자',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.red,
                    ),
                  ),
              ],
            ),
          ),
          // 사용자 목록
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? _buildEmptyState(theme)
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return _buildUserItem(theme, user);
                        },
                      ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip(ThemeData theme, String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
          _applyFilters();
        });
      },
      selectedColor: theme.colorScheme.primaryContainer,
      checkmarkColor: theme.colorScheme.primary,
    );
  }
  
  Widget _buildUserItem(ThemeData theme, UserModel user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: user.isSuspended
              ? Colors.red.withOpacity(0.3)
              : theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: InkWell(
        onTap: () => _showUserDetails(user),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 프로필 이미지
              CircleAvatar(
                radius: 25,
                backgroundColor: user.isSuspended
                    ? Colors.red.withOpacity(0.2)
                    : theme.colorScheme.primaryContainer,
                child: Text(
                  user.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: user.isSuspended
                        ? Colors.red
                        : theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 사용자 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          user.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (user.isAdmin)
                          _buildBadge(theme, '관리자', Colors.blue),
                        if (user.isReseller)
                          _buildBadge(theme, '대신판매자', Colors.green),
                        if (user.isSuspended)
                          _buildBadge(theme, '정지', Colors.red),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 14,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          user.rating.toStringAsFixed(1),
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.shopping_cart,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '거래 ${user.transactionCount}회',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatDate(user.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 액션 버튼
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) => _handleUserAction(user, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: Text('상세 보기'),
                  ),
                  const PopupMenuItem(
                    value: 'message',
                    child: Text('메시지 보내기'),
                  ),
                  if (!user.isSuspended)
                    const PopupMenuItem(
                      value: 'suspend',
                      child: Text('계정 정지'),
                    )
                  else
                    const PopupMenuItem(
                      value: 'unsuspend',
                      child: Text('정지 해제'),
                    ),
                  if (!user.isReseller)
                    const PopupMenuItem(
                      value: 'make_reseller',
                      child: Text('대신판매자 승인'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildBadge(ThemeData theme, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '사용자가 없습니다',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '검색 조건을 변경해보세요',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
  
  void _showUserDetails(UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _UserDetailsSheet(user: user),
    );
  }
  
  void _handleUserAction(UserModel user, String action) {
    switch (action) {
      case 'view':
        _showUserDetails(user);
        break;
      case 'message':
        _sendMessage(user);
        break;
      case 'suspend':
        _suspendUser(user);
        break;
      case 'unsuspend':
        _unsuspendUser(user);
        break;
      case 'make_reseller':
        _makeReseller(user);
        break;
    }
  }
  
  void _sendMessage(UserModel user) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${user.name}님에게 메시지 보내기'),
      ),
    );
  }
  
  void _suspendUser(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('계정 정지'),
        content: Text('${user.name}님의 계정을 정지하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // 실제 정지 처리
              setState(() {
                user.isSuspended = true;
                _applyFilters();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('계정이 정지되었습니다'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text('정지'),
          ),
        ],
      ),
    );
  }
  
  void _unsuspendUser(UserModel user) {
    setState(() {
      user.isSuspended = false;
      _applyFilters();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('정지가 해제되었습니다'),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  void _makeReseller(UserModel user) {
    setState(() {
      user.isReseller = true;
      _applyFilters();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('대신판매자로 승인되었습니다'),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}

// 사용자 상세 정보 시트
class _UserDetailsSheet extends StatelessWidget {
  final UserModel user;
  
  const _UserDetailsSheet({required this.user});
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 핸들
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 헤더
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    user.name.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        user.email,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),
          // 상세 정보
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoSection(theme, '기본 정보', [
                    _buildInfoRow('전화번호', user.phone),
                    _buildInfoRow('가입일', _formatDate(user.createdAt)),
                    _buildInfoRow('계정 상태', user.isSuspended ? '정지' : '정상'),
                  ]),
                  const SizedBox(height: 24),
                  _buildInfoSection(theme, '활동 정보', [
                    _buildInfoRow('평점', '${user.rating.toStringAsFixed(1)} / 5.0'),
                    _buildInfoRow('거래 횟수', '${user.transactionCount}회'),
                    _buildInfoRow('대신판매자', user.isReseller ? '승인됨' : '미승인'),
                  ]),
                  const SizedBox(height: 24),
                  _buildInfoSection(theme, '자기소개', [
                    Text(
                      user.bio ?? '자기소개가 없습니다.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoSection(ThemeData theme, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }
}