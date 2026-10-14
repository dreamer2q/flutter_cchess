import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cchess/chess/game/ai_strength.dart';
import 'package:flutter_cchess/theme/bloc/theme_bloc.dart';
import 'package:flutter_cchess/theme/app_chrome.dart';

import 'game_settings.dart';

class GameSettingsPage extends StatefulWidget {
  const GameSettingsPage({
    super.key,
    required this.initialSettings,
    required this.onSettingsChanged,
  });

  final GameSettings initialSettings;
  final Future<void> Function(GameSettings settings) onSettingsChanged;

  @override
  State<GameSettingsPage> createState() => _GameSettingsPageState();
}

class _GameSettingsPageState extends State<GameSettingsPage> {
  late GameSettings _settings = widget.initialSettings;
  var _selectedSection = _SettingsSection.appearance;

  Future<void> _update(GameSettings next) async {
    final previous = _settings;
    setState(() => _settings = next);
    if (next.themeConfigAsset != previous.themeConfigAsset) {
      context.read<ThemeBloc>().add(ThemeAssetRequested(next.themeConfigAsset));
    }
    await widget.onSettingsChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.canvas,
      appBar: AppBar(
        leading: IconButton(
          tooltip: '返回对局',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text('设置'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: const AppBackdrop(
          child: AppGlassSurface(
            borderRadius: BorderRadius.zero,
            child: SizedBox.expand(),
          ),
        ),
      ),
      body: AppBackdrop(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 760) {
              return Row(
                children: [
                  SizedBox(
                    width: 232,
                    child: _SettingsSidebar(
                      selected: _selectedSection,
                      onSelected: (section) =>
                          setState(() => _selectedSection = section),
                    ),
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    child: _SettingsDetail(
                      section: _selectedSection,
                      settings: _settings,
                      onUpdate: _update,
                    ),
                  ),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
              children: [
                for (final section in _SettingsSection.values) ...[
                  _SettingsDetail(
                    section: section,
                    settings: _settings,
                    onUpdate: _update,
                    compact: true,
                  ),
                  if (section != _SettingsSection.values.last)
                    const SizedBox(height: 28),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _SettingsSection {
  appearance('棋盘外观', '更换棋盘主题与棋子风格', Icons.palette_outlined),
  ai('电脑对手', '调整电脑难度与思考方式', Icons.smart_toy_outlined),
  feedback('声音与触觉', '控制声音与设备反馈', Icons.volume_up_outlined),
  motion('动画与显示', '调整棋子动画与界面动效', Icons.motion_photos_on_outlined);

  const _SettingsSection(this.title, this.subtitle, this.icon);

  final String title;
  final String subtitle;
  final IconData icon;
}

class _SettingsSidebar extends StatelessWidget {
  const _SettingsSidebar({required this.selected, required this.onSelected});

  final _SettingsSection selected;
  final ValueChanged<_SettingsSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x44FFFFFF),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 12),
            child: Text(
              '偏好设置',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: const Color(0xFF68716E)),
            ),
          ),
          for (final section in _SettingsSection.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _SettingsNavigationItem(
                section: section,
                selected: section == selected,
                onTap: () => onSelected(section),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsNavigationItem extends StatelessWidget {
  const _SettingsNavigationItem({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final _SettingsSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? const Color(0xFF176B50)
        : const Color(0xFF3B4340);
    return Material(
      color: selected ? const Color(0x1F2D9B73) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11),
            child: Row(
              children: [
                Icon(section.icon, size: 19, color: foreground),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    section.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsDetail extends StatelessWidget {
  const _SettingsDetail({
    required this.section,
    required this.settings,
    required this.onUpdate,
    this.compact = false,
  });

  final _SettingsSection section;
  final GameSettings settings;
  final ValueChanged<GameSettings> onUpdate;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final detail = switch (section) {
      _SettingsSection.appearance => _appearance(context),
      _SettingsSection.ai => _ai(context),
      _SettingsSection.feedback => _feedback(context),
      _SettingsSection.motion => _motion(context),
    };
    final content = Column(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.stretch,
      children: [
        Text(section.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 5),
        Text(
          section.subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF68716E)),
        ),
        if (section == _SettingsSection.appearance)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '偏好会立即保存到本机。新对局的用时和电脑难度会在开始时选择。',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF68716E)),
            ),
          ),
        const SizedBox(height: 24),
        detail,
      ],
    );

    if (compact) return content;
    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(40, 28, 40, 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: content,
        ),
      ),
    );
  }

  Widget _appearance(BuildContext context) {
    return _SettingsGroup(
      title: '棋盘主题',
      children: [
        for (final choice in const [
          (
            GameSettings.defaultThemeConfigAsset,
            '经典木纹',
            '浅色棋盘，清晰易读',
            'assets/skins/woods/board.jpg',
          ),
          (
            'assets/skins/night/config.json',
            '夜间胡桃木',
            '深色棋盘，金色棋线',
            'assets/skins/night/board.png',
          ),
          (
            'assets/skins/qqclassic/config.json',
            '暖木经典',
            '暖色棋盘，传统棋子',
            'assets/skins/qqclassic/board.png',
          ),
        ])
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                choice.$4,
                width: 44,
                height: 50,
                fit: BoxFit.cover,
              ),
            ),
            title: Text(choice.$2),
            subtitle: Text(choice.$3),
            selected: settings.themeConfigAsset == choice.$1,
            selectedTileColor: const Color(0x10176B50),
            trailing: Icon(
              settings.themeConfigAsset == choice.$1
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              color: settings.themeConfigAsset == choice.$1
                  ? AppPalette.accent
                  : AppPalette.muted,
            ),
            onTap: () =>
                onUpdate(settings.copyWith(themeConfigAsset: choice.$1)),
          ),
      ],
    );
  }

  Widget _feedback(BuildContext context) {
    return _SettingsGroup(
      title: '对局反馈',
      children: [
        SwitchListTile.adaptive(
          title: const Text('对局音效'),
          subtitle: const Text('走子、吃子、将军与结果反馈'),
          value: settings.soundEnabled,
          onChanged: (value) =>
              onUpdate(settings.copyWith(soundEnabled: value)),
        ),
        const _SettingsDivider(),
        SwitchListTile.adaptive(
          title: const Text('触觉反馈'),
          subtitle: const Text('移动设备上的落子与非法操作反馈'),
          value: settings.hapticsEnabled,
          onChanged: (value) =>
              onUpdate(settings.copyWith(hapticsEnabled: value)),
        ),
      ],
    );
  }

  Widget _ai(BuildContext context) {
    return _SettingsGroup(
      title: '电脑怎么想',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SegmentedButton<AiStrength>(
            expandedInsets: EdgeInsets.zero,
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: AiStrength.easy, label: Text('入门')),
              ButtonSegment(value: AiStrength.normal, label: Text('普通')),
              ButtonSegment(value: AiStrength.hard, label: Text('较强')),
            ],
            selected: {settings.aiStrength},
            onSelectionChanged: (selection) {
              final strength = selection.first;
              onUpdate(
                settings.copyWith(
                  aiStrength: strength,
                  aiMaxDepth: strength.maxDepth,
                  aiMaxThinkMs: strength.maxThinkMs,
                ),
              );
            },
          ),
        ),
        const _SettingsDivider(),
        _AiSearchLimits(settings: settings, onUpdate: onUpdate),
      ],
    );
  }

  Widget _motion(BuildContext context) {
    return _SettingsGroup(
      title: '棋子与界面',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SegmentedButton<MotionPreference>(
            expandedInsets: EdgeInsets.zero,
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: MotionPreference.system,
                icon: Icon(Icons.settings_suggest_outlined),
                label: Text('跟随系统'),
              ),
              ButtonSegment(
                value: MotionPreference.full,
                icon: Icon(Icons.animation_outlined),
                label: Text('完整'),
              ),
              ButtonSegment(
                value: MotionPreference.reduced,
                icon: Icon(Icons.motion_photos_off_outlined),
                label: Text('精简'),
              ),
            ],
            selected: {settings.motionPreference},
            onSelectionChanged: (selection) =>
                onUpdate(settings.copyWith(motionPreference: selection.first)),
          ),
        ),
      ],
    );
  }
}

class _AiSearchLimits extends StatefulWidget {
  const _AiSearchLimits({required this.settings, required this.onUpdate});

  final GameSettings settings;
  final ValueChanged<GameSettings> onUpdate;

  @override
  State<_AiSearchLimits> createState() => _AiSearchLimitsState();
}

class _AiSearchLimitsState extends State<_AiSearchLimits> {
  late double _depth = widget.settings.aiMaxDepth.toDouble();
  late double _thinkMs = widget.settings.aiMaxThinkMs.toDouble();

  @override
  void didUpdateWidget(covariant _AiSearchLimits oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.aiMaxDepth != widget.settings.aiMaxDepth) {
      _depth = widget.settings.aiMaxDepth.toDouble();
    }
    if (oldWidget.settings.aiMaxThinkMs != widget.settings.aiMaxThinkMs) {
      _thinkMs = widget.settings.aiMaxThinkMs.toDouble();
    }
  }

  bool get _isCustom =>
      _depth.round() != widget.settings.aiStrength.maxDepth ||
      _thinkMs.round() != widget.settings.aiStrength.maxThinkMs;

  @override
  Widget build(BuildContext context) {
    final depth = _depth.round();
    final thinkMs = _thinkMs.round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isCustom)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '已自定义搜索参数',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF176B50),
                ),
              ),
            ),
          Text(
            '入门适合熟悉规则，普通适合日常练习，较强会思考更久。这里的选择作为新对局的默认难度。',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF68716E)),
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('高级电脑设置'),
            subtitle: Text(depth == 0 ? '自动安排（推荐）' : '最多 $depth 层，可能提前落子'),
            children: [
              Row(
                children: [
                  const Expanded(child: Text('电脑思考时间参考')),
                  Text(_formatThinkTime(thinkMs)),
                ],
              ),
              Slider(
                value: _thinkMs,
                min: 100,
                max: AiStrength.maxConfiguredThinkMs.toDouble(),
                divisions: (AiStrength.maxConfiguredThinkMs - 100) ~/ 50,
                label: _formatThinkTime(thinkMs),
                onChanged: (value) => setState(() => _thinkMs = value),
                onChangeEnd: (value) => widget.onUpdate(
                  widget.settings.copyWith(aiMaxThinkMs: value.round()),
                ),
              ),
              const Text('有棋钟时，电脑会结合剩余用时自动调整。'),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(child: Text('搜索深度上限')),
                  Text(depth == 0 ? '自动（推荐）' : '$depth 层'),
                ],
              ),
              Slider(
                value: _depth,
                min: 0,
                max: AiStrength.maxConfiguredDepth.toDouble(),
                divisions: AiStrength.maxConfiguredDepth,
                label: depth == 0 ? '自动' : '$depth 层',
                onChanged: (value) => setState(() => _depth = value),
                onChangeEnd: (value) => widget.onUpdate(
                  widget.settings.copyWith(aiMaxDepth: value.round()),
                ),
              ),
              TextButton.icon(
                onPressed: () => widget.onUpdate(
                  widget.settings.copyWith(
                    aiMaxDepth: widget.settings.aiStrength.maxDepth,
                    aiMaxThinkMs: widget.settings.aiStrength.maxThinkMs,
                  ),
                ),
                icon: const Icon(Icons.restart_alt),
                label: const Text('恢复推荐设置'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatThinkTime(int milliseconds) => milliseconds < 1000
      ? '$milliseconds 毫秒'
      : '${(milliseconds / 1000).toStringAsFixed(milliseconds % 1000 == 0 ? 0 : 1)} 秒';
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 9),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        AppGlassSurface(
          key: ValueKey('settings-group-$title'),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ],
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) => const Divider(
    height: 1,
    indent: 16,
    endIndent: 16,
    color: Color(0x26717F7B),
  );
}
