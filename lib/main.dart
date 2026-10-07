import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/deep_link.dart';
import 'core/auth_service.dart';
import 'core/cloud_backup.dart';
import 'core/local_store.dart';
import 'core/theme.dart';
import 'core/ui.dart';
import 'firebase_options.dart';
import 'home/home_screen.dart';
<<<<<<< HEAD
import 'notice/notice.dart';
import 'progression/title.dart';
import 'shop/rewarded_ads.dart';
=======
import 'progression/achievements_screen.dart';
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStore.init();
  setAppOrientation();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // 익명 인증: 보안 규칙(auth != null)을 위해 미리 로그인(실패해도 게임은 진행).
  AuthService.ensureSignedIn().then((_) {}).catchError((_) {});
<<<<<<< HEAD
  // 기본 세로 고정 — 큰 판(최고급)만 게임 화면에서 가로를 허용한다.
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  DeepLinkRouter.shared.start();
=======
  // 연동 계정이면 값이 바뀔 때마다 클라우드 백업(잦은 변경은 1초 모아서 한 번).
  Timer? debounce;
  LocalStore.backupHook = () {
    debounce?.cancel();
    debounce = Timer(const Duration(seconds: 1), CloudBackup.backupIfLinked);
  };
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
  runApp(const MineApp());
  // 시작 공지 + (ATT 동의 후) 보상형 광고 SDK.
  unawaited(NoticeStore.shared.loadOnLaunch());
  unawaited(RewardedAdManager.shared.start());
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
<<<<<<< HEAD
    return ValueListenableBuilder<ColorTheme>(
      valueListenable: colorThemeNotifier,
      builder: (_, _, _) => ValueListenableBuilder<ThemeMode>(
        valueListenable: themeModeNotifier,
        builder: (_, mode, _) => MaterialApp(
          title: '지뢰찾기 아레나',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: AppTheme.soloAccent),
            useMaterial3: true,
            splashFactory: NoSplash.splashFactory,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
                seedColor: AppTheme.soloAccent, brightness: Brightness.dark),
            useMaterial3: true,
            splashFactory: NoSplash.splashFactory,
          ),
          // 어디서든 새 칭호를 얻으면 상단에 잠깐 축하 배너(원본 RootView overlay).
          builder: (context, child) =>
              Stack(children: [child!, const _UnlockBannerHost()]),
          home: const HomeScreen(),
        ),
      ),
    );
  }
}

/// 갓 해금한 칭호 축하 배너 — 잠깐(2.8초) 떴다 자동으로 사라진다.
class _UnlockBannerHost extends StatefulWidget {
  const _UnlockBannerHost();

  @override
  State<_UnlockBannerHost> createState() => _UnlockBannerHostState();
}

class _UnlockBannerHostState extends State<_UnlockBannerHost> {
  final store = LocalStore.shared;
  Title? _shown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    store.addListener(_sync);
  }

  @override
  void dispose() {
    store.removeListener(_sync);
    _timer?.cancel();
    super.dispose();
  }

  void _sync() {
    final t = store.pendingUnlockToast;
    if (t == null || t.id == _shown?.id) return;
    setState(() => _shown = t);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 2800), () {
      store.clearUnlockToast(t);
      if (mounted) setState(() => _shown = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _shown;
    final t = AppTheme.of(context);
    return Positioned(
      left: 0,
      right: 0,
      top: MediaQuery.paddingOf(context).top + 8,
      child: IgnorePointer(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                  position: Tween(begin: const Offset(0, -1), end: Offset.zero)
                      .animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
                  child: c)),
          child: title == null
              ? const SizedBox.shrink()
              : Padding(
                  key: ValueKey(title.id),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: title.rarity.color.withValues(alpha: 0.5)),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(children: [
                        Icon(TitleRarity.common.icon,
                            size: 22, color: title.rarity.color),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('새 칭호 획득!',
                                    style: TextStyle(
                                        color: t.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(title.name,
                                    style: TextStyle(
                                        color: t.text,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                              ]),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: title.rarity.color.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(100)),
                          child: Text(title.rarity.label,
                              style: TextStyle(
                                  color: title.rarity.color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ]),
                    ),
                  ),
                ),
        ),
=======
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
>>>>>>> b7044c5f47a3cc3a46cf09873deec5db40c3c62e
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
