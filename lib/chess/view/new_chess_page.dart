import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_cchess/chess/bloc/chess_bloc.dart';
import 'package:flutter_cchess/chess/view/chess_page.dart';
import 'package:flutter_cchess/storage/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NewChessPage extends StatefulWidget {
  const NewChessPage({super.key});

  @override
  State<NewChessPage> createState() => _NewChessPageState();
}

class _NewChessPageState extends State<NewChessPage> {
  late Future<GameRecord?> _currentGame = _loadCurrentGame();

  Future<GameRecord?> _loadCurrentGame() async {
    final preferences = await SharedPreferences.getInstance();
    final record = await SharedPreferencesGameRepository(
      preferences,
    ).getLatestInProgress();
    return record?.result == GameResult.inProgress ? record : null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GameRecord?>(
      future: _currentGame,
      builder: (context, snapshot) {
        final currentGame = snapshot.data;
        return Scaffold(
          backgroundColor: const Color(0xFF171A1A),
          body: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/skins/night/background-desktop.png',
                fit: BoxFit.cover,
              ),
              const ColoredBox(color: Color(0xA6171A1A)),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final desktop = constraints.maxWidth >= 860;
                    return Column(
                      children: [
                        const _HomeHeader(),
                        Expanded(
                          child: desktop
                              ? _DesktopHome(
                                  currentGame: currentGame,
                                  onOpen: _openGame,
                                  onContinue: _continueGame,
                                )
                              : _MobileHome(
                                  currentGame: currentGame,
                                  onOpen: _openGame,
                                  onContinue: _continueGame,
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openGame(PlayMode playMode) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ChessPage(playMode: playMode)));
    _reloadCurrentGame();
  }

  Future<void> _continueGame(GameRecord record) async {
    final mode = record.mode == GamePlayMode.self
        ? PlayMode.withSelf
        : PlayMode.withAI;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChessPage(playMode: mode, initialRecord: record),
      ),
    );
    _reloadCurrentGame();
  }

  void _reloadCurrentGame() {
    if (mounted) setState(() => _currentGame = _loadCurrentGame());
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            const Icon(Icons.grid_4x4, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Text(
              '中国象棋',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '离线对局',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopHome extends StatelessWidget {
  const _DesktopHome({
    required this.onOpen,
    required this.onContinue,
    required this.currentGame,
  });

  final ValueChanged<PlayMode> onOpen;
  final ValueChanged<GameRecord> onContinue;
  final GameRecord? currentGame;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 18, 28, 32),
          child: Row(
            children: [
              const Expanded(flex: 6, child: _BoardPreview()),
              const SizedBox(width: 36),
              Expanded(
                flex: 4,
                child: _ModeChooser(
                  onOpen: onOpen,
                  onContinue: onContinue,
                  currentGame: currentGame,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileHome extends StatelessWidget {
  const _MobileHome({
    required this.onOpen,
    required this.onContinue,
    required this.currentGame,
  });

  final ValueChanged<PlayMode> onOpen;
  final ValueChanged<GameRecord> onContinue;
  final GameRecord? currentGame;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      child: Column(
        children: [
          const SizedBox(height: 330, child: _BoardPreview()),
          const SizedBox(height: 20),
          _ModeChooser(
            onOpen: onOpen,
            onContinue: onContinue,
            currentGame: currentGame,
          ),
        ],
      ),
    );
  }
}

class _BoardPreview extends StatelessWidget {
  const _BoardPreview();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: 9 / 10,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x99000000),
                blurRadius: 30,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/skins/maple/board.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeChooser extends StatelessWidget {
  const _ModeChooser({
    required this.onOpen,
    required this.onContinue,
    required this.currentGame,
  });

  final ValueChanged<PlayMode> onOpen;
  final ValueChanged<GameRecord> onContinue;
  final GameRecord? currentGame;

  @override
  Widget build(BuildContext context) {
    return _HomeGlass(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '开始对局',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '选择单机模式，棋局将自动保存在本机。',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 22),
            if (currentGame != null) ...[
              _ModeButton(
                icon: Icons.play_arrow,
                title: '继续上局',
                description:
                    '${currentGame!.mode == GamePlayMode.ai ? '人机对局' : '本地双人'} · ${currentGame!.moves.length} 步',
                emphasized: true,
                onTap: () => onContinue(currentGame!),
              ),
              const SizedBox(height: 12),
            ],
            _ModeButton(
              icon: Icons.smart_toy_outlined,
              title: '人机对局',
              description: '执红先行，与本地引擎对弈',
              emphasized: currentGame == null,
              onTap: () => onOpen(PlayMode.withAI),
            ),
            const SizedBox(height: 12),
            _ModeButton(
              icon: Icons.people_outline,
              title: '本地双人',
              description: '同一设备轮流落子',
              onTap: () => onOpen(PlayMode.withSelf),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.lock_outline, color: Colors.white54, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '无账号、无联网，数据仅保存在当前设备',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white54),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final background = emphasized
        ? const Color(0xCC23795D)
        : const Color(0x1FFFFFFF);
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: emphasized ? const Color(0xAA72D6B0) : const Color(0x33FFFFFF),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 76),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 27),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white70),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeGlass extends StatelessWidget {
  const _HomeGlass({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xB0202425),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x33FFFFFF)),
          ),
          child: child,
        ),
      ),
    );
  }
}
