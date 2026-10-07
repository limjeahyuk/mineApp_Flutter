import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 게임 화면 전환 — 원본 RootView의 `.transition(.opacity)`(0.25초 페이드).
Route<T> fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, a, _, child) =>
          FadeTransition(opacity: a, child: child),
    );

/// 풀스크린 커버(아래에서 올라옴) — 원본 `.fullScreenCover`.
Route<T> coverRoute<T>(Widget page) =>
    MaterialPageRoute<T>(fullscreenDialog: true, builder: (_) => page);

/// 화면 방향 — 큰 판(최고급)은 세로 기본 + 가로 허용, 그 외는 세로 고정(원본 setAppOrientation).
void setBigBoardOrientation(bool allowLandscape) {
  SystemChrome.setPreferredOrientations(allowLandscape
      ? const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]
      : const [DeviceOrientation.portraitUp]);
}
