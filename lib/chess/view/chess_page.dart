import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cchess/audio/audio.dart';
import 'package:flutter_cchess/chess/game/game_board.dart';
import 'package:flutter_cchess/chess/game/ai_strength.dart';
import 'package:flutter_cchess/chess/game/opening_book.dart';
import 'package:flutter_cchess/chess/notation/chinese_notation.dart';
import 'package:flutter_cchess/chess/theme/board_corner_marker.dart';
import 'package:flutter_cchess/chess/presentation/game_presentation_coordinator.dart';
import 'package:flutter_cchess/chess/widget/animated_invalid_move.dart';
import 'package:flutter_cchess/chess/widget/animated_move.dart';
import 'package:flutter_cchess/chess/widget/animated_overlay.dart';
import 'package:flutter_cchess/models/board.dart';
import 'package:flutter_cchess/models/piece.dart';
import 'package:flutter_cchess/settings/settings.dart';
import 'package:flutter_cchess/storage/storage.dart';
import 'package:flutter_cchess/theme/bloc/theme_bloc.dart';
import 'package:flutter_cchess/theme/themes/board_theme.dart';
import 'package:flutter_cchess/timer/ticker.dart';
import 'package:flutter_cchess/utils/utils.dart';

import '../bloc/chess_bloc.dart';
import 'chess_analysis_page.dart';
import 'game_layout_policy.dart';

class ChessPage extends StatefulWidget {
  const ChessPage({
    super.key,
    this.playMode = PlayMode.withAI,
    this.initialRecord,
    this.timeControlSeconds = 900,
    this.aiStrength = AiStrength.normal,
    this.redAiStrength = AiStrength.normal,
    this.blackAiStrength = AiStrength.normal,
    this.aiMaxDepth,
    this.aiMaxThinkMs,
    this.redAiMaxDepth,
    this.blackAiMaxDepth,
    this.aiVsAiStepDelayMs = 0,
  });

  final PlayMode playMode;
  final GameRecord? initialRecord;
  final int timeControlSeconds;
  final AiStrength aiStrength;
  final AiStrength redAiStrength;
  final AiStrength blackAiStrength;
  final int? aiMaxDepth;
  final int? aiMaxThinkMs;
  final int? redAiMaxDepth;
  final int? blackAiMaxDepth;
  final int aiVsAiStepDelayMs;

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
    final openingBookLines = OpeningBook.fromRecords(
      await gameRepository.list(),
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
      openingBookLines: openingBookLines,
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
                      redAiStrength:
                          widget.initialRecord?.redAiStrength ??
                          widget.redAiStrength,
                      blackAiStrength:
                          widget.initialRecord?.blackAiStrength ??
                          widget.blackAiStrength,
                      aiMaxDepth:
                          widget.initialRecord?.aiMaxDepth ??
                          widget.aiMaxDepth ??
                          (widget.aiStrength == bootstrap.settings.aiStrength
                              ? bootstrap.settings.aiMaxDepth
                              : widget.aiStrength.maxDepth),
                      aiMaxThinkMs:
                          widget.initialRecord?.aiMaxThinkMs ??
                          widget.aiMaxThinkMs ??
                          (widget.aiStrength == bootstrap.settings.aiStrength
                              ? bootstrap.settings.aiMaxThinkMs
                              : widget.aiStrength.maxThinkMs),
                      redAiMaxDepth:
                          widget.initialRecord?.redAiMaxDepth ??
                          widget.redAiMaxDepth,
                      blackAiMaxDepth:
                          widget.initialRecord?.blackAiMaxDepth ??
                          widget.blackAiMaxDepth,
                      aiVsAiStepDelayMs:
                          widget.initialRecord?.aiVsAiStepDelayMs ??
                          widget.aiVsAiStepDelayMs,
                      openingBookLines: bootstrap.openingBookLines,
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
    required this.openingBookLines,
  });

  final GameRepository gameRepository;
  final GameSettingsRepository settingsRepository;
  final GameSettings settings;
  final Board initialBoard;
  final String initialFen;
  final List<List<int>> openingBookLines;
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
  var _allowPagePop = false;

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
    final aiSettingsChanged =
        settings.aiStrength != _settings.aiStrength ||
        settings.aiMaxDepth != _settings.aiMaxDepth ||
        settings.aiMaxThinkMs != _settings.aiMaxThinkMs;
    setState(() => _settings = settings);
    if (soundChanged) {
      await _audioService.setEnabled(settings.soundEnabled);
    }
    await widget.settingsRepository.save(settings);
    if (aiSettingsChanged) {
      context.read<ChessBloc>().add(
        ChessEventAiSettingsChanged(
          aiStrength: settings.aiStrength,
          aiMaxDepth: settings.aiMaxDepth,
          aiMaxThinkMs: settings.aiMaxThinkMs,
        ),
      );
    }
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
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: SizedBox(
          width: 520,
          child: SingleChildScrollView(
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
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final homeButton = OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        unawaited(_requestExit());
                      },
                      icon: const Icon(Icons.home_outlined),
                      label: const Text('返回首页'),
                    );
                    final replayButton = FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChessPage(
                              playMode: state.playMode,
                              timeControlSeconds: state.timeControlSeconds,
                              aiStrength: state.aiStrength,
                              redAiStrength: state.redAiStrength,
                              blackAiStrength: state.blackAiStrength,
                              redAiMaxDepth: state.redAiMaxDepth,
                              blackAiMaxDepth: state.blackAiMaxDepth,
                              aiVsAiStepDelayMs: state.aiVsAiStepDelayMs,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('再来一局'),
                    );
                    if (constraints.maxWidth < 400) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          homeButton,
                          const SizedBox(height: 12),
                          replayButton,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: homeButton),
                        const SizedBox(width: 12),
                        Expanded(child: replayButton),
                      ],
                    );
                  },
                ),
              ],
            ),
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
      await _popPage();
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
      if (mounted) await _popPage();
    }
  }

  Future<void> _popPage() async {
    if (!mounted) return;
    setState(() => _allowPagePop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
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
          redAiStrength: state.redAiStrength,
          blackAiStrength: state.blackAiStrength,
          redAiMaxDepth: state.redAiMaxDepth,
          blackAiMaxDepth: state.blackAiMaxDepth,
          aiVsAiStepDelayMs: state.aiVsAiStepDelayMs,
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
            final boardTheme = context.select(
              (ThemeBloc bloc) => bloc.state.theme,
            );
            return PopScope(
              canPop: _allowPagePop,
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
                          child: _GameBackdrop(
                            theme: boardTheme,
                            desktop: desktop,
                          ),
                        ),
                        SafeArea(
                          child: desktop
                              ? _DesktopGameLayout(
                                  state: state,
                                  inspectorTab: _inspectorTab,
                                  onEvaluate: () => context
                                      .read<ChessBloc>()
                                      .add(const ChessEventEvaluatePosition()),
                                  onInspectorTabChanged: (value) {
                                    setState(() => _inspectorTab = value);
                                  },
                                  onBack: _requestExit,
                                  onSettings: _showSettings,
                                  onMenu: _showGameMenu,
                                  onAnalysis: _openAnalysis,
                                )
                              : _MobileGameLayout(
                                  state: state,
                                  onBack: _requestExit,
                                  onSettings: _showSettings,
                                  onMenu: _showGameMenu,
                                  onEvaluate: () => context
                                      .read<ChessBloc>()
                                      .add(const ChessEventEvaluatePosition()),
                                  onNotation: _showNotation,
                                  onAnalysis: _openAnalysis,
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

  Future<void> _openAnalysis() async {
    final bloc = context.read<ChessBloc>();
    final source = bloc.state;
    if (!_canAnalyze(source)) return;
    final origin = source.board.copyWith();
    final themeBloc = context.read<ThemeBloc>();
    var pausedByAnalysis = false;
    if (source.canPause) {
      final pauseResult = bloc.stream.firstWhere(
        (state) =>
            state.phase == GamePhase.paused ||
            state.phase == GamePhase.finished,
      );
      bloc.add(const ChessEventPause());
      final pausedState = await pauseResult.timeout(
        const Duration(seconds: 2),
        onTimeout: () => bloc.state,
      );
      pausedByAnalysis = pausedState.phase == GamePhase.paused;
    }
    if (!mounted) return;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => BlocProvider.value(
            value: themeBloc,
            child: ChessAnalysisPage(
              origin: origin,
              initialFen: bloc.initialFen,
            ),
          ),
        ),
      );
    } finally {
      if (mounted && pausedByAnalysis && bloc.state.canResume) {
        bloc.add(const ChessEventResume());
      }
    }
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
                leading: const Icon(Icons.settings_outlined),
                title: const Text('设置'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showSettings();
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_tree_outlined),
                title: const Text('棋局拆解'),
                enabled: _canAnalyze(state),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openAnalysis();
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
              if (state.playMode != PlayMode.withAIvsAI)
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
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
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
    final themeBloc = context.read<ThemeBloc>();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: themeBloc,
          child: GameSettingsPage(
            initialSettings: _settings,
            onSettingsChanged: _saveSettings,
          ),
        ),
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
    required this.onEvaluate,
    required this.onNotation,
    required this.onAnalysis,
  });

  final ChessState state;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final VoidCallback onMenu;
  final VoidCallback onEvaluate;
  final VoidCallback onNotation;
  final VoidCallback onAnalysis;

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
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 5, 18, 0),
          child: _MobilePositionEvaluation(state: state),
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
        _GameCommandBar(
          state: state,
          onNotation: onNotation,
          onMenu: onMenu,
          onEvaluate: onEvaluate,
          onAnalysis: onAnalysis,
        ),
      ],
    );
  }
}

class _DesktopGameLayout extends StatelessWidget {
  const _DesktopGameLayout({
    required this.state,
    required this.inspectorTab,
    required this.onEvaluate,
    required this.onInspectorTabChanged,
    required this.onBack,
    required this.onSettings,
    required this.onMenu,
    required this.onAnalysis,
  });

  final ChessState state;
  final int inspectorTab;
  final VoidCallback onEvaluate;
  final ValueChanged<int> onInspectorTabChanged;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final VoidCallback onMenu;
  final VoidCallback onAnalysis;

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
                          onEvaluate: onEvaluate,
                          onTabChanged: onInspectorTabChanged,
                          onSettings: onSettings,
                          onMenu: onMenu,
                          onAnalysis: onAnalysis,
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
              tooltip: '设置',
              onPressed: onSettings,
              icon: const Icon(Icons.settings_outlined),
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
        state.playMode == PlayMode.withSelf ||
        (state.playMode != PlayMode.withAIvsAI && side == state.playSide);
    final computer =
        state.playMode == PlayMode.withAIvsAI ||
        (state.playMode == PlayMode.withAI && !isPlayer);
    final thinking =
        state.phase == GamePhase.aiThinking &&
        state.board.innerBoard.sdPlayer == side.index;
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
                    computer
                        ? '电脑 · ${_aiStrengthLabel(state, side)}'
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
    required this.onEvaluate,
    required this.onTabChanged,
    required this.onSettings,
    required this.onMenu,
    required this.onAnalysis,
  });

  final ChessState state;
  final int tab;
  final VoidCallback onEvaluate;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onSettings;
  final VoidCallback onMenu;
  final VoidCallback onAnalysis;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PlayerPanel(side: PlaySide.black, state: state),
        const SizedBox(height: 12),
        Expanded(
          child: _GlassSurface(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        icon: Icon(Icons.list_alt),
                        label: Text('棋谱'),
                      ),
                      ButtonSegment(
                        value: 1,
                        icon: Icon(Icons.tune),
                        label: Text('局面'),
                      ),
                    ],
                    selected: {tab},
                    onSelectionChanged: (selection) =>
                        onTabChanged(selection.first),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: tab == 0
                        ? _MoveHistory(state: state, embedded: true)
                        : _PositionSummary(
                            state: state,
                            onEvaluate: onEvaluate,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _PlayerPanel(side: PlaySide.red, state: state),
        const SizedBox(height: 10),
        _GameCommandBar(
          state: state,
          onNotation: () => onTabChanged(0),
          onMenu: onMenu,
          onEvaluate: onEvaluate,
          onAnalysis: onAnalysis,
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
    final moves = ChineseChessNotation.formatHistory(state.board);
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
            padding: const EdgeInsets.symmetric(vertical: 5),
            itemCount: (moves.length + 1) ~/ 2,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final firstIndex = index * 2;
              final first = moves[firstIndex];
              final second = firstIndex + 1 < moves.length
                  ? moves[firstIndex + 1]
                  : null;
              final redMove = first.isRed
                  ? first
                  : second?.isRed == true
                  ? second
                  : null;
              final blackMove = first.isRed ? second : first;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: Row(
                  children: [
                    SizedBox(
                      width: 58,
                      child: Text(
                        '第${index + 1}回合',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _GameColors.muted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _MoveNotationCell(
                        move: redMove,
                        latest:
                            firstIndex + (first.isRed ? 0 : 1) ==
                            moves.length - 1,
                        red: true,
                      ),
                    ),
                    Expanded(
                      child: _MoveNotationCell(
                        move: blackMove,
                        latest:
                            firstIndex + (first.isRed ? 1 : 0) ==
                            moves.length - 1,
                        red: false,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
    if (moves.isEmpty) {
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
    final moveHeader = Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text('回合', style: Theme.of(context).textTheme.labelSmall),
          ),
          Expanded(
            child: Center(
              child: Text(
                '红方',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFFB23B38),
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                '黑方',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: _GameColors.ink),
              ),
            ),
          ),
        ],
      ),
    );
    if (embedded) {
      return Column(
        children: [
          moveHeader,
          Expanded(child: content),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('本局棋谱', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          moveHeader,
          Expanded(child: content),
        ],
      ),
    );
  }
}

class _MoveNotationCell extends StatelessWidget {
  const _MoveNotationCell({
    required this.move,
    required this.latest,
    required this.red,
  });

  final ChineseNotationMove? move;
  final bool latest;
  final bool red;

  @override
  Widget build(BuildContext context) {
    if (move == null) return const Center(child: Text('—'));
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      decoration: BoxDecoration(
        color: latest ? const Color(0x182D9B73) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        move!.text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: red ? const Color(0xFF9D3835) : _GameColors.ink,
          fontWeight: latest ? FontWeight.w700 : FontWeight.w500,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _PositionSummary extends StatelessWidget {
  const _PositionSummary({required this.state, required this.onEvaluate});

  final ChessState state;
  final VoidCallback onEvaluate;

  @override
  Widget build(BuildContext context) {
    final turn = state.board.innerBoard.sdPlayer == PlaySide.red.index
        ? '红方'
        : '黑方';
    final status = _gamePhaseLabel(state.phase);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
          child: _DesktopPositionEvaluation(
            state: state,
            onEvaluate: onEvaluate,
          ),
        ),
        const Divider(height: 1),
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

class _MobilePositionEvaluation extends StatelessWidget {
  const _MobilePositionEvaluation({required this.state});

  final ChessState state;

  @override
  Widget build(BuildContext context) {
    final score =
        state.aiEvaluationForRed ?? state.board.staticEvaluationForRed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              _evaluationLabel(state),
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: _GameColors.muted),
            ),
            const Spacer(),
            Text(
              '${_positionScoreLabel(score)} 分',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: score == 0 ? _GameColors.ink : _scoreColor(score),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _PositionAdvantageMeter(score: score, compact: true),
      ],
    );
  }
}

class _DesktopPositionEvaluation extends StatelessWidget {
  const _DesktopPositionEvaluation({
    required this.state,
    required this.onEvaluate,
  });

  final ChessState state;
  final VoidCallback onEvaluate;

  @override
  Widget build(BuildContext context) {
    final score =
        state.aiEvaluationForRed ?? state.board.staticEvaluationForRed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.analytics_outlined, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _evaluationLabel(state),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${_positionScoreLabel(score)} 分',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: score == 0 ? _GameColors.ink : _scoreColor(score),
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: state.isEvaluating ? '正在评分' : 'AI评分',
              visualDensity: VisualDensity.compact,
              onPressed: state.canEvaluate ? onEvaluate : null,
              icon: state.isEvaluating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.analytics_outlined, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 11),
        _PositionAdvantageMeter(score: score),
        const SizedBox(height: 5),
        Row(
          children: [
            Text(
              '黑方优势',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: _GameColors.muted),
            ),
            const Spacer(),
            Text(
              '均势',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: _GameColors.muted),
            ),
            const Spacer(),
            Text(
              '红方优势',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: _GameColors.muted),
            ),
          ],
        ),
      ],
    );
  }
}

class _PositionAdvantageMeter extends StatelessWidget {
  const _PositionAdvantageMeter({required this.score, this.compact = false});

  final int score;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final offset = (score.clamp(-400, 400) / 800) * width;
        final markerLeft = (width / 2 + offset - 5)
            .clamp(0.0, width - 10)
            .toDouble();
        return SizedBox(
          height: compact ? 8 : 10,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: compact ? 2 : 3,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: _GameColors.inactive.withValues(alpha: .28),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Positioned(
                left: width / 2 - .5,
                top: 1,
                bottom: 1,
                child: Container(width: 1, color: _GameColors.muted),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: markerLeft,
                top: compact ? 0 : 1,
                child: Container(
                  width: 10,
                  height: 8,
                  decoration: BoxDecoration(
                    color: score == 0 ? _GameColors.jade : _scoreColor(score),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _positionScoreLabel(int score) => score > 0 ? '+$score' : '$score';

String _evaluationLabel(ChessState state) {
  if (state.isEvaluating) return 'AI 评分中';
  if (state.evaluationFailed) return '评分失败，可重试';
  final depth = state.aiEvaluationDepth;
  if (depth != null && depth > 0) return 'AI 评分 · $depth 层';
  if (state.aiEvaluationForRed != null) return 'AI 评估 · 快速结果';
  return '快速估值（红方视角）';
}

Color _scoreColor(int score) =>
    score > 0 ? const Color(0xFF9D3835) : const Color(0xFF303B3D);

class _GameCommandBar extends StatelessWidget {
  const _GameCommandBar({
    required this.state,
    required this.onNotation,
    required this.onMenu,
    required this.onEvaluate,
    required this.onAnalysis,
    this.desktop = false,
  });

  final ChessState state;
  final VoidCallback onNotation;
  final VoidCallback onMenu;
  final VoidCallback onEvaluate;
  final VoidCallback onAnalysis;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ChessBloc>();
    final hintPending =
        state.playMode == PlayMode.withAI &&
        state.phase == GamePhase.aiThinking &&
        state.board.isTurn(state.playSide);
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
          label: hintPending ? '计算中' : '提示',
          icon: hintPending
              ? Icons.hourglass_top_rounded
              : Icons.lightbulb_outline,
          active: hintPending || state.hintMoves.isNotEmpty,
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
      _GameCommand(
        label: '拆解',
        icon: Icons.account_tree_outlined,
        onPressed: _canAnalyze(state) ? onAnalysis : null,
      ),
      if (!desktop)
        _GameCommand(
          label: state.isEvaluating ? '评分中' : '评分',
          icon: state.isEvaluating
              ? Icons.hourglass_top_rounded
              : Icons.analytics_outlined,
          active: state.isEvaluating || state.aiEvaluationForRed != null,
          onPressed: state.canEvaluate ? onEvaluate : null,
        ),
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
    final color = command.active
        ? _GameColors.jade
        : command.onPressed == null
        ? _GameColors.inactive
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

class _GameBackdrop extends StatelessWidget {
  const _GameBackdrop({required this.theme, required this.desktop});

  final BoardTheme theme;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final asset = desktop
        ? theme.desktopBackgroundAsset
        : theme.mobileBackgroundAsset;
    if (asset == null) {
      return const ColoredBox(color: _GameColors.mobileCanvas);
    }
    return Image.asset(
      asset,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
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
                                        state.selected?.sq == pair.sq &&
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
                              if (state.hintMoves.isNotEmpty) ...[
                                Align(
                                  alignment: theme.getAlignment(
                                    _viewPosition(
                                      state.hintMoves.first.srcPos,
                                      flipped,
                                    ),
                                  ),
                                  child: _HintBoardMarker(
                                    dimension: theme.pieceSize,
                                    destination: false,
                                  ),
                                ),
                                Align(
                                  alignment: theme.getAlignment(
                                    _viewPosition(
                                      state.hintMoves.first.dstPos,
                                      flipped,
                                    ),
                                  ),
                                  child: _HintBoardMarker(
                                    dimension: theme.pieceSize,
                                    destination: true,
                                  ),
                                ),
                              ],
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
  return switch (mode) {
    PlayMode.withSelf => '本地双人',
    PlayMode.withAI => '人机对局',
    PlayMode.withAIvsAI => 'AI 对战',
    PlayMode.withNetwork => '联网对局',
  };
}

bool _canAnalyze(ChessState state) =>
    state.presentations.isEmpty &&
    (state.phase == GamePhase.playerTurn ||
        state.phase == GamePhase.aiThinking ||
        state.phase == GamePhase.paused ||
        state.phase == GamePhase.finished);

String _aiStrengthLabel(ChessState state, PlaySide side) {
  final strength = state.playMode == PlayMode.withAIvsAI
      ? side == PlaySide.red
            ? state.redAiStrength
            : state.blackAiStrength
      : state.aiStrength;
  if (state.playMode != PlayMode.withAIvsAI &&
      (state.aiMaxDepth != strength.maxDepth ||
          state.aiMaxThinkMs != strength.maxThinkMs)) {
    return '自定义';
  }
  return switch (strength) {
    AiStrength.easy => '入门',
    AiStrength.normal => '普通',
    AiStrength.hard => '较强',
  };
}

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

class _GameColors {
  const _GameColors._();

  static const mobileCanvas = Color(0xFFECE9E1);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0x33717F7B);
  static const ink = Color(0xFF202625);
  static const muted = Color(0xFF68716E);
  static const inactive = Color(0xFF9EA5A2);
  static const jade = Color(0xFF2D9B73);
  static const hint = Color(0xFFD29A43);
}

class _HintBoardMarker extends StatelessWidget {
  const _HintBoardMarker({required this.dimension, required this.destination});

  final double dimension;
  final bool destination;

  @override
  Widget build(BuildContext context) {
    final markerSize = dimension * (destination ? .62 : .94);
    return IgnorePointer(
      child: SizedBox.square(
        dimension: dimension,
        child: Center(
          child: Container(
            width: markerSize,
            height: markerSize,
            decoration: BoxDecoration(
              color: _GameColors.hint.withValues(alpha: destination ? .17 : .1),
              shape: BoxShape.circle,
              border: Border.all(color: _GameColors.hint, width: 2.5),
              boxShadow: const [
                BoxShadow(color: Color(0x332E2110), blurRadius: 5),
              ],
            ),
            child: destination
                ? Center(
                    child: Container(
                      width: dimension * .14,
                      height: dimension * .14,
                      decoration: const BoxDecoration(
                        color: _GameColors.hint,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
