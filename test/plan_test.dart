import 'package:flutter_test/flutter_test.dart';
import 'package:lifeline/data/models/export_request.dart';
import 'package:lifeline/data/models/tailor_plan.dart';
import 'package:lifeline/data/models/target_profile.dart';

void main() {
  group('TailorPlan 解析', () {
    test('决策/rejected/追问 解析与夹紧', () {
      final plan = TailorPlan.fromJson({
        'role': '后端工程师',
        'level': 'senior',
        'track': 'tech',
        'narrative': '高并发系统',
        'ats_keywords': ['Kubernetes', 'Go'],
        'decisions': [
          {'source_record_id': 'r1', 'decision': 'lead', 'relevance': 1.5, 'bullet_cap': 9},
          {'source_record_id': 'r2', 'decision': 'delete', 'reason': '与目标无关'},
          {'source_record_id': 'r3', 'decision': 'bogus'},
        ],
        'open_questions': ['订单峰值的口径是 QPS 还是 TPS？'],
      });
      expect(plan.decisions.length, 3);
      expect(plan.decisions[0].relevance, 1.0); // 夹紧到 [0,1]
      expect(plan.decisions[0].bulletCap, 5); // 夹紧到 [0,5]
      expect(plan.decisions[1].decision, 'delete');
      expect(plan.rejected.single.sourceRecordId, 'r2');
      expect(plan.decisions[2].decision, 'keep'); // 非法值回退
      expect(plan.openQuestions.single, contains('QPS'));
    });
  });

  group('ExportRequest 目标画像字段', () {
    test('level/stage/track 往返', () {
      final r = const ExportRequest(
        targetRole: '数据分析',
        targetLevel: 'senior',
        careerStage: 'switcher',
        track: 'finance',
      );
      final back = ExportRequest.fromJson(r.toJson());
      expect(back.targetLevel, 'senior');
      expect(back.careerStage, 'switcher');
      expect(back.track, 'finance');
    });

    test('缺省值回退', () {
      final back = ExportRequest.fromJson({'target_role': 'x'});
      expect(back.targetLevel, 'mid');
      expect(back.track, 'general');
    });
  });

  group('赛道权重', () {
    test('每条赛道维度权重之和为 1', () {
      for (final t in Track.all) {
        final sum = t.dimensionWeights.values.fold<double>(0, (a, b) => a + b);
        expect(sum, closeTo(1.0, 0.001), reason: t.id);
      }
    });
  });
}
