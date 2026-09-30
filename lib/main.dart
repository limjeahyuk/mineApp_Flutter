import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/auth_service.dart';
import 'core/local_store.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStore.init();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // 익명 로그인은 백그라운드로(솔로엔 불필요, 멀티 대비). 실패해도 게임은 진행.
  AuthService.ensureSignedIn().then((_) {}).catchError((_) {});
  runApp(const MineApp());
}

class MineApp extends StatelessWidget {
  const MineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([themeModeNotifier, colorThemeNotifier]),
      builder: (_, _) => MaterialApp(
        key: ValueKey(colorThemeNotifier.value),
        title: '지뢰찾기 아레나',
        debugShowCheckedModeBanner: false,
        themeMode: themeModeNotifier.value,
        theme: buildAppTheme(Brightness.light),
        darkTheme: buildAppTheme(Brightness.dark),
        home: const HomeScreen(),
      ),
    );
  }
}
