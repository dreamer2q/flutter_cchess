import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_cchess/debug/ui_debug_overlay.dart';
import 'package:flutter/services.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter_cchess/chess/view/new_chess_page.dart';

class AppBlocObserver extends BlocObserver {
  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    log('onChange(${bloc.runtimeType}, ${change.currentState})');
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    log('onError(${bloc.runtimeType}, $error, $stackTrace)');
    super.onError(bloc, error, stackTrace);
  }
}

void main() {
  Bloc.observer = AppBlocObserver();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF171A1A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '中国象棋',
      builder: (context, child) =>
          UiDebugOverlay(child: child ?? const SizedBox.shrink()),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2D9B73),
          brightness: Brightness.light,
          surface: const Color(0xFFF9F8F5),
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F1EC),
        visualDensity: VisualDensity.standard,
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          showDragHandle: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const NewChessPage(),
    );
  }
}
