import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design_system/components/studio_surfaces.dart';
import '../design_system/studio_typography.dart';
import '../rust_api.dart';

typedef PublishCalendarDayCallback = void Function(
  BuildContext context,
  DateTime dayLocal,
);

/// Month grid showing how many drafts are scheduled on each calendar day (local midnight bucket).
class PublishScheduleCalendar extends StatefulWidget {
  const PublishScheduleCalendar({
    super.key,
    required this.drafts,
    required this.busy,
    required this.onDayTap,
  });

  final List<PublishDraftRow> drafts;
  final bool busy;
  final PublishCalendarDayCallback onDayTap;

  @override
  State<PublishScheduleCalendar> createState() =>
      _PublishScheduleCalendarState();
}

class _PublishScheduleCalendarState extends State<PublishScheduleCalendar> {
  late DateTime _monthFirst;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _monthFirst = DateTime(now.year, now.month);
  }

  Map<DateTime, int> _scheduledCountsByDay() {
    final out = <DateTime, int>{};
    for (final d in widget.drafts) {
      final key = _scheduledLocalDay(d.scheduledAt);
      if (key == null) {
        continue;
      }
      out[key] = (out[key] ?? 0) + 1;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    final outline =
        studioPanelBorderColor(context).withValues(alpha: 0.7);
    final counts = _scheduledCountsByDay();
    final locale = Localizations.localeOf(context);
    final title = DateFormat.yMMMM(locale.toString()).format(_monthFirst);
    final mat = MaterialLocalizations.of(context);
    final n = mat.narrowWeekdays;
    final weekdayLabels = [n[1], n[2], n[3], n[4], n[5], n[6], n[0]];
    final cells = _cellsForMonth(_monthFirst);
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: l10n.shortVideoPublishCalendarPrevMonth,
              onPressed:
                  widget.busy ? null : () => _shiftMonth(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: l10n.shortVideoPublishCalendarNextMonth,
              onPressed:
                  widget.busy ? null : () => _shiftMonth(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final w in weekdayLabels)
              Expanded(
                child: Text(
                  w,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(color: outline),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cells.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.05,
          ),
          itemBuilder: (context, index) {
            final cell = cells[index];
            if (cell.isPadding) {
              return const SizedBox.shrink();
            }
            final day = cell.day!;
            final c = counts[DateTime(day.year, day.month, day.day)] ?? 0;
            final isToday =
                DateTime(day.year, day.month, day.day) == todayKey;

            final labelStyle = theme.textTheme.labelSmall?.copyWith(
              fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
            );
            final countLabel = c <= 0
                ? l10n.shortVideoPublishCalendarDraftCountEmpty
                : (c >= 10
                    ? l10n.shortVideoPublishCalendarDraftCountOverflow
                    : '$c');

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.busy
                    ? null
                    : () => widget.onDayTap(context, day),
                borderRadius: BorderRadius.circular(8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: outline),
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: isToday ? 0.65 : 0.35,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(l10n.l10nBatch_775383c7b6(day.day), style: labelStyle),
                        const SizedBox(height: 2),
                        Text(
                          countLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: outline,
                            fontSize: StudioTypography.of(context).meta,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _shiftMonth(int delta) {
    setState(() {
      final y = _monthFirst.year;
      final m = _monthFirst.month + delta;
      _monthFirst = DateTime(y, m);
    });
  }

  List<_CalendarCell> _cellsForMonth(DateTime monthFirst) {
    final y = monthFirst.year;
    final m = monthFirst.month;
    final first = DateTime(y, m, 1);
    final daysInMonth = DateTime(y, m + 1, 0).day;
    final leading = first.weekday - DateTime.monday;
    assert(leading >= 0 && leading < 7, 'unexpected weekday');

    final list = <_CalendarCell>[
      for (var i = 0; i < leading; i++) const _CalendarCell.padding(),
      for (var d = 1; d <= daysInMonth; d++)
        _CalendarCell.day(DateTime(y, m, d)),
    ];
    final tail = list.length % 7;
    if (tail != 0) {
      for (var i = 0; i < 7 - tail; i++) {
        list.add(const _CalendarCell.padding());
      }
    }
    return list;
  }
}

DateTime? _scheduledLocalDay(String? scheduledAtIso) {
  final trimmed = (scheduledAtIso ?? '').trim();
  if (trimmed.isEmpty) {
    return null;
  }
  try {
    final utc = DateTime.parse(trimmed).toUtc();
    final loc = utc.toLocal();
    return DateTime(loc.year, loc.month, loc.day);
  } catch (_) {
    return null;
  }
}

class _CalendarCell {
  const _CalendarCell.padding() : day = null;
  _CalendarCell.day(DateTime d) : day = d;

  final DateTime? day;
  bool get isPadding => day == null;
}
