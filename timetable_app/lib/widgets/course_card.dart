import 'package:flutter/material.dart';

import '../app_palette.dart';
import '../models/course.dart';
import '../services/schedule_utils.dart';

class CourseCard extends StatelessWidget {
  const CourseCard({
    super.key,
    required this.course,
    this.showWeekday = false,
    this.onTap,
  });

  final Course course;
  final bool showWeekday;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = course.colorValue != null
        ? Color(course.colorValue!)
        : Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: context.appCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: course.isCustom ? accent : context.appBorder,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 62,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clockTimeLabel(course),
                      style: TextStyle(
                        color: accent,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course.periodLabel,
                      style: TextStyle(
                        color: context.appMuted,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 4,
                height: 58,
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (showWeekday) ...[
                          Text(
                            weekdayShortLabel(course.weekday),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  course.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: context.appText,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                              if (course.isCustom) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    '自定义',
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                              if (onTap != null)
                                Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(
                                    Icons.edit_outlined,
                                    size: 15,
                                    color: context.appMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        _Meta(
                          icon: Icons.location_on_outlined,
                          text: course.location,
                        ),
                        _Meta(icon: Icons.person_outline, text: course.teacher),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      course.weeksLabel,
                      style: TextStyle(color: context.appMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: context.appMuted),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.appMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
