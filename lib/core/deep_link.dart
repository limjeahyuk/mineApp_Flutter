import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../modes/coop_screen.dart';
import '../modes/treasure_screen.dart';
import '../multiplayer/multiplayer.dart';
import '../multiplayer/versus_screen.dart';

/// 방 초대 딥링크 — Swift InviteLink/DeepLinkRouter 이식.
/// `mineapp://…?g=mine|treasure|touch&c=CODE` 로 들어오면 해당 게임의 "코드로 참가"를 연다.
/// (공유 메시지의 https 링크는 웹 랜딩 페이지가 이 스킴으로 앱을 연다)
class DeepLink {
  static final navigatorKey = GlobalKey<NavigatorState>();
  static StreamSubscription<Uri>? _sub;

  /// (게임, 정규화된 코드). 우리 스킴이 아니거나 코드가 없으면 null.
  static (String, String)? parse(Uri uri) {
    if (uri.scheme.toLowerCase() != 'mineapp') return null;
    final q = uri.queryParameters;
    final code = RoomCode.normalize(q['c'] ?? q['code'] ?? '');
    if (code.isEmpty) return null;
    final g = q['g'] ?? q['game'] ?? 'mine';
    return (const {'mine', 'treasure', 'touch'}.contains(g) ? g : 'mine', code);
  }

  static void start() {
    final links = AppLinks();
    _sub ??= links.uriLinkStream.listen(_open, onError: (_) {});
  }

  static void _open(Uri uri) {
    final parsed = parse(uri);
    final nav = navigatorKey.currentState;
    if (parsed == null || nav == null) return;
    final (game, code) = parsed;
    final mode = RaceMode.join(code);
    final Widget screen = switch (game) {
      'treasure' => TreasureScreen(mode: mode),
      'touch' => CoopScreen(mode: mode),
      _ => VersusScreen(mode: mode),
    };
    // 진행 중이던 화면을 닫고 홈 위에 새 방으로(원본: launch 교체).
    nav.popUntil((r) => r.isFirst);
    nav.push(MaterialPageRoute(builder: (_) => screen));
  }
}
