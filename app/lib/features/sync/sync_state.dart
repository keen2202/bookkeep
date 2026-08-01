import 'package:flutter/foundation.dart';

/// 同步状态机（Spec BK-P0-006）：idle → pushing → pulling → merging → idle；
/// 任一环节失败 → error（队列保留，恢复后重试）。
enum SyncPhase { idle, pushing, pulling, merging, error }

class SyncState {
  SyncState({this.phase = SyncPhase.idle});

  final SyncPhase phase;

  SyncState copyWith({SyncPhase? phase}) => SyncState(phase: phase ?? this.phase);
}

class SyncPhaseNotifier extends ValueNotifier<SyncPhase> {
  SyncPhaseNotifier([super.value = SyncPhase.idle]);
}
