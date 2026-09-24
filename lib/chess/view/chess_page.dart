import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cchess/audio/audio.dart';
import 'package:flutter_cchess/chess/game/game_board.dart';
import 'package:flutter_cchess/chess/game/ai_strength.dart';
import 'package:flutter_cchess/chess/theme/board_corner_marker.dart';
import 'package:flutter_cchess/chess/presentation/game_presentation_coordinator.dart';
import 'package:flutter_cchess/chess/widget/animated_captured_piece.dart';
import 'package:flutter_cchess/chess/widget/animated_invalid_move.dart';
import 'package:flutter_cchess/chess/widget/animated_move.dart';
import 'package:flutter_cchess/chess/widget/animated_overlay.dart';
import 'package:flutter_cchess/models/board.dart';
import 'package:flutter_cchess/models/piece.dart';
import 'package:flutter_cchess/settings/settings.dart';
import 'package:flutter_cchess/storage/storage.dart';
import 'package:flutter_cchess/theme/bloc/theme_bloc.dart';
import 'package:flutter_cchess/timer/ticker.dart';
import 'package:flutter_cchess/utils/utils.dart';

import '../bloc/chess_bloc.dart';
import 'game_layout_policy.dart';

class ChessPage extends StatefulWidget {
  const ChessPage({
    super.key,
    this.playMode = PlayMode.withAI,
    this.initialRecord,
    this.timeControlSeconds = 900,
    this.aiStrength = AiStrength.normal,
  });

  final PlayMode playMode;
  final GameRecord? initialRecord;
  final int timeControlSeconds;
  final AiStrength aiStrength;

  @override
  State<ChessPage> createState() => _ChessPageState();
}

class _ChessPageState extends State<ChessPage> {
  late final Future<_GameBootstrap> _bootstrap = _load();

  Future<_GameBootstrap> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final gameRepository = SharedPreferencesGameRepository(preferences);
    final settingsRepository = SharedPreferencesGameSettingsRepository(
      preferences,
    );
    final record = widget.initialRecord;
    final initialFen = record?.initialFen ?? initialFenString;
    var initialBoard = FenUtil.parse(initialFen);
    if (record != null) {
      for (final move in record.moves) {
        final movePos = MovePos(move.from, move.to);
        if (!initialBoard.isMovable(movePos)) {
          throw const FormatException('Saved game contains an illegal move.');
        }
        initialBoard = initialBoard.copyWith(
          actions: initialBoard.actions.rebuild(
            (actions) => actions..add(BoardMoveAction(movePos.mv)),
          ),
        );
      }
    }
    return _GameBootstrap(
      gameRepository: gameRepository,
      settingsRepository: settingsRepository,
      settings: await settingsRepository.load(),
      initialBoard: initialBoard,
      initialFen: initialFen,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_GameBootstrap>(
      future: _bootstrap,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _LoadingFailure(onBack: () => Navigator.maybePop(context));
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final bootstrap = snapshot.data!;
        return MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => ThemeBloc()
                ..add(ThemeAssetRequested(bootstrap.settings.themeConfigAsset)),
            ),
            BlocProvider(
              create: (_) =>
                  ChessBloc(
                    ticker: Ticker(),
                    repository: bootstrap.gameRepository,
                    initialFen: bootstrap.initialFen,
                    gameId: widget.initialRecord?.id,
                    createdAt: widget.initialRecord?.createdAt,
                  )..add(
                    ChessEventInitialized(
                      initialBoard: bootstrap.initialBoard,
                      playMode: widget.playMode,
                      timeControlSeconds:
                          widget.initialRecord?.timeControlSeconds ??
                          widget.timeControlSeconds,
                      redElapsedMs: widget.initialRecord?.redElapsedMs ?? 0,
                      blackElapsedMs: widget.initialRecord?.blackElapsedMs ?? 0,
                      aiStrength:
                          widget.initialRecord?.aiStrength ?? widget.aiStrength,
                    ),
                  ),
            ),
          ],
          child: ChessView(
            initialSettings: bootstrap.settings,
            settingsRepository: bootstrap.settingsRepository,
            isResumedGame: widget.initialRecord != null,
          ),
        );
      },
    );
  }
}

class _GameBootstrap {
  const _GameBootstrap({
    required this.gameRepository,
    required this.settingsRepository,
    required this.settings,
    required this.initialBoard,
    required this.initialFen,
  });

  final GameRepository gameRepository;
  final GameSettingsRepository settingsRepository;
  final GameSettings settings;
  final Board initialBoard;
  final String initialFen;
}

class _LoadingFailure extends StatelessWidget {
  const _LoadingFailure({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            const Text('无法加载本地棋局'),
            const SizedBox(height: 16),
            FilledButton(onPressed: onBack, child: const Text('返回')),
          ],
        ),
      ),
    );
  }
}

class ChessView extends StatefulWidget {
  const ChessView({
    super.key,
    required this.initialSettings,
    required this.settingsRepository,
    this.isResumedGame = false,
  });

  final GameSettings initialSettings;
  final GameSettingsRepository settingsRepository;
  final bool isResumedGame;

  @override
  State<ChessView> createState() => _ChessViewState();
}

class _ChessViewState extends State<ChessView> with WidgetsBindingObserver {
  late GameSettings _settings = widget.initialSettings;
  late final AudioService _audioService;
  late final GameAudioController _audioController;
  late final GamePresentationCoordinator _presentationCoordinator;
  ChessState? _previousState;
  var _inspectorTab = 0;
  var _resultShown = false;
  var _pausedByLifecycle = false;

  @override
  void initState() {
    super.initState();
    _audioService = AudioplayersAudioService(enabled: _settings.soundEnabled);
    _audioController = GameAudioController(service: _audioService);
    _presentationCoordinator = GamePresentationCoordinator(
      audioController: _audioController,
      haptic: _performHaptic,
    );
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _previousState = context.read<ChessBloc>().state;
      if (!widget.isResumedGame) {
        _playCue(GameAudioCue.newGame, 'new-game');
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_audioController.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) {
      _presentationCoordinator.resume();
      if (_pausedByLifecycle) {
        _pausedByLifecycle = false;
        context.read<ChessBloc>().add(const ChessEventResume());
      }
      return;
    }
    final bloc = context.read<ChessBloc>();
    if (bloc.state.canPause) {
      _pausedByLifecycle = true;
      bloc.add(const ChessEventPause());
    }
    unawaited(_presentationCoordinator.suspend());
  }

  Future<void> _saveSettings(GameSettings settings) async {
    final soundChanged = settings.soundEnabled != _settings.soundEnabled;
    setState(() => _settings = settings);
    if (soundChanged) {
      await _audioService.setEnabled(settings.soundEnabled);
    }
    await widget.settingsRepository.save(settings);
  }

  void _handleState(BuildContext context, ChessState state) {
    final previous = _previousState;
    _previousState = state;
    final completed = previous?.activePresentation;
    final feedbackStarted =
        completed != null &&
        state.activePresentation?.id == completed.id &&
        completed.stage == PresentationStage.animating &&
        state.activePresentation?.stage == PresentationStage.feedback;
    final removed =
        completed != null &&
        !state.presentations.any((effect) => effect.id == completed.id);
    if (feedbackStarted ||
        (removed && completed.stage == PresentationStage.animating)) {
      final presented = state.activePresentation?.id == completed.id
          ? state.activePresentation!
          : completed;
      unawaited(
        _presentationCoordinator
            .present(presented, state, hapticsEnabled: _settings.hapticsEnabled)
            .catchError((Object _) {}),
      );
    }
    if (state.phase == GamePhase.finished &&
        state.presentations.isEmpty &&
        !_resultShown) {
      _resultShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showResult(state);
      });
    }
  }

  Future<void> _performHaptic(PresentationHapticKind kind) {
    switch (kind) {
      case PresentationHapticKind.light:
        return HapticFeedback.selectionClick();
      case PresentationHapticKind.medium:
        return HapticFeedback.mediumImpact();
      case PresentationHapticKind.result:
        return HapticFeedback.heavyImpact();
    }
  }

  void _playCue(GameAudioCue cue, Object stepId) {
    _playCues(<GameAudioCue>[cue], stepId);
  }

  void _playCues(Iterable<GameAudioCue> cues, Object stepId) {
    unawaited(
      _audioController
          .playForStep(stepId: stepId, candidates: cues)
          .catchError((Object _) => null),
    );
  }

  Future<void> _showResult(ChessState state) async {
    final winner = state.winningSide;
    final title = winner == null
        ? '和棋'
        : winner == PlaySide.red
        ? '红方胜'
        : '黑方胜';
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: false,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events_outlined, size: 42),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                state.resultReason ?? '棋局已自动保存',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        Navigator.maybePop(context);
                      },
                      icon: const Icon(Icons.home_outlined),
                      label: const Text('返回首页'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChessPage(
                              playMode: state.playMode,
                              timeControlSeconds: state.timeControlSeconds,
                              aiStrength: state.aiStrength,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('再来一局'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _requestExit() async {
    final bloc = context.read<ChessBloc>();
    final state = bloc.state;
    if (state.board.lastMoves.isEmpty || state.phase == GamePhase.finished) {
      await bloc.persistSnapshot();
      if (!mounted) return;
      Navigator.maybePop(context);
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('返回首页？'),
        content: const Text('当前棋局已经自动保存，下次可以继续。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('继续对局'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('返回首页'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      await bloc.persistSnapshot();
      if (mounted) Navigator.maybePop(context);
    }
  }

  Future<void> _requestNewGame(ChessState state) async {
    var confirmed = true;
    if (state.board.lastMoves.isNotEmpty && state.phase != GamePhase.finished) {
      confirmed =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('开始新对局？'),
              content: const Text('当前棋局会保留在本机，新对局将从初始局面开始。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('开始新局'),
                ),
              ],
            ),
          ) ??
          false;
    }
    if (!confirmed || !mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChessPage(
          playMode: state.playMode,
          timeControlSeconds: state.timeControlSeconds,
          aiStrength: state.aiStrength,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final disableAnimations =
        _settings.motionPreference == MotionPreference.reduced
        ? true
        : _settings.motionPreference == MotionPreference.full
        ? false
        : mediaQuery.disableAnimations;
    return MediaQuery(
      data: mediaQuery.copyWith(disableAnimations: disableAnimations),
      child: BlocListener<ChessBloc, ChessState>(
        listenWhen: (previous, current) =>
            previous.phase != current.phase ||
            previous.presentations != current.presentations ||
            previous.winningSide != current.winningSide,
        listener: _handleState,
        child: BlocBuilder<ChessBloc, ChessState>(
          builder: (context, state) {
            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) {
                if (!didPop) _requestExit();
              },
              child: Scaffold(
                backgroundColor: _GameColors.mobileCanvas,
                body: LayoutBuilder(
                  builder: (context, constraints) {
                    final desktop = GameLayoutPolicy.useDesktop(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: desktop
                              ? const _DesktopBackdrop()
                              : const ColoredBox(
                                  color: _GameColors.mobileCanvas,
                                ),
                        ),
                        SafeArea(
                          child: desktop
                              ? _DesktopGameLayout(
                                  state: state,
                                  inspectorTab: _inspectorTab,
                                  onInspectorTabChanged: (value) {
                                    setState(() => _inspectorTab = value);
                                  },
                                  onBack: _requestExit,
                                  onSettings: _showSettings,
                                  onMenu: _showGameMenu,
                                )
                              : _MobileGameLayout(
                                  state: state,
                                  onBack: _requestExit,
                                  onSettings: _showSettings,
                                  onMenu: _showGameMenu,
                                  onNotation: _showNotation,
                                ),
                        ),
                        if (state.phase == GamePhase.paused)
                          _PauseOverlay(
                            onResume: () => context.read<ChessBloc>().add(
                              const ChessEventResume(),
                            ),
                          ),
                        if (state.activePresentation?.tacticalEffect != null &&
                            state.activePresentation?.stage ==
                                PresentationStage.feedback)
                          IgnorePointer(
                            child: Center(
                              child: AnimatedOverlay(
                                key: ValueKey(state.activePresentation!.id),
                                onEnd: () => context.read<ChessBloc>().add(
                                  ChessEventPresentationAcknowledged(
                                    state.activePresentation!.id,
                                  ),
                                ),
                                child: _EffectLabel(
                                  label: _playEffectLabel(
                                    state.activePresentation!.tacticalEffect!,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (state.phase == GamePhase.failure)
                          _FailureOverlay(
                            message: state.failureMessage ?? '对局暂时无法继续。',
                            canRetry: state.canRetryAi,
                            onRetry: () => context.read<ChessBloc>().add(
                              const ChessEventRetryAi(),
                            ),
                            onSwitchToLocal: () => context
                                .read<ChessBloc>()
                                .add(const ChessEventSwitchToLocal()),
                          ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showNotation() async {
    final state = context.read<ChessBloc>().state;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: .68,
        child: _MoveHistory(state: state),
      ),
    );
  }

  Future<void> _showGameMenu() async {
    final bloc = context.read<ChessBloc>();
    final state = bloc.state;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.flip_camera_android_outlined),
                title: const Text('翻转棋盘'),
                enabled: state.canFlip,
                onTap: () {
                  Navigator.pop(sheetContext);
                  bloc.add(const ChessEventFlipBoard());
                },
              ),
              ListTile(
                leading: Icon(
                  state.phase == GamePhase.paused
                      ? Icons.play_arrow
                      : Icons.pause,
                ),
                title: Text(state.phase == GamePhase.paused ? '继续对局' : '暂停对局'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  bloc.add(
                    state.phase == GamePhase.paused
                        ? const ChessEventResume()
                        : const ChessEventPause(),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('主题与声音'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showSettings();
                },
              ),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('新对局'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _requestNewGame(state);
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.red),
                title: const Text('认输', style: TextStyle(color: Colors.red)),
                enabled: state.canResign,
                onTap: () async {
                  final resign = await showDialog<bool>(
                    context: sheetContext,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('确认认输？'),
                      content: const Text('认输后本局将立即结束。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('取消'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('认输'),
                        ),
                      ],
                    ),
                  );
                  if (resign == true && mounted) {
                    Navigator.pop(sheetContext);
                    bloc.add(const ChessEventResign());
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> update(GameSettings next) async {
            setSheetState(() => _settings = next);
            await _saveSettings(next);
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('主题与反馈', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 20),
                  Text('棋盘主题', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 10),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: 'assets/skins/maple/config.json',
                        label: Text('浅色枫木'),
                      ),
                      ButtonSegment(
                        value: 'assets/skins/night/config.json',
                        label: Text('夜间胡桃木'),
                      ),
                      ButtonSegment(
                        value: 'assets/skins/woods/config.json',
                        label: Text('经典'),
                      ),
                    ],
                    selected: {_settings.themeConfigAsset},
                    onSelectionChanged: (selection) {
                      final asset = selection.first;
                      context.read<ThemeBloc>().add(ThemeAssetRequested(asset));
                      update(_settings.copyWith(themeConfigAsset: asset));
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('对局音效'),
                    subtitle: const Text('走子、吃子、将军与结果反馈'),
                    value: _settings.soundEnabled,
                    onChanged: (value) =>
                        update(_settings.copyWith(soundEnabled: value)),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('背景音乐'),
                    subtitle: const Text('音乐素材准备中'),
                    value: false,
                    onChanged: null,
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('触觉反馈'),
                    subtitle: const Text('移动端落子与非法操作反馈'),
                    value: _settings.hapticsEnabled,
                    onChanged: (value) =>
                        update(_settings.copyWith(hapticsEnabled: value)),
                  ),
                  const SizedBox(height: 12),
                  Text('动态效果', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 10),
                  SegmentedButton<MotionPreference>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: MotionPreference.system,
                        label: Text('跟随系统'),
                      ),
                      ButtonSegment(
                        value: MotionPreference.full,
                        label: Text('完整'),
                      ),
                      ButtonSegment(
                        value: MotionPreference.reduced,
                        label: Text('精简'),
                      ),
                    ],
                    selected: {_settings.motionPreference},
                    onSelectionChanged: (selection) => update(
                      _settings.copyWith(motionPreference: selection.first),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MobileGameLayout extends StatelessWidget {
  const _MobileGameLayout({
    required this.state,
    required this.onBack,
    required this.onSettings,
    required this.onMenu,
    required this.onNotation,
  });

  final ChessState state;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final VoidCallback onMenu;
  final VoidCallback onNotation;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GameTopBar(
          title: _modeTitle(state.playMode),
          onBack: onBack,
          onSettings: onSettings,
          onMenu: onMenu,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: _PlayerPanel(
            side: PlaySide.black,
            state: state,
            compact: true,
          ),
        ),
        const Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: ChessBoard(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: _PlayerPanel(side: PlaySide.red, state: state, compact: true),
        ),
        _GameCommandBar(state: state, onNotation: onNotation, onMenu: onMenu),
      ],
    );
  }
}

class _DesktopGameLayout extends StatelessWidget {
  const _DesktopGameLayout({
    required this.state,
    required this.inspectorTab,
    required this.onInspectorTabChanged,
    required this.onBack,
    required this.onSettings,
    required this.onMenu,
  });

  final ChessState state;
  final int inspectorTab;
  final ValueChanged<int> onInspectorTabChanged;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          _GameTopBar(
            title: _modeTitle(state.playMode),
            onBack: onBack,
            onSettings: onSettings,
            onMenu: onMenu,
            desktop: true,
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Expanded(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.only(right: 24),
                            child: ChessBoard(),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: GameLayoutPolicy.inspectorWidth(
                          constraints.maxWidth,
                        ),
                        child: _DesktopInspector(
                          state: state,
                          tab: inspectorTab,
                          onTabChanged: onInspectorTabChanged,
                          onSettings: onSettings,
                          onMenu: onMenu,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameTopBar extends StatelessWidget {
  const _GameTopBar({
    required this.title,
    required this.onBack,
    required this.onSettings,
    required this.onMenu,
    this.desktop = false,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final VoidCallback onMenu;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return _GlassSurface(
      borderRadius: desktop
          ? BorderRadius.zero
          : const BorderRadius.vertical(bottom: Radius.circular(8)),
      child: SizedBox(
        height: desktop ? 56 : 58,
        child: Row(
          children: [
            const SizedBox(width: 6),
            IconButton(
              tooltip: '返回首页',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.grid_4x4, size: 20),
            const SizedBox(width: 10),
            Text('中国象棋', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(width: 12),
            Container(width: 1, height: 20, color: _GameColors.border),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: _GameColors.muted),
              ),
            ),
            IconButton(
              tooltip: '主题与声音',
              onPressed: onSettings,
              icon: const Icon(Icons.volume_up_outlined),
            ),
            IconButton(
              tooltip: '更多',
              onPressed: onMenu,
              icon: const Icon(Icons.more_horiz),
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}

class _PlayerPanel extends StatelessWidget {
  const _PlayerPanel({
    required this.side,
    required this.state,
    this.compact = false,
  });

  final PlaySide side;
  final ChessState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeBloc>().state.theme;
    final active =
        state.board.innerBoard.sdPlayer == side.index &&
        state.phase != GamePhase.finished &&
        state.phase != GamePhase.paused &&
        state.phase != GamePhase.failure;
    final isPlayer =
        state.playMode == PlayMode.withSelf || side == state.playSide;
    final thinking = state.phase == GamePhase.aiThinking && !isPlayer;
    final piece = ChessPiece(side == PlaySide.red ? 8 : 16);
    return _GlassSurface(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: compact ? 9 : 14,
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: compact ? 46 : 58,
              child: FittedBox(child: theme.buildPiece(context, piece)),
            ),
            SizedBox(width: compact ? 10 : 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.playMode == PlayMode.withAI && !isPlayer
                        ? '电脑 · ${_aiStrengthLabel(state.aiStrength)}'
                        : side == PlaySide.red
                        ? '红方 · 我'
                        : '黑方 · 本地',
                    style:
                        (compact
                                ? Theme.of(context).textTheme.titleSmall
                                : Theme.of(context).textTheme.titleMedium)
                            ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active
                              ? _GameColors.jade
                              : _GameColors.inactive,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          thinking
                              ? '思考中'
                              : active
                              ? '轮到${isPlayer
                                    ? '你'
                                    : side == PlaySide.red
                                    ? '红方'
                                    : '黑方'}'
                              : '等待中',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: active
                                    ? _GameColors.jade
                                    : _GameColors.muted,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              _clockLabel(state, side),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                color:
                    state.timeControlSeconds > 0 &&
                        state.remainingSeconds(side) <= 60
                    ? const Color(0xFFB23B38)
                    : active
                    ? _GameColors.ink
                    : _GameColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopInspector extends StatelessWidget {
  const _DesktopInspector({
    required this.state,
    required this.tab,
    required this.onTabChanged,
    required this.onSettings,
    required this.onMenu,
  });

  final ChessState state;
  final int tab;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onSettings;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PlayerPanel(side: PlaySide.black, state: state),
        const SizedBox(height: 12),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: 0,
              icon: Icon(Icons.list_alt),
              label: Text('棋谱'),
            ),
            ButtonSegment(value: 1, icon: Icon(Icons.tune), label: Text('局面')),
          ],
          selected: {tab},
          onSelectionChanged: (selection) => onTabChanged(selection.first),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: tab == 0
              ? _MoveHistory(state: state, embedded: true)
              : _PositionSummary(state: state),
        ),
        const SizedBox(height: 12),
        _PlayerPanel(side: PlaySide.red, state: state),
        const SizedBox(height: 10),
        _GameCommandBar(
          state: state,
          onNotation: () => onTabChanged(0),
          onMenu: onMenu,
          desktop: true,
        ),
      ],
    );
  }
}

class _MoveHistory extends StatelessWidget {
  const _MoveHistory({required this.state, this.embedded = false});

  final ChessState state;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final moves = state.board.lastMoves;
    final content = moves.isEmpty
        ? const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.list_alt, size: 34, color: _GameColors.muted),
                SizedBox(height: 10),
                Text('棋谱将在落子后显示'),
              ],
            ),
          )
        : ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: (moves.length + 1) ~/ 2,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final redIndex = index * 2;
              final blackIndex = redIndex + 1;
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    SizedBox(width: 32, child: Text('${index + 1}')),
                    Expanded(child: Text(_moveLabel(moves[redIndex]))),
                    Expanded(
                      child: Text(
                        blackIndex < moves.length
                            ? _moveLabel(moves[blackIndex])
                            : '…',
                      ),
                    ),
                  ],
                ),
              );
            },
          );
    if (embedded) return content;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('本局棋谱', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Expanded(child: content),
        ],
      ),
    );
  }
}

class _PositionSummary extends StatelessWidget {
  const _PositionSummary({required this.state});

  final ChessState state;

  @override
  Widget build(BuildContext context) {
    final turn = state.board.innerBoard.sdPlayer == PlaySide.red.index
        ? '红方'
        : '黑方';
    final status = _gamePhaseLabel(state.phase);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 6),
          leading: const Icon(Icons.adjust),
          title: const Text('当前回合'),
          trailing: Text(turn),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 6),
          leading: const Icon(Icons.info_outline),
          title: const Text('对局状态'),
          trailing: Text(status),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 6),
          leading: const Icon(Icons.save_outlined),
          title: const Text('本地存档'),
          trailing: Text(_persistenceLabel(state.persistenceStatus)),
        ),
      ],
    );
  }
}

class _GameCommandBar extends StatelessWidget {
  const _GameCommandBar({
    required this.state,
    required this.onNotation,
    required this.onMenu,
    this.desktop = false,
  });

  final ChessState state;
  final VoidCallback onNotation;
  final VoidCallback onMenu;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ChessBloc>();
    final commands = <_GameCommand>[
      _GameCommand(
        label: '悔棋',
        icon: Icons.undo,
        onPressed: state.canUndo
            ? () => bloc.add(const ChessEventUndo())
            : null,
      ),
      if (state.playMode == PlayMode.withAI)
        _GameCommand(
          label: '提示',
          icon: Icons.lightbulb_outline,
          active: state.hintMoves.isNotEmpty,
          onPressed: state.canHint
              ? () => bloc.add(const ChessEventGetHint())
              : null,
        )
      else
        _GameCommand(
          label: '翻转',
          icon: Icons.flip_camera_android_outlined,
          onPressed: state.canFlip
              ? () => bloc.add(const ChessEventFlipBoard())
              : null,
        ),
      _GameCommand(label: '棋谱', icon: Icons.list_alt, onPressed: onNotation),
      _GameCommand(label: '菜单', icon: Icons.menu, onPressed: onMenu),
    ];
    return _GlassSurface(
      borderRadius: desktop
          ? const BorderRadius.all(Radius.circular(8))
          : const BorderRadius.vertical(top: Radius.circular(8)),
      child: SizedBox(
        height: desktop ? 68 : 72,
        child: Row(
          children: commands
              .map(
                (command) => Expanded(child: _CommandButton(command: command)),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _GameCommand {
  const _GameCommand({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.active = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool active;
}

class _CommandButton extends StatelessWidget {
  const _CommandButton({required this.command});

  final _GameCommand command;

  @override
  Widget build(BuildContext context) {
    final color = command.onPressed == null
        ? _GameColors.inactive
        : command.active
        ? _GameColors.jade
        : _GameColors.ink;
    return Tooltip(
      message: command.label,
      child: InkWell(
        onTap: command.onPressed,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(command.icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              command.label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({required this.onResume});

  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: .58),
        child: Center(
          child: _GlassSurface(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.pause_circle_outline, size: 44),
                  const SizedBox(height: 12),
                  Text('对局已暂停', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: onResume,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('继续对局'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EffectLabel extends StatelessWidget {
  const _EffectLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _GameColors.ink.withValues(alpha: .82),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _FailureOverlay extends StatelessWidget {
  const _FailureOverlay({
    required this.message,
    required this.canRetry,
    required this.onRetry,
    required this.onSwitchToLocal,
  });

  final String message;
  final bool canRetry;
  final VoidCallback onRetry;
  final VoidCallback onSwitchToLocal;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: .58),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: _GlassSurface(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 42),
                    const SizedBox(height: 12),
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    if (canRetry)
                      FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('重试思考'),
                      ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: onSwitchToLocal,
                      icon: const Icon(Icons.people_outline),
                      label: const Text('切换本地双人'),
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

class _GlassSurface extends StatelessWidget {
  const _GlassSurface({
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  final Widget child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _GameColors.surface.withValues(alpha: .88),
            borderRadius: borderRadius,
            border: Border.all(color: _GameColors.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _DesktopBackdrop extends StatelessWidget {
  const _DesktopBackdrop();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: _GameColors.mobileCanvas);
  }
}

class ChessBoard extends StatefulWidget {
  const ChessBoard({super.key});

  @override
  State<ChessBoard> createState() => _ChessBoardState();
}

class _ChessBoardState extends State<ChessBoard> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'chess-board');
  PiecePos _keyboardPosition = PiecePos(SquareBoard.coordXYFix(4, 9));
  bool _showKeyboardFocus = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(KeyEvent event, ChessState state) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      context.read<ChessBloc>().add(const ChessEventClearSelection());
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      setState(() => _showKeyboardFocus = true);
      if (state.canInteractBoard) {
        context.read<ChessBloc>().add(ChessEventBoardTap(_keyboardPosition));
      }
      return KeyEventResult.handled;
    }
    var dx = 0;
    var dy = 0;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) dx = -1;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) dx = 1;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) dy = -1;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) dy = 1;
    if (dx == 0 && dy == 0) return KeyEventResult.ignored;
    if (state.boardFlipped) {
      dx = -dx;
      dy = -dy;
    }
    final x =
        (SquareBoard.getFileX(_keyboardPosition.sq) -
                SquareBoard.FILE_LEFT +
                dx)
            .clamp(0, 8);
    final y =
        (SquareBoard.getRankY(_keyboardPosition.sq) - SquareBoard.RANK_TOP + dy)
            .clamp(0, 9);
    setState(() {
      _keyboardPosition = PiecePos(SquareBoard.coordXYFix(x, y));
      _showKeyboardFocus = true;
    });
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.select((ThemeBloc bloc) => bloc.state.theme);
    final state = context.select((ChessBloc bloc) => bloc.state);
    final effect = state.activePresentation;
    final animating = effect?.stage == PresentationStage.animating;
    final board = animating ? effect!.beforeBoard : state.board;
    final locked = !state.canInteractBoard;
    final flipped = state.boardFlipped;
    final movingFrom = effect?.kind == PresentationEffectKind.undo
        ? effect?.move.dstPos
        : effect?.move.srcPos;
    final movingTo = effect?.kind == PresentationEffectKind.undo
        ? effect?.move.srcPos
        : effect?.move.dstPos;

    return Semantics(
      label: '中国象棋棋盘，方向${flipped ? '黑方在下' : '红方在下'}',
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: (_, event) => _handleKey(event, state),
        child: Center(
          child: AspectRatio(
            aspectRatio: theme.boardSize.width / theme.boardSize.height,
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                height: theme.boardSize.height,
                width: theme.boardSize.width,
                child: Stack(
                  children: [
                    theme.buildBoard(context),
                    Padding(
                      padding: theme.boardPadding,
                      child: IgnorePointer(
                        ignoring: locked,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (_) {
                            _focusNode.requestFocus();
                            if (_showKeyboardFocus) {
                              setState(() => _showKeyboardFocus = false);
                            }
                          },
                          onTapUp: (tap) {
                            final contentSize = Size(
                              theme.boardSize.width -
                                  theme.boardPadding.horizontal,
                              theme.boardSize.height -
                                  theme.boardPadding.vertical,
                            );
                            final offset = flipped
                                ? Offset(
                                    contentSize.width - tap.localPosition.dx,
                                    contentSize.height - tap.localPosition.dy,
                                  )
                                : tap.localPosition;
                            final position = theme.hitTest(offset);
                            if (position != null) {
                              setState(() => _keyboardPosition = position);
                              context.read<ChessBloc>().add(
                                ChessEventBoardTap(position),
                              );
                            }
                          },
                          child: Stack(
                            children: [
                              if (state.lastMove != null) ...[
                                Align(
                                  alignment: theme.getAlignment(
                                    _viewPosition(
                                      state.lastMove!.srcPos,
                                      flipped,
                                    ),
                                  ),
                                  child: theme.buildMovePrint(context, true),
                                ),
                                Align(
                                  alignment: theme.getAlignment(
                                    _viewPosition(
                                      state.lastMove!.dstPos,
                                      flipped,
                                    ),
                                  ),
                                  child: theme.buildMovePrint(context, false),
                                ),
                              ],
                              if (state.hintMoves.isNotEmpty) ...[
                                Align(
                                  alignment: theme.getAlignment(
                                    _viewPosition(
                                      state.hintMoves.first.srcPos,
                                      flipped,
                                    ),
                                  ),
                                  child: theme.buildMovePrint(context, true),
                                ),
                                Align(
                                  alignment: theme.getAlignment(
                                    _viewPosition(
                                      state.hintMoves.first.dstPos,
                                      flipped,
                                    ),
                                  ),
                                  child: theme.buildPieceMask(context),
                                ),
                              ],
                              if (animating &&
                                  effect!.kind !=
                                      PresentationEffectKind.invalidMove)
                                Align(
                                  alignment: theme.getAlignment(
                                    _viewPosition(movingFrom!, flipped),
                                  ),
                                  child: theme.buildMovePrint(context, true),
                                ),
                              ...board.pcPairs.map((pair) {
                                if (animating && movingFrom?.sq == pair.sq) {
                                  return const SizedBox.shrink();
                                }
                                return Align(
                                  alignment: theme.getAlignment(
                                    _viewPosition(pair.pos, flipped),
                                  ),
                                  child: Semantics(
                                    button: true,
                                    label: _pieceSemantic(pair.piece, pair.pos),
                                    child:
                                        effect?.kind ==
                                                PresentationEffectKind.move &&
                                            effect?.capturedPiece != null &&
                                            effect?.move.sqDst == pair.sq &&
                                            animating
                                        ? AnimatedCapturedPiece(
                                            key: ValueKey(
                                              'captured-${effect!.id}',
                                            ),
                                            child: theme.buildPiece(
                                              context,
                                              pair.piece,
                                            ),
                                          )
                                        : state.selected?.sq == pair.sq &&
                                              !animating
                                        ? theme.buildSelectedPiece(
                                            context,
                                            pair.piece,
                                          )
                                        : theme.buildPiece(context, pair.piece),
                                  ),
                                );
                              }),
                              if (!animating)
                                ...state.selectedMoves.map(
                                  (move) => Align(
                                    alignment: theme.getAlignment(
                                      _viewPosition(move.dstPos, flipped),
                                    ),
                                    child: theme.buildPieceMask(context),
                                  ),
                                ),
                              if (_showKeyboardFocus &&
                                  _focusNode.hasFocus &&
                                  state.canInteractBoard &&
                                  state.selected?.sq != _keyboardPosition.sq)
                                Align(
                                  alignment: theme.getAlignment(
                                    _viewPosition(_keyboardPosition, flipped),
                                  ),
                                  child: IgnorePointer(
                                    child: BoardCornerMarker(
                                      key: const ValueKey(
                                        'board-keyboard-focus',
                                      ),
                                      dimension: theme.pieceSize,
                                    ),
                                  ),
                                ),
                              if (animating &&
                                  effect?.kind ==
                                      PresentationEffectKind.invalidMove &&
                                  effect?.movingPiece != null)
                                AnimatedInvalidMove(
                                  key: ValueKey('invalid-${effect!.id}'),
                                  begin: theme.getAlignment(
                                    _viewPosition(effect.move.srcPos, flipped),
                                  ),
                                  end: theme.getAlignment(
                                    _viewPosition(effect.move.dstPos, flipped),
                                  ),
                                  child: theme.buildPiece(
                                    context,
                                    effect.movingPiece!,
                                  ),
                                  onEnd: () => context.read<ChessBloc>().add(
                                    ChessEventPresentationAnimationCompleted(
                                      effect.id,
                                    ),
                                  ),
                                ),
                              if (animating &&
                                  effect!.kind !=
                                      PresentationEffectKind.invalidMove &&
                                  effect.movingPiece != null)
                                AnimatedMove(
                                  key: ValueKey('move-${effect.id}'),
                                  begin: theme.getAlignment(
                                    _viewPosition(movingFrom!, flipped),
                                  ),
                                  end: theme.getAlignment(
                                    _viewPosition(movingTo!, flipped),
                                  ),
                                  child: theme.buildPiece(
                                    context,
                                    effect.movingPiece!,
                                  ),
                                  duration: _moveDuration(effect.move),
                                  onEnd: () => context.read<ChessBloc>().add(
                                    ChessEventPresentationAnimationCompleted(
                                      effect.id,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
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

PiecePos _viewPosition(PiecePos position, bool flipped) =>
    flipped ? PiecePos(SquareBoard.getSquareFlip(position.sq)) : position;

Duration _moveDuration(MovePos move) {
  final dx =
      (SquareBoard.getFileX(move.sqDst) - SquareBoard.getFileX(move.sqSrc))
          .abs();
  final dy =
      (SquareBoard.getRankY(move.sqDst) - SquareBoard.getRankY(move.sqSrc))
          .abs();
  final distance = dx > dy ? dx : dy;
  return Duration(milliseconds: (180 + distance * 20).clamp(180, 300));
}

String _modeTitle(PlayMode mode) {
  return mode == PlayMode.withSelf ? '本地双人' : '人机对局';
}

String _aiStrengthLabel(AiStrength strength) => switch (strength) {
  AiStrength.easy => '入门',
  AiStrength.normal => '普通',
  AiStrength.hard => '较强',
};

String _clockLabel(ChessState state, PlaySide side) {
  if (state.timeControlSeconds == 0) return '不限时';
  final remaining = state.remainingSeconds(side);
  final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
  final seconds = (remaining % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _playEffectLabel(PlayEffect effect) {
  switch (effect) {
    case PlayEffect.check:
      return '将军';
    case PlayEffect.eat:
      return '吃子';
    case PlayEffect.mate:
      return '绝杀';
  }
}

String _gamePhaseLabel(GamePhase phase) {
  switch (phase) {
    case GamePhase.aiThinking:
      return '电脑思考中';
    case GamePhase.paused:
      return '已暂停';
    case GamePhase.finished:
      return '棋局结束';
    case GamePhase.loading:
      return '正在准备';
    case GamePhase.failure:
      return '需要处理';
    case GamePhase.playerTurn:
      return '等待落子';
  }
}

String _persistenceLabel(PersistenceStatus status) {
  switch (status) {
    case PersistenceStatus.idle:
      return '本地';
    case PersistenceStatus.saving:
      return '保存中';
    case PersistenceStatus.saved:
      return '已保存';
    case PersistenceStatus.failed:
      return '保存失败';
  }
}

String _pieceSemantic(ChessPiece piece, PiecePos position) {
  const names = ['将', '士', '象', '马', '车', '炮', '兵'];
  final side = piece.isRedSide() ? '红方' : '黑方';
  final file = SquareBoard.getFileX(position.sq) - SquareBoard.FILE_LEFT + 1;
  final rank = SquareBoard.getRankY(position.sq) - SquareBoard.RANK_TOP + 1;
  return '$side${names[piece.numTag]}，第$file路，第$rank线';
}

String _moveLabel(MovePos move) {
  final srcFile = SquareBoard.getFileX(move.sqSrc) - SquareBoard.FILE_LEFT + 1;
  final srcRank = SquareBoard.getRankY(move.sqSrc) - SquareBoard.RANK_TOP + 1;
  final dstFile = SquareBoard.getFileX(move.sqDst) - SquareBoard.FILE_LEFT + 1;
  final dstRank = SquareBoard.getRankY(move.sqDst) - SquareBoard.RANK_TOP + 1;
  return '$srcFile,$srcRank → $dstFile,$dstRank';
}

class _GameColors {
  const _GameColors._();

  static const mobileCanvas = Color(0xFFF0F2F1);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0x33717F7B);
  static const ink = Color(0xFF202625);
  static const muted = Color(0xFF68716E);
  static const inactive = Color(0xFF9EA5A2);
  static const jade = Color(0xFF2D9B73);
}
