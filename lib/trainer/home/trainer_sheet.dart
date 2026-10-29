import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../domain/trainers.dart';
import '../learn/path_screen.dart';
import '../practice/practice_setup.dart';
import '../ui/kit.dart';

/// "How would you like to train?" — Learn (guided path) or Practice (quiz).
Future<void> openTrainerSheet(BuildContext context, TrainerKind kind) async {
  final store = TrainerScope.of(context).store;
  final color = trainerColor(kind);
  final choice = await showTrainerSheet<String>(
    context,
    (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            TrainerBadge(color: color, icon: trainerIcon(kind), size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kind.title, style: TT.h3),
                  const Text('Nasıl çalışmak istersin?', style: TT.small),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Divider(color: TC.line)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '%${(store.mastery(kind) * 100).round()} ustalık',
                style: TT.small,
              ),
            ),
            const Expanded(child: Divider(color: TC.line)),
          ],
        ),
        const SizedBox(height: 14),
        _SheetOption(
          key: const Key('sheet_learn'),
          icon: Icons.menu_book_rounded,
          title: 'Öğren',
          subtitle: 'Adım adım rehberli dersler',
          color: color,
          filled: false,
          onTap: () => Navigator.pop(context, 'learn'),
        ),
        const SizedBox(height: 12),
        _SheetOption(
          key: const Key('sheet_practice'),
          icon: Icons.play_arrow_rounded,
          title: 'Pratik',
          subtitle: 'Kulağını süreli bir testle sına',
          color: color,
          filled: true,
          onTap: () => Navigator.pop(context, 'practice'),
        ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => choice == 'learn'
          ? PathScreen(trainer: kind)
          : PracticeSetupScreen(trainer: kind),
    ),
  );
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.filled,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool filled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      color: filled ? null : Colors.white,
      gradient: filled
          ? LinearGradient(colors: [color.withValues(alpha: 0.85), color])
          : null,
      border: filled ? null : Border.all(color: TC.line, width: 1.5),
      boxShadow: filled
          ? [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ]
          : null,
    ),
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: filled
                      ? Colors.white.withValues(alpha: 0.25)
                      : soft(color),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: filled ? Colors.white : color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: filled ? Colors.white : TC.ink,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: filled
                            ? Colors.white.withValues(alpha: 0.9)
                            : TC.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: filled ? Colors.white : TC.faint,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
