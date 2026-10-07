import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import '../multiplayer/multiplayer.dart';

/// 방 초대 링크 — Swift InviteLink 이식. 공유 메시지의 https 링크 → Hosting 랜딩 →
/// `mineapp://join?g=…&c=…`로 앱을 연다. 쿼리(g/game, c/code)만 읽는다.
enum InviteGame { mine, treasure, touch }

class InviteLink {
  static const scheme = 'mineapp';
  static const webBase = 'https://mineapp-aabc8.web.app';

  static String webURL(InviteGame game, String code) =>
      '$webBase/j?g=${game.name}&c=$code';

  static (InviteGame, String)? parse(Uri uri) {
    String? v(List<String> names) {
      for (final n in names) {
        final x = uri.queryParameters[n];
        if (x != null) return x;
      }
      return null;
    }

    final raw = v(['c', 'code']);
    if (raw == null) return null;
    final code = RoomCode.normalize(raw);
    if (code.isEmpty) return null;
    final g = InviteGame.values
        .where((e) => e.name == (v(['g', 'game']) ?? ''))
        .firstOrNull;
    return (g ?? InviteGame.mine, code);
  }
}

/// 딥링크로 들어온 "방 입장" 요청을 보관해 홈이 소비한다(콜드/웜 런치 공통).
class DeepLinkRouter extends ValueNotifier<(InviteGame, String)?> {
  DeepLinkRouter._() : super(null);
  static final shared = DeepLinkRouter._();

  StreamSubscription<Uri>? _sub;

  void start() {
    if (_sub != null) return;
    try {
      _sub = AppLinks().uriLinkStream.listen(handle, onError: (_) {});
    } catch (_) {}
  }

  void handle(Uri uri) {
    if (uri.scheme.toLowerCase() != InviteLink.scheme) return;
    final p = InviteLink.parse(uri);
    if (p != null) value = p;
  }

  /// 대기 중인 요청을 꺼내고 비운다.
  (InviteGame, String)? take() {
    final p = value;
    value = null;
    return p;
  }
}
