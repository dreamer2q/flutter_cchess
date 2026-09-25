import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cchess/chess/game/ai_strength.dart';
import 'package:flutter_cchess/theme/bloc/theme_bloc.dart';

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
      backgroundColor: const Color(0xFFF2F1EC),
      appBar: AppBar(
        leading: IconButton(
          tooltip: '返回对局',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text('设置'),
        backgroundColor: const Color(0xFFF2F1EC),
        surfaceTintColor: Colors.transparent,
      ),
      body: LayoutBuilder(
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
    );
  }
}

enum _SettingsSection {
  appearance('棋盘外观', '更换棋盘主题与棋子风格', Icons.palette_outlined),
  ai('电脑对手', '设置电脑强度与单步搜索上限', Icons.smart_toy_outlined),
  feedback('声音与触觉', '控制对局中的声音与设备反馈', Icons.volume_up_outlined),
  motion('动态效果', '调整棋子动画与界面动效', Icons.motion_photos_on_outlined);

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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(section.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 5),
        Text(
          section.subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF68716E)),
        ),
        const SizedBox(height: 24),
        detail,
      ],
    );

    if (compact) return content;
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(40, 32, 40, 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: content,
        ),
      ),
    );
  }

  Widget _appearance(BuildContext context) {
    return _SettingsGroup(
      title: '棋盘主题',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: GameSettings.defaultThemeConfigAsset,
                icon: Icon(Icons.grid_4x4),
                label: Text('经典木纹'),
              ),
              ButtonSegment(
                value: 'assets/skins/night/config.json',
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('夜间胡桃木'),
              ),
            ],
            selected: {settings.themeConfigAsset},
            onSelectionChanged: (selection) =>
                onUpdate(settings.copyWith(themeConfigAsset: selection.first)),
          ),
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
        const ListTile(
          title: Text('背景音乐'),
          subtitle: Text('音乐尚未提供'),
          trailing: Icon(Icons.hourglass_empty_rounded, size: 19),
          enabled: false,
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
      title: '电脑思考',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SegmentedButton<AiStrength>(
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
          Row(
            children: [
              const Expanded(child: Text('搜索深度上限')),
              Text('$depth 层'),
            ],
          ),
          Slider(
            value: _depth,
            min: 1,
            max: AiStrength.maxConfiguredDepth.toDouble(),
            divisions: AiStrength.maxConfiguredDepth - 1,
            label: '$depth 层',
            onChanged: (value) => setState(() => _depth = value),
            onChangeEnd: (value) => widget.onUpdate(
              widget.settings.copyWith(aiMaxDepth: value.round()),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Expanded(child: Text('每步思考上限')),
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
          Text(
            '设置的是搜索上限；局面简单时电脑可能更快落子。',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF68716E)),
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
      crossAxisAlignment: CrossAxisAlignment.start,
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
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xEFFFFFFF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x26717F7B)),
          ),
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
