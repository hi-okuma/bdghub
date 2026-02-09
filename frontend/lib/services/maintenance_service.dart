import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bodogehub/utils/logger.dart';

/// メンテナンス情報を保持するクラス
class MaintenanceInfo {
  final bool isMaintenance;
  final String message;

  MaintenanceInfo({required this.isMaintenance, required this.message});
}

class MaintenanceService {
  /// Firebase初期化後、認証なしでメンテナンス状態を確認
  /// セキュリティルール上、認証不要でアクセス可能
  static Future<MaintenanceInfo> checkMaintenanceStatus() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('serviceConfig')
          .doc('global')
          .get();

      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        if (data.containsKey('maintenance')) {
          final config = data['maintenance'] as Map<String, dynamic>;
          return MaintenanceInfo(
            isMaintenance: config['isMaintenance'] ?? false,
            message: config['maintenanceMessage'] ?? '',
          );
        }
      }
      return MaintenanceInfo(isMaintenance: false, message: '');
    } catch (e) {
      Logger.log('メンテナンス確認エラー: $e');
      // エラー時はメンテなしとして続行
      return MaintenanceInfo(isMaintenance: false, message: '');
    }
  }
}
