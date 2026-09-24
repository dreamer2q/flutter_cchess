import 'package:flutter/material.dart';

class XiangqiRulesPage extends StatelessWidget {
  const XiangqiRulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F1),
      appBar: AppBar(
        leading: IconButton(
          tooltip: '返回首页',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text('象棋规则'),
        backgroundColor: const Color(0xFFF0F2F1),
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
            children: const [
              _RulesIntroduction(),
              SizedBox(height: 24),
              _RulesSection(
                title: '棋盘与行棋',
                description:
                    '棋子落在纵横线的交点上。棋盘中间是“河界”，双方底线附近各有一个九宫。红方先行，双方轮流走一步。把棋子走到对方棋子所在的交点即可吃子；每种棋子都有自己的移动范围，不能越过规则禁止的路线。',
              ),
              SizedBox(height: 24),
              _PieceRules(),
              SizedBox(height: 24),
              _RulesSection(
                title: '将军与胜负',
                description:
                    '攻击对方帅（将）称为“将军”，被将军的一方必须立即解除攻击。不能让己方帅（将）暴露在攻击下，也不能让双方帅（将）在同一直线上直接相对。帅（将）被将死，或轮到一方行棋却没有合法着法，该方负。',
              ),
              SizedBox(height: 24),
              _NotationExample(),
              SizedBox(height: 22),
              Text(
                '规则说明依据《中国象棋竞赛规则（2020版）》整理。',
                style: TextStyle(color: Color(0xFF68716E), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RulesIntroduction extends StatelessWidget {
  const _RulesIntroduction();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .82),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x26717F7B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.grid_4x4_rounded,
            color: Color(0xFF2D8062),
            size: 26,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '目标：保护己方帅（将），将死对方',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  '象棋是双方轮流行棋的策略棋类。每一步都要为自己的帅（将）留出安全位置。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF68716E),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RulesSection extends StatelessWidget {
  const _RulesSection({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF3D4643),
            height: 1.65,
          ),
        ),
      ],
    );
  }
}

class _PieceRules extends StatelessWidget {
  const _PieceRules();

  static const rules = <(String, String, String)>[
    ('帅 / 将', '在九宫内每次沿横线或竖线走一格；不能走到被攻击的位置。', '帅'),
    ('仕 / 士', '在九宫内沿斜线走一格，负责保护帅（将）。', '仕'),
    ('相 / 象', '沿斜线走两格，不能过河；中间点被占就是“塞象眼”。', '相'),
    ('马', '走“日”字；起步方向旁的交点有棋子，就是“蹩马腿”。', '马'),
    ('车', '沿横线或竖线走任意格，中间不能有棋子阻挡。', '车'),
    ('炮', '不吃子时像车一样走；吃子时，炮与目标之间必须恰好隔一个棋子。', '炮'),
    ('兵 / 卒', '每次向前走一格；过河后还可以横走一格，但不能后退。', '兵'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '七类棋子',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .82),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x26717F7B)),
          ),
          child: Column(
            children: [
              for (var index = 0; index < rules.length; index++) ...[
                _PieceRuleRow(
                  name: rules[index].$1,
                  description: rules[index].$2,
                  glyph: rules[index].$3,
                ),
                if (index != rules.length - 1)
                  const Divider(height: 1, indent: 16, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PieceRuleRow extends StatelessWidget {
  const _PieceRuleRow({
    required this.name,
    required this.description,
    required this.glyph,
  });

  final String name;
  final String description;
  final String glyph;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x142D9B73),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x552D8062)),
            ),
            child: Text(
              glyph,
              style: const TextStyle(
                color: Color(0xFF176B50),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF68716E),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotationExample extends StatelessWidget {
  const _NotationExample();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x102D9B73),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x332D8062)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('棋谱怎么看', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 7),
          Text(
            '例如“炮二平五”：红方二路炮横向走到五路。棋谱中的“进”表示向对方方向前进，“退”表示回退，“平”表示横向移动。',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.55),
          ),
        ],
      ),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F1),
      appBar: AppBar(
        leading: IconButton(
          tooltip: '返回首页',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text('关于'),
        backgroundColor: const Color(0xFFF0F2F1),
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .82),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0x26717F7B)),
                  ),
                  child: const Icon(
                    Icons.grid_4x4_rounded,
                    size: 34,
                    color: Color(0xFF2D8062),
                  ),
                ),
                const SizedBox(height: 16),
                Text('中国象棋', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 5),
                Text(
                  '离线对弈，棋局保存在本机',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF68716E),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .82),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x26717F7B)),
                  ),
                  child: const Column(
                    children: [
                      _AboutFeatureRow(
                        icon: Icons.smart_toy_outlined,
                        title: '人机对局',
                        subtitle: '离线 AI，支持调整思考强度与棋钟',
                      ),
                      Divider(height: 1, indent: 16, endIndent: 16),
                      _AboutFeatureRow(
                        icon: Icons.people_outline,
                        title: '本地双人',
                        subtitle: '两位玩家共用一台设备对弈',
                      ),
                      Divider(height: 1, indent: 16, endIndent: 16),
                      _AboutFeatureRow(
                        icon: Icons.history_rounded,
                        title: '棋谱与复盘',
                        subtitle: '支持查看本地棋局和导入棋谱',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '无需注册账号。对局记录与偏好设置仅保存在当前设备。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF68716E),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const XiangqiRulesPage(),
                    ),
                  ),
                  icon: const Icon(Icons.help_outline_rounded),
                  label: const Text('查看象棋规则'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AboutFeatureRow extends StatelessWidget {
  const _AboutFeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2D8062)),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}
