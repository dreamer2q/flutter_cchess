import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_cchess/chess/bloc/chess_bloc.dart';
import 'package:flutter_cchess/chess/game/ai_strength.dart';
import 'package:flutter_cchess/chess/notation/game_notation.dart';
import 'package:flutter_cchess/chess/theme/wood_theme.dart';
import 'package:flutter_cchess/chess/view/chess_page.dart';
import 'package:flutter_cchess/help/help_pages.dart';
import 'package:flutter_cchess/settings/settings.dart';
import 'package:flutter_cchess/storage/storage.dart';
import 'package:flutter_cchess/theme/bloc/theme_bloc.dart';
import 'package:flutter_cchess/utils/fen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NewChessPage extends StatefulWidget {
  const NewChessPage({super.key, this.pickNotationFile});

  final Future<XFile?> Function()? pickNotationFile;

  @override
  State<NewChessPage> createState() => _NewChessPageState();
}

class _NewChessPageState extends State<NewChessPage> {
  late Future<_HomeData> _homeData = _loadHomeData();
  int _timeControlSeconds = 900;
  AiStrength? _selectedStrength;
  AiStrength? _selectedRedStrength;
  AiStrength? _selectedBlackStrength;

  Future<_HomeData> _loadHomeData() async {
    final preferences = await SharedPreferences.getInstance();
    final record = await SharedPreferencesGameRepository(
      preferences,
    ).getLatestInProgress();
    final settings = await SharedPreferencesGameSettingsRepository(
      preferences,
    ).load();
    return _HomeData(
      currentGame: record?.result == GameResult.inProgress ? record : null,
      settings: settings,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeData>(
      future: _homeData,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const _HomeData();
        final currentGame = data.currentGame;
        final aiStrength = _selectedStrength ?? data.settings.aiStrength;
        final redAiStrength = _selectedRedStrength ?? data.settings.aiStrength;
        final blackAiStrength =
            _selectedBlackStrength ?? data.settings.aiStrength;
        return Scaffold(
          backgroundColor: const Color(0xFFF0F2F1),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final desktop = constraints.maxWidth >= 860;
                return Column(
                  children: [
                    _HomeHeader(
                      onHelp: _openRules,
                      onAbout: _openAbout,
                      onSettings: () => _openSettings(data.settings),
                    ),
                    Expanded(
                      child: desktop
                          ? _DesktopHome(
                              currentGame: currentGame,
                              onOpen: (mode) => _openGame(mode, data.settings),
                              onContinue: _continueGame,
                              onImport: _importRecord,
                              timeControlSeconds: _timeControlSeconds,
                              aiStrength: aiStrength,
                              redAiStrength: redAiStrength,
                              blackAiStrength: blackAiStrength,
                              onTimeChanged: (value) =>
                                  setState(() => _timeControlSeconds = value),
                              onStrengthChanged: (value) =>
                                  setState(() => _selectedStrength = value),
                              onRedStrengthChanged: (value) =>
                                  setState(() => _selectedRedStrength = value),
                              onBlackStrengthChanged: (value) => setState(
                                () => _selectedBlackStrength = value,
                              ),
                            )
                          : _MobileHome(
                              currentGame: currentGame,
                              onOpen: (mode) => _openGame(mode, data.settings),
                              onContinue: _continueGame,
                              onImport: _importRecord,
                              timeControlSeconds: _timeControlSeconds,
                              aiStrength: aiStrength,
                              redAiStrength: redAiStrength,
                              blackAiStrength: blackAiStrength,
                              onTimeChanged: (value) =>
                                  setState(() => _timeControlSeconds = value),
                              onStrengthChanged: (value) =>
                                  setState(() => _selectedStrength = value),
                              onRedStrengthChanged: (value) =>
                                  setState(() => _selectedRedStrength = value),
                              onBlackStrengthChanged: (value) => setState(
                                () => _selectedBlackStrength = value,
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _openGame(PlayMode playMode, GameSettings settings) async {
    final strength = _selectedStrength ?? settings.aiStrength;
    final redStrength = _selectedRedStrength ?? settings.aiStrength;
    final blackStrength = _selectedBlackStrength ?? settings.aiStrength;
    final usesConfiguredLimits = strength == settings.aiStrength;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChessPage(
          playMode: playMode,
          timeControlSeconds: _timeControlSeconds,
          aiStrength: strength,
          redAiStrength: redStrength,
          blackAiStrength: blackStrength,
          aiMaxDepth: usesConfiguredLimits
              ? settings.aiMaxDepth
              : strength.maxDepth,
          aiMaxThinkMs: usesConfiguredLimits
              ? settings.aiMaxThinkMs
              : strength.maxThinkMs,
        ),
      ),
    );
    _reloadHome();
  }

  Future<void> _continueGame(GameRecord record) async {
    final mode = switch (record.mode) {
      GamePlayMode.self => PlayMode.withSelf,
      GamePlayMode.ai => PlayMode.withAI,
      GamePlayMode.aiVsAi => PlayMode.withAIvsAI,
    };
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChessPage(playMode: mode, initialRecord: record),
      ),
    );
    _reloadHome();
  }

  Future<void> _openRules() => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => const XiangqiRulesPage()),
  );

  Future<void> _openAbout() => Navigator.of(
    context,
  ).push<void>(MaterialPageRoute<void>(builder: (_) => const AboutPage()));

  Future<void> _importRecord() async {
    try {
      final file = await (widget.pickNotationFile?.call() ?? openFile());
      if (file == null) return;
      if (await file.length() > 2 * 1024 * 1024) {
        throw const FormatException('棋谱文件不能超过 2 MB。');
      }
      final record = GameNotationImporter.parse(await file.readAsString());
      final preferences = await SharedPreferences.getInstance();
      await SharedPreferencesGameRepository(preferences).save(record);
      if (mounted) await _continueGame(record);
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法读取棋谱文件。')));
      }
    }
  }

  Future<void> _openSettings(GameSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesGameSettingsRepository(preferences);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider(
          create: (_) =>
              ThemeBloc()..add(ThemeAssetRequested(settings.themeConfigAsset)),
          child: GameSettingsPage(
            initialSettings: settings,
            onSettingsChanged: repository.save,
          ),
        ),
      ),
    );
    _reloadHome();
  }

  void _reloadHome() {
    if (mounted) {
      setState(() {
        _selectedStrength = null;
        _selectedRedStrength = null;
        _selectedBlackStrength = null;
        _homeData = _loadHomeData();
      });
    }
  }
}

class _HomeData {
  const _HomeData({this.currentGame, this.settings = const GameSettings()});

  final GameRecord? currentGame;
  final GameSettings settings;
}

String _strengthLabel(AiStrength strength) => switch (strength) {
  AiStrength.easy => '入门',
  AiStrength.normal => '普通',
  AiStrength.hard => '较强',
};

String _gamePlayModeLabel(GamePlayMode mode) => switch (mode) {
  GamePlayMode.self => '本地双人',
  GamePlayMode.ai => '人机对局',
  GamePlayMode.aiVsAi => 'AI 对战',
};

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.onHelp,
    required this.onAbout,
    required this.onSettings,
  });

  final VoidCallback onHelp;
  final VoidCallback onAbout;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showMode = constraints.maxWidth >= 420;
        return SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.grid_4x4, color: Color(0xFF202625), size: 22),
                const SizedBox(width: 12),
                Text(
                  '中国象棋',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF202625),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (showMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      '离线对局',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF68716E),
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: '象棋规则',
                  onPressed: onHelp,
                  icon: const Icon(Icons.help_outline_rounded),
                ),
                IconButton(
                  tooltip: '关于中国象棋',
                  onPressed: onAbout,
                  icon: const Icon(Icons.info_outline_rounded),
                ),
                IconButton(
                  tooltip: '设置',
                  onPressed: onSettings,
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DesktopHome extends StatelessWidget {
  const _DesktopHome({
    required this.onOpen,
    required this.onContinue,
    required this.onImport,
    required this.currentGame,
    required this.timeControlSeconds,
    required this.aiStrength,
    required this.redAiStrength,
    required this.blackAiStrength,
    required this.onTimeChanged,
    required this.onStrengthChanged,
    required this.onRedStrengthChanged,
    required this.onBlackStrengthChanged,
  });

  final ValueChanged<PlayMode> onOpen;
  final ValueChanged<GameRecord> onContinue;
  final VoidCallback onImport;
  final GameRecord? currentGame;
  final int timeControlSeconds;
  final AiStrength aiStrength;
  final AiStrength redAiStrength;
  final AiStrength blackAiStrength;
  final ValueChanged<int> onTimeChanged;
  final ValueChanged<AiStrength> onStrengthChanged;
  final ValueChanged<AiStrength> onRedStrengthChanged;
  final ValueChanged<AiStrength> onBlackStrengthChanged;

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
                child: SingleChildScrollView(
                  child: _ModeChooser(
                    onOpen: onOpen,
                    onContinue: onContinue,
                    onImport: onImport,
                    currentGame: currentGame,
                    timeControlSeconds: timeControlSeconds,
                    aiStrength: aiStrength,
                    redAiStrength: redAiStrength,
                    blackAiStrength: blackAiStrength,
                    onTimeChanged: onTimeChanged,
                    onStrengthChanged: onStrengthChanged,
                    onRedStrengthChanged: onRedStrengthChanged,
                    onBlackStrengthChanged: onBlackStrengthChanged,
                  ),
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
    required this.onImport,
    required this.currentGame,
    required this.timeControlSeconds,
    required this.aiStrength,
    required this.redAiStrength,
    required this.blackAiStrength,
    required this.onTimeChanged,
    required this.onStrengthChanged,
    required this.onRedStrengthChanged,
    required this.onBlackStrengthChanged,
  });

  final ValueChanged<PlayMode> onOpen;
  final ValueChanged<GameRecord> onContinue;
  final VoidCallback onImport;
  final GameRecord? currentGame;
  final int timeControlSeconds;
  final AiStrength aiStrength;
  final AiStrength redAiStrength;
  final AiStrength blackAiStrength;
  final ValueChanged<int> onTimeChanged;
  final ValueChanged<AiStrength> onStrengthChanged;
  final ValueChanged<AiStrength> onRedStrengthChanged;
  final ValueChanged<AiStrength> onBlackStrengthChanged;

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
            onImport: onImport,
            currentGame: currentGame,
            timeControlSeconds: timeControlSeconds,
            aiStrength: aiStrength,
            redAiStrength: redAiStrength,
            blackAiStrength: blackAiStrength,
            onTimeChanged: onTimeChanged,
            onStrengthChanged: onStrengthChanged,
            onRedStrengthChanged: onRedStrengthChanged,
            onBlackStrengthChanged: onBlackStrengthChanged,
          ),
        ],
      ),
    );
  }
}

class _BoardPreview extends StatelessWidget {
  const _BoardPreview();

  static final _opening = FenUtil.parse(initialFenString);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: 521 / 577,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: 521,
                height: 577,
                child: Stack(
                  children: [
                    Image.asset(
                      'assets/skins/woods/board.jpg',
                      width: 521,
                      height: 577,
                      fit: BoxFit.fill,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                      child: _PreviewPieces(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewPieces extends StatelessWidget {
  const _PreviewPieces();

  @override
  Widget build(BuildContext context) {
    const theme = WoodsBoardTheme();
    return Stack(
      children: _BoardPreview._opening.pcPairs
          .map(
            (pair) => Align(
              alignment: theme.getAlignment(pair.pos),
              child: theme.buildPiece(context, pair.piece),
            ),
          )
          .toList(),
    );
  }
}

class _ModeChooser extends StatelessWidget {
  const _ModeChooser({
    required this.onOpen,
    required this.onContinue,
    required this.onImport,
    required this.currentGame,
    required this.timeControlSeconds,
    required this.aiStrength,
    required this.redAiStrength,
    required this.blackAiStrength,
    required this.onTimeChanged,
    required this.onStrengthChanged,
    required this.onRedStrengthChanged,
    required this.onBlackStrengthChanged,
  });

  final ValueChanged<PlayMode> onOpen;
  final ValueChanged<GameRecord> onContinue;
  final VoidCallback onImport;
  final GameRecord? currentGame;
  final int timeControlSeconds;
  final AiStrength aiStrength;
  final AiStrength redAiStrength;
  final AiStrength blackAiStrength;
  final ValueChanged<int> onTimeChanged;
  final ValueChanged<AiStrength> onStrengthChanged;
  final ValueChanged<AiStrength> onRedStrengthChanged;
  final ValueChanged<AiStrength> onBlackStrengthChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '开始对局',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF202625),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '选择单机模式，棋局将自动保存在本机。',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF68716E)),
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final timeField = DropdownButtonFormField<int>(
                initialValue: timeControlSeconds,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '每方用时',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 300, child: Text('5 分钟')),
                  DropdownMenuItem(value: 600, child: Text('10 分钟')),
                  DropdownMenuItem(value: 900, child: Text('15 分钟')),
                  DropdownMenuItem(value: 1800, child: Text('30 分钟')),
                  DropdownMenuItem(value: 0, child: Text('不限时')),
                ],
                onChanged: (value) {
                  if (value != null) onTimeChanged(value);
                },
              );
              final strengthField = DropdownButtonFormField<AiStrength>(
                initialValue: aiStrength,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '电脑强度',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: AiStrength.easy, child: Text('入门')),
                  DropdownMenuItem(value: AiStrength.normal, child: Text('普通')),
                  DropdownMenuItem(value: AiStrength.hard, child: Text('较强')),
                ],
                onChanged: (value) {
                  if (value != null) onStrengthChanged(value);
                },
              );
              if (constraints.maxWidth < 340) {
                return Column(
                  children: [
                    timeField,
                    const SizedBox(height: 12),
                    strengthField,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: timeField),
                  const SizedBox(width: 12),
                  Expanded(child: strengthField),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Text(
            'AI 对战强度',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF46514D),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              DropdownButtonFormField<AiStrength> strengthField({
                required String label,
                required AiStrength strength,
                required ValueChanged<AiStrength> onChanged,
              }) => DropdownButtonFormField<AiStrength>(
                initialValue: strength,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: label,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: AiStrength.easy, child: Text('入门')),
                  DropdownMenuItem(value: AiStrength.normal, child: Text('普通')),
                  DropdownMenuItem(value: AiStrength.hard, child: Text('较强')),
                ],
                onChanged: (value) {
                  if (value != null) onChanged(value);
                },
              );
              final redField = strengthField(
                label: '红方电脑',
                strength: redAiStrength,
                onChanged: onRedStrengthChanged,
              );
              final blackField = strengthField(
                label: '黑方电脑',
                strength: blackAiStrength,
                onChanged: onBlackStrengthChanged,
              );
              if (constraints.maxWidth < 340) {
                return Column(
                  children: [redField, const SizedBox(height: 10), blackField],
                );
              }
              return Row(
                children: [
                  Expanded(child: redField),
                  const SizedBox(width: 12),
                  Expanded(child: blackField),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          if (currentGame != null) ...[
            _ModeButton(
              icon: Icons.play_arrow,
              title: '继续上局',
              description:
                  '${_gamePlayModeLabel(currentGame!.mode)} · ${currentGame!.moves.length} 步',
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
            icon: Icons.smart_toy,
            title: 'AI 对战',
            description:
                '红方 ${_strengthLabel(redAiStrength)} · 黑方 ${_strengthLabel(blackAiStrength)}',
            onTap: () => onOpen(PlayMode.withAIvsAI),
          ),
          const SizedBox(height: 12),
          _ModeButton(
            icon: Icons.people_outline,
            title: '本地双人',
            description: '同一设备轮流落子',
            onTap: () => onOpen(PlayMode.withSelf),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.folder_open_outlined),
            label: const Text('导入棋谱'),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(
                Icons.lock_outline,
                color: Color(0xFF68716E),
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '无账号、无联网，数据仅保存在当前设备',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF68716E),
                  ),
                ),
              ),
            ],
          ),
        ],
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
        ? const Color(0xFF23795D)
        : const Color(0xFFFFFFFF);
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: emphasized ? const Color(0xFF23795D) : const Color(0x33717F7B),
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
                Icon(
                  icon,
                  color: emphasized ? Colors.white : const Color(0xFF202625),
                  size: 27,
                ),
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
                              color: emphasized
                                  ? Colors.white
                                  : const Color(0xFF202625),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: emphasized
                              ? Colors.white70
                              : const Color(0xFF68716E),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: emphasized ? Colors.white70 : const Color(0xFF68716E),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
