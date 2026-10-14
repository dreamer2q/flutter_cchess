import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_cchess/chess/bloc/chess_bloc.dart';
import 'package:flutter_cchess/chess/game/ai_strength.dart';
import 'package:flutter_cchess/chess/notation/game_notation.dart';
import 'package:flutter_cchess/chess/view/chess_page.dart';
import 'package:flutter_cchess/help/help_pages.dart';
import 'package:flutter_cchess/settings/settings.dart';
import 'package:flutter_cchess/storage/storage.dart';
import 'package:flutter_cchess/theme/bloc/theme_bloc.dart';
import 'package:flutter_cchess/theme/app_chrome.dart';
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
        return BlocProvider(
          key: ValueKey(data.settings.themeConfigAsset),
          create: (_) =>
              ThemeBloc()
                ..add(ThemeAssetRequested(data.settings.themeConfigAsset)),
          child: Scaffold(
            backgroundColor: AppPalette.canvas,
            body: AppBackdrop(
              child: SafeArea(
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
                                  onOpen: (mode) =>
                                      _openGame(mode, data.settings),
                                  onContinue: _continueGame,
                                  onImport: _importRecord,
                                )
                              : _MobileHome(
                                  currentGame: currentGame,
                                  onOpen: (mode) =>
                                      _openGame(mode, data.settings),
                                  onContinue: _continueGame,
                                  onImport: _importRecord,
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openGame(PlayMode playMode, GameSettings settings) async {
    if (playMode == PlayMode.withAIvsAI) {
      final config = await showDialog<_AiVsAiConfig>(
        context: context,
        builder: (_) =>
            _AiVsAiSetupDialog(initialTimeControlSeconds: _timeControlSeconds),
      );
      if (config == null || !mounted) return;
      setState(() => _timeControlSeconds = config.timeControlSeconds);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChessPage(
            playMode: playMode,
            timeControlSeconds: config.timeControlSeconds,
            aiStrength: config.redStrength,
            redAiStrength: config.redStrength,
            blackAiStrength: config.blackStrength,
            aiMaxDepth: config.redDepth,
            aiMaxThinkMs: config.redStrength.maxThinkMs,
            redAiMaxDepth: config.redDepth,
            blackAiMaxDepth: config.blackDepth,
            aiVsAiStepDelayMs: config.stepDelayMs,
          ),
        ),
      );
      _reloadHome();
      return;
    }
    if (playMode == PlayMode.withAI || playMode == PlayMode.withSelf) {
      final config = await showDialog<_HumanVsAiConfig>(
        context: context,
        builder: (_) => _GameSetupDialog(
          localTwoPlayer: playMode == PlayMode.withSelf,
          initialTimeControlSeconds: _timeControlSeconds,
          initialStrength: _selectedStrength ?? settings.aiStrength,
          initialMaxDepth:
              _selectedStrength == null ||
                  _selectedStrength == settings.aiStrength
              ? settings.aiMaxDepth
              : _selectedStrength!.maxDepth,
          initialMaxThinkMs:
              _selectedStrength == null ||
                  _selectedStrength == settings.aiStrength
              ? settings.aiMaxThinkMs
              : _selectedStrength!.maxThinkMs,
        ),
      );
      if (config == null || !mounted) return;
      setState(() {
        _timeControlSeconds = config.timeControlSeconds;
        _selectedStrength = config.strength;
      });
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChessPage(
            playMode: playMode,
            timeControlSeconds: config.timeControlSeconds,
            aiStrength: config.strength,
            aiMaxDepth: config.maxDepth,
            aiMaxThinkMs: config.maxThinkMs,
          ),
        ),
      );
      _reloadHome();
      return;
    }
    final strength = _selectedStrength ?? settings.aiStrength;
    final usesConfiguredLimits = strength == settings.aiStrength;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChessPage(
          playMode: playMode,
          timeControlSeconds: _timeControlSeconds,
          aiStrength: strength,
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
        return AppGlassSurface(
          borderRadius: BorderRadius.zero,
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(
                    Icons.grid_4x4,
                    color: Color(0xFF202625),
                    size: 22,
                  ),
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
  });

  final ValueChanged<PlayMode> onOpen;
  final ValueChanged<GameRecord> onContinue;
  final VoidCallback onImport;
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
                child: SingleChildScrollView(
                  child: _ModeChooser(
                    onOpen: onOpen,
                    onContinue: onContinue,
                    onImport: onImport,
                    currentGame: currentGame,
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
  });

  final ValueChanged<PlayMode> onOpen;
  final ValueChanged<GameRecord> onContinue;
  final VoidCallback onImport;
  final GameRecord? currentGame;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      child: Column(
        children: [
          _ModeChooser(
            onOpen: onOpen,
            onContinue: onContinue,
            onImport: onImport,
            currentGame: currentGame,
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 220, child: _BoardPreview()),
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
    final theme = context.watch<ThemeBloc>().state.theme;
    return Center(
      child: AspectRatio(
        aspectRatio: theme.boardSize.aspectRatio,
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
                width: theme.boardSize.width,
                height: theme.boardSize.height,
                child: Stack(
                  children: [
                    theme.buildBoard(context),
                    Padding(
                      padding: theme.boardPadding,
                      child: const _PreviewPieces(),
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
    final theme = context.watch<ThemeBloc>().state.theme;
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
  });

  final ValueChanged<PlayMode> onOpen;
  final ValueChanged<GameRecord> onContinue;
  final VoidCallback onImport;
  final GameRecord? currentGame;

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
          TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const XiangqiRulesPage()),
            ),
            icon: const Icon(Icons.help_outline_rounded, size: 18),
            label: const Text('第一次玩？查看象棋规则'),
          ),
          const SizedBox(height: 22),
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
            description: '和电脑下，开始前选择用时和难度',
            emphasized: currentGame == null,
            onTap: () => onOpen(PlayMode.withAI),
          ),
          const SizedBox(height: 12),
          _ModeButton(
            icon: Icons.smart_toy,
            title: 'AI 对战',
            description: '观看两台电脑自动对弈',
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

class _HumanVsAiConfig {
  const _HumanVsAiConfig({
    required this.timeControlSeconds,
    required this.strength,
    required this.maxDepth,
    required this.maxThinkMs,
  });

  final int timeControlSeconds;
  final AiStrength strength;
  final int maxDepth;
  final int maxThinkMs;
}

class _GameSetupDialog extends StatefulWidget {
  const _GameSetupDialog({
    required this.localTwoPlayer,
    required this.initialTimeControlSeconds,
    required this.initialStrength,
    required this.initialMaxDepth,
    required this.initialMaxThinkMs,
  });

  final bool localTwoPlayer;
  final int initialTimeControlSeconds;
  final AiStrength initialStrength;
  final int initialMaxDepth;
  final int initialMaxThinkMs;

  @override
  State<_GameSetupDialog> createState() => _GameSetupDialogState();
}

class _GameSetupDialogState extends State<_GameSetupDialog> {
  late int _timeControlSeconds = widget.initialTimeControlSeconds;
  late AiStrength _strength = widget.initialStrength;
  late int _maxDepth = widget.initialMaxDepth;
  late int _maxThinkMs = widget.initialMaxThinkMs;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.localTwoPlayer ? '本地双人' : '和电脑下'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.localTwoPlayer ? '两位玩家共用设备，红方先行。' : '先选好对局节奏，开始后也可以暂停。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              const Text('每方用时'),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _timeControlSeconds,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.timer_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 300, child: Text('5 分钟')),
                  DropdownMenuItem(value: 600, child: Text('10 分钟')),
                  DropdownMenuItem(value: 900, child: Text('15 分钟（推荐）')),
                  DropdownMenuItem(value: 1800, child: Text('30 分钟')),
                  DropdownMenuItem(value: 0, child: Text('不限时')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _timeControlSeconds = value);
                  }
                },
              ),
              if (!widget.localTwoPlayer) ...[
                const SizedBox(height: 20),
                const Text('电脑难度'),
                const SizedBox(height: 8),
                DropdownButtonFormField<AiStrength>(
                  initialValue: _strength,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.smart_toy_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: AiStrength.easy,
                      child: Text('入门 · 走得快，适合第一次玩'),
                    ),
                    DropdownMenuItem(
                      value: AiStrength.normal,
                      child: Text('普通 · 推荐'),
                    ),
                    DropdownMenuItem(
                      value: AiStrength.hard,
                      child: Text('较强 · 思考更久'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _strength = value;
                        _maxDepth = value.maxDepth;
                        _maxThinkMs = value.maxThinkMs;
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '电脑会根据难度和剩余用时自动安排思考。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF68716E),
                  ),
                ),
                const SizedBox(height: 8),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: const Text('高级设置'),
                  subtitle: const Text('通常不需要调整'),
                  children: [
                    _depthControl(
                      title: '搜索深度上限',
                      depth: _maxDepth,
                      onChanged: (value) => setState(() => _maxDepth = value),
                    ),
                    _thinkTimeControl(),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(
            context,
            _HumanVsAiConfig(
              timeControlSeconds: _timeControlSeconds,
              strength: _strength,
              maxDepth: _maxDepth,
              maxThinkMs: _maxThinkMs,
            ),
          ),
          icon: const Icon(Icons.play_arrow),
          label: const Text('开始对局'),
        ),
      ],
    );
  }

  Widget _depthControl({
    required String title,
    required int depth,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Text(title),
            const Spacer(),
            Text(depth == 0 ? '自动' : '$depth 层'),
          ],
        ),
        Slider(
          value: depth.toDouble(),
          min: 0,
          max: AiStrength.maxConfiguredDepth.toDouble(),
          divisions: AiStrength.maxConfiguredDepth,
          label: depth == 0 ? '自动' : '$depth 层',
          onChanged: (value) => onChanged(value.round()),
        ),
      ],
    );
  }

  Widget _thinkTimeControl() {
    return Row(
      children: [
        const Expanded(child: Text('基础思考时间')),
        DropdownButton<int>(
          value: const [300, 1500, 5000].contains(_maxThinkMs)
              ? _maxThinkMs
              : null,
          hint: const Text('自定义'),
          items: const [
            DropdownMenuItem(value: 300, child: Text('较快')),
            DropdownMenuItem(value: 1500, child: Text('标准')),
            DropdownMenuItem(value: 5000, child: Text('更深')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _maxThinkMs = value);
          },
        ),
      ],
    );
  }
}

class _AiVsAiConfig {
  const _AiVsAiConfig({
    required this.timeControlSeconds,
    required this.redStrength,
    required this.redDepth,
    required this.blackStrength,
    required this.blackDepth,
    required this.stepDelayMs,
  });

  final int timeControlSeconds;
  final AiStrength redStrength;
  final int redDepth;
  final AiStrength blackStrength;
  final int blackDepth;
  final int stepDelayMs;
}

class _AiVsAiSetupDialog extends StatefulWidget {
  const _AiVsAiSetupDialog({required this.initialTimeControlSeconds});

  final int initialTimeControlSeconds;

  @override
  State<_AiVsAiSetupDialog> createState() => _AiVsAiSetupDialogState();
}

class _AiVsAiSetupDialogState extends State<_AiVsAiSetupDialog> {
  late int _timeControlSeconds = widget.initialTimeControlSeconds;
  AiStrength _redStrength = AiStrength.hard;
  int _redDepth = AiStrength.automaticDepth;
  AiStrength _blackStrength = AiStrength.hard;
  int _blackDepth = AiStrength.automaticDepth;
  int _stepDelayMs = 800;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('AI 对战'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.sizeOf(context).height * 0.65,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('每方用时'),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _timeControlSeconds,
                isExpanded: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 300, child: Text('5 分钟')),
                  DropdownMenuItem(value: 600, child: Text('10 分钟')),
                  DropdownMenuItem(value: 900, child: Text('15 分钟')),
                  DropdownMenuItem(value: 1800, child: Text('30 分钟')),
                  DropdownMenuItem(value: 0, child: Text('不限时')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _timeControlSeconds = value);
                  }
                },
              ),
              const SizedBox(height: 20),
              _sideControls(
                title: '红方电脑',
                strength: _redStrength,
                onStrengthChanged: (value) =>
                    setState(() => _redStrength = value),
              ),
              const SizedBox(height: 20),
              _sideControls(
                title: '黑方电脑',
                strength: _blackStrength,
                onStrengthChanged: (value) =>
                    setState(() => _blackStrength = value),
              ),
              const SizedBox(height: 20),
              const Text('落子间隔'),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _stepDelayMs,
                isExpanded: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('无停顿')),
                  DropdownMenuItem(value: 400, child: Text('0.4 秒')),
                  DropdownMenuItem(value: 800, child: Text('0.8 秒')),
                  DropdownMenuItem(value: 1200, child: Text('1.2 秒')),
                  DropdownMenuItem(value: 1800, child: Text('1.8 秒')),
                  DropdownMenuItem(value: 2500, child: Text('2.5 秒')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _stepDelayMs = value);
                  }
                },
              ),
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text('高级设置'),
                children: [
                  _depthControl(
                    title: '红方搜索深度',
                    depth: _redDepth,
                    onChanged: (value) => setState(() => _redDepth = value),
                  ),
                  _depthControl(
                    title: '黑方搜索深度',
                    depth: _blackDepth,
                    onChanged: (value) => setState(() => _blackDepth = value),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(
            context,
            _AiVsAiConfig(
              timeControlSeconds: _timeControlSeconds,
              redStrength: _redStrength,
              redDepth: _redDepth,
              blackStrength: _blackStrength,
              blackDepth: _blackDepth,
              stepDelayMs: _stepDelayMs,
            ),
          ),
          icon: const Icon(Icons.play_arrow),
          label: const Text('开始对战'),
        ),
      ],
    );
  }

  Widget _sideControls({
    required String title,
    required AiStrength strength,
    required ValueChanged<AiStrength> onStrengthChanged,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<AiStrength>(
          initialValue: strength,
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: AiStrength.easy, child: Text('入门')),
            DropdownMenuItem(value: AiStrength.normal, child: Text('普通')),
            DropdownMenuItem(value: AiStrength.hard, child: Text('较强')),
          ],
          onChanged: (value) {
            if (value != null) {
              onStrengthChanged(value);
            }
          },
        ),
      ],
    );
  }

  Widget _depthControl({
    required String title,
    required int depth,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Text(title),
            const Spacer(),
            Text(depth == 0 ? '自动' : '$depth 层'),
          ],
        ),
        Slider(
          value: depth.toDouble(),
          min: 0,
          max: AiStrength.maxConfiguredDepth.toDouble(),
          divisions: AiStrength.maxConfiguredDepth,
          label: depth == 0 ? '自动' : '$depth 层',
          onChanged: (value) => onChanged(value.round()),
        ),
      ],
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
