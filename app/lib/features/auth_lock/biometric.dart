import 'package:local_auth/local_auth.dart';

/// 生物识别抽象（Spec §3.6 / BK-T-008）；测试注入 FakeBiometricAuth
abstract class BiometricAuth {
  Future<bool> available();
  Future<bool> authenticate();
}

/// local_auth 实现：设备不支持/用户拒绝均优雅降级到 PIN
class LocalAuthBiometric implements BiometricAuth {
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  Future<bool> available() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(localizedReason: '解锁 bookkeep 查看记账数据');
    } catch (_) {
      return false;
    }
  }
}

class FakeBiometricAuth implements BiometricAuth {
  FakeBiometricAuth({this.supported = true, this.result = true});

  bool supported;
  bool result;
  int authenticateCalls = 0;

  @override
  Future<bool> available() async => supported;

  @override
  Future<bool> authenticate() async {
    authenticateCalls++;
    return result;
  }
}
