import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/auth_service.dart';
import 'core/cloud_backup.dart';
import 'core/local_store.dart';
import 'core/theme.dart';
import 'core/ui.dart';
import 'firebase_options.dart';
import 'home/home_screen.dart';
import 'progression/achievements_screen.dart';
import 'shop/rewarded_ads.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStore.init();
  setAppOrientation();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // 익명 로그인은 백그라운드로(솔로엔 불필요, 멀티 대비). 실패해도 게임은 진행.
  AuthService.ensureSignedIn().then((_) {}).catchError((_) {});
  // 연동 계정이면 값이 바뀔 때마다 클라우드 백업(잦은 변경은 1초 모아서 한 번).
  Timer? debounce;
  LocalStore.backupHook = () {
    debounce?.cancel();
    debounce = Timer(const Duration(seconds: 1), CloudBackup.backupIfLinked);
  };
  runApp(const MineApp());
  // 맞춤형 광고 추적 동의(ATT)는 앱이 활성화된 뒤에만 뜨므로 첫 프레임 후 요청하고,
  // 그 결과를 반영해 광고 SDK를 시작한다(Swift RootView.task).
  WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(RewardedAdManager.shared.start()));
}

class MineApp extends StatelessWidget {
  const MineApp({super.key});

  ThemeData _theme(Brightness b) {
    final t = AppTheme(b == Brightness.dark);
    return ThemeData(
      brightness: b,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
          seedColor: AppTheme.soloAccent, brightness: b, surface: t.surface),
      scaffoldBackgroundColor: t.bg,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([themeModeNotifier, colorThemeNotifier]),
      builder: (_, _) => MaterialApp(
        title: '지뢰 찾기',
        debugShowCheckedModeBanner: false,
        themeMode: themeModeNotifier.value,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        // 어디서든 새 칭호를 얻으면 상단에 잠깐 축하 배너를 띄운다(Swift RootView.unlockBanner).
        builder: (context, child) => Stack(
          children: [
            ?child,
            const _UnlockBannerHost(),
          ],
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class _UnlockBannerHost extends StatefulWidget {
  const _UnlockBannerHost();

  @override
  State<_UnlockBannerHost> createState() => _UnlockBannerHostState();
}

class _UnlockBannerHostState extends State<_UnlockBannerHost> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    LocalStore.shared.pendingUnlockToast.addListener(_onToast);
  }

  @override
  void dispose() {
    LocalStore.shared.pendingUnlockToast.removeListener(_onToast);
    _timer?.cancel();
    super.dispose();
  }

  void _onToast() {
    final title = LocalStore.shared.pendingUnlockToast.value;
    setState(() {});
    if (title == null) return;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 2800), () {
      if (LocalStore.shared.pendingUnlockToast.value?.id == title.id) {
        LocalStore.shared.pendingUnlockToast.value = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = LocalStore.shared.pendingUnlockToast.value;
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOutBack,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, -1), end: Offset.zero)
                      .animate(anim),
                  child: child,
                ),
              ),
              child: title == null
                  ? const SizedBox.shrink()
                  : TitleUnlockBanner(key: ValueKey(title.id), title: title),
            ),
          ),
        ),
      ),
    );
  }
}
