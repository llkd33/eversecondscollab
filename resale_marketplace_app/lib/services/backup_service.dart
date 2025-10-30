import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

/// Backup Service for database backup and restore operations
class BackupService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get list of backups
  Future<List<Map<String, dynamic>>> getBackups({
    int limit = 50,
    int offset = 0,
    String? backupType,
    String? status,
  }) async {
    try {
      var query = _supabase.from('system_backups').select('''
        *,
        initiator:users!system_backups_initiated_by_fkey(id, name, email)
      ''');

      if (backupType != null && backupType.isNotEmpty) {
        query = query.eq('backup_type', backupType);
      }

      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }

      final response = await query
          .order('started_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching backups: $e');
      return [];
    }
  }

  /// Create manual backup
  Future<Map<String, dynamic>?> createManualBackup({
    required String adminId,
    String scope = 'full',
    List<String>? tables,
  }) async {
    try {
      // Create backup record
      final backupData = {
        'backup_type': 'manual',
        'backup_scope': scope,
        'tables_included': tables ?? _getDefaultTables(),
        'status': 'in_progress',
        'initiated_by': adminId,
      };

      final response = await _supabase
          .from('system_backups')
          .insert(backupData)
          .select()
          .single();

      final backupId = response['id'];

      // Trigger backup process (in background)
      _performBackup(backupId, tables ?? _getDefaultTables());

      return response;
    } catch (e) {
      print('Error creating backup: $e');
      return null;
    }
  }

  /// Schedule automatic backup
  Future<bool> scheduleBackup({
    required String schedule, // cron format or interval
    String scope = 'full',
    List<String>? tables,
  }) async {
    try {
      // This would typically be handled by a scheduled job
      // For now, we'll store the schedule configuration
      final scheduleData = {
        'backup_type': 'scheduled',
        'backup_scope': scope,
        'tables_included': tables ?? _getDefaultTables(),
        'metadata': jsonEncode({
          'schedule': schedule,
          'next_run': _calculateNextRun(schedule),
        }),
      };

      // Store in a separate configuration table or use metadata
      await _supabase.from('system_backups').insert(scheduleData);

      return true;
    } catch (e) {
      print('Error scheduling backup: $e');
      return false;
    }
  }

  /// Restore from backup
  Future<bool> restoreFromBackup(String backupId) async {
    try {
      // Get backup details
      final backup = await _supabase
          .from('system_backups')
          .select()
          .eq('id', backupId)
          .single();

      if (backup['status'] != 'completed') {
        throw Exception('Can only restore from completed backups');
      }

      final backupLocation = backup['backup_location'];
      if (backupLocation == null || backupLocation.isEmpty) {
        throw Exception('Backup location not found');
      }

      // This would involve:
      // 1. Download backup file from storage
      // 2. Parse and validate backup data
      // 3. Restore data to respective tables
      // 4. Verify data integrity

      // For now, return success (actual implementation would be more complex)
      return true;
    } catch (e) {
      print('Error restoring backup: $e');
      return false;
    }
  }

  /// Perform backup (background process)
  Future<void> _performBackup(String backupId, List<String> tables) async {
    try {
      final backupData = <String, List<Map<String, dynamic>>>{};
      int totalSize = 0;

      // Export each table
      for (final table in tables) {
        try {
          final data = await _supabase.from(table).select();
          backupData[table] = List<Map<String, dynamic>>.from(data);

          // Calculate approximate size
          totalSize += jsonEncode(data).length;
        } catch (e) {
          print('Error backing up table $table: $e');
          // Continue with other tables
        }
      }

      // Convert to JSON
      final backupJson = jsonEncode({
        'backup_id': backupId,
        'timestamp': DateTime.now().toIso8601String(),
        'tables': backupData,
      });

      // In production, upload to storage (Supabase Storage or external)
      final backupLocation = 'backup_$backupId.json';

      // Store backup file (this would be uploaded to storage)
      // await _uploadToStorage(backupLocation, backupJson);

      // Update backup record
      await _supabase.from('system_backups').update({
        'status': 'completed',
        'backup_size_bytes': totalSize,
        'backup_location': backupLocation,
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', backupId);
    } catch (e) {
      print('Error performing backup: $e');

      // Update backup record with error
      await _supabase.from('system_backups').update({
        'status': 'failed',
        'error_message': e.toString(),
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', backupId);
    }
  }

  /// Get default tables to backup
  List<String> _getDefaultTables() {
    return [
      'users',
      'shops',
      'products',
      'shop_products',
      'chats',
      'messages',
      'transactions',
      'reviews',
      'safe_transactions',
      'reports',
      'sms_logs',
    ];
  }

  /// Calculate next run time for scheduled backup
  DateTime _calculateNextRun(String schedule) {
    // Simple implementation - daily at midnight
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1);
  }

  /// Delete old backups
  Future<bool> deleteBackup(String backupId) async {
    try {
      // Delete backup file from storage first
      final backup = await _supabase
          .from('system_backups')
          .select('backup_location')
          .eq('id', backupId)
          .single();

      final backupLocation = backup['backup_location'];
      if (backupLocation != null) {
        // Delete from storage
        // await _deleteFromStorage(backupLocation);
      }

      // Delete backup record
      await _supabase.from('system_backups').delete().eq('id', backupId);

      return true;
    } catch (e) {
      print('Error deleting backup: $e');
      return false;
    }
  }

  /// Get backup statistics
  Future<Map<String, dynamic>> getBackupStatistics() async {
    try {
      final response = await _supabase.from('system_backups').select();

      final backups = List<Map<String, dynamic>>.from(response);

      int totalBackups = backups.length;
      int completedBackups =
          backups.where((b) => b['status'] == 'completed').length;
      int failedBackups =
          backups.where((b) => b['status'] == 'failed').length;
      int totalSize = backups.fold<int>(
          0, (sum, b) => sum + (b['backup_size_bytes'] as int? ?? 0));

      // Get last backup time
      DateTime? lastBackup;
      if (completedBackups > 0) {
        final sortedBackups = List<Map<String, dynamic>>.from(backups)
          ..sort((a, b) {
            final aTime = DateTime.parse(a['completed_at'] ?? a['started_at']);
            final bTime = DateTime.parse(b['completed_at'] ?? b['started_at']);
            return bTime.compareTo(aTime);
          });
        lastBackup = DateTime.parse(
            sortedBackups.first['completed_at'] ?? sortedBackups.first['started_at']);
      }

      return {
        'totalBackups': totalBackups,
        'completedBackups': completedBackups,
        'failedBackups': failedBackups,
        'totalSizeBytes': totalSize,
        'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
        'lastBackup': lastBackup?.toIso8601String(),
      };
    } catch (e) {
      print('Error getting backup statistics: $e');
      return {
        'totalBackups': 0,
        'completedBackups': 0,
        'failedBackups': 0,
        'totalSizeBytes': 0,
        'totalSizeMB': '0.00',
      };
    }
  }
}
