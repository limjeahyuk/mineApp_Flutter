import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart' hide Title;

import 'core/auth_service.dart';
import 'core/deep_link.dart';
import 'core/local_store.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'home/home_screen.dart';
import 'progression/title.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStore.init();
  refreshAchievements(); // 기존 통계로 이미 충족된 업적을 조용히 해금(원본 init과 동일)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // 익명 로그인은 백그라운드로(솔로엔 불필요, 멀티 대비). 실패해도 게임은 진행.
  AuthService.ensureSignedIn().then((_) {}).catchError((_) {});
  runApp(const MineApp());
  DeepLink.start(); // 방 초대 링크(mineapp://) — 콜드 런치 링크도 스트림으로 들어온다
}

class MineApp extends StatelessWidget {
  const MineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([themeModeNotifier, colorThemeNotifier]),
      builder: (_, _) => MaterialApp(
        navigatorKey: DeepLink.navigatorKey,
        title: '지뢰찾기 아레나',
        debugShowCheckedModeBanner: false,
        themeMode: themeModeNotifier.value,
        theme: buildAppTheme(Brightness.light),
        darkTheme: buildAppTheme(Brightness.dark),
        home: const HomeScreen(),
        // 어디서든 새 칭호를 얻으면 상단에 잠깐 축하 배너(원본 RootView.unlockBanner).
        builder: (context, child) => Stack(children: [
          child ?? const SizedBox.shrink(),
          const _UnlockBannerOverlay(),
        ]),
      ),
    );
  }
}

class _UnlockBannerOverlay extends StatefulWidget {
  const _UnlockBannerOverlay();

  @override
  State<_UnlockBannerOverlay> createState() => _UnlockBannerOverlayState();
}

class _UnlockBannerOverlayState extends State<_UnlockBannerOverlay> {
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    titleUnlockToast.addListener(_onToast);
  }

  void _onToast() {
    final shown = titleUnlockToast.value;
    if (shown == null) return;
    _hide?.cancel();
    _hide = Timer(const Duration(milliseconds: 2800), () {
      if (titleUnlockToast.value?.id == shown.id) titleUnlockToast.value = null;
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    titleUnlockToast.removeListener(_onToast);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder(
      valueListenable: titleUnlockToast,
      builder: (context, title, _) => Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (c, a) => SlideTransition(
              position: Tween(begin: const Offset(0, -0.6), end: Offset.zero).animate(a),
              child: FadeTransition(opacity: a, child: c),
            ),
            child: title == null
                ? const SizedBox.shrink()
                : Material(
                    key: ValueKey(title.id),
                    type: MaterialType.transparency,
                    child: TitleUnlockBanner(title: title, dark: dark),
                  ),
          ),
        ),
      ),
    );
  }
}
