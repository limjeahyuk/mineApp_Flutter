import 'package:flutter_test/flutter_test.dart';
import 'package:mine_app/core/deep_link.dart';

void main() {
  test('초대 링크 파싱 — 게임/코드 정규화, 다른 스킴은 무시', () {
    expect(DeepLink.parse(Uri.parse('mineapp://join?g=treasure&c=abc234')), ('treasure', 'ABC234'));
    expect(DeepLink.parse(Uri.parse('mineapp://j?c=XYZ789')), ('mine', 'XYZ789'));
    expect(DeepLink.parse(Uri.parse('mineapp://j?game=touch&code=q-w-e-r')), ('touch', 'QWER'));
    expect(DeepLink.parse(Uri.parse('https://mineapp-aabc8.web.app/j?g=mine&c=ABC234')), isNull);
    expect(DeepLink.parse(Uri.parse('mineapp://j?g=mine')), isNull);
  });
}
