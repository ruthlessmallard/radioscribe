import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/segment.dart';
import '../theme/app_theme.dart';

class SegmentCard extends StatelessWidget {
  final TranscriptSegment segment;
  final VoidCallback onDismiss;
  final bool showTimestamp;

  const SegmentCard({
    super.key,
    required this.segment,
    required this.onDismiss,
    this.showTimestamp = false,
  });

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: ValueKey(segment.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) => onDismiss(),
            backgroundColor: AppColors.grey,
            foregroundColor: Colors.white,
            icon: Icons.close,
            label: 'DISMISS',
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(4),
              bottomRight: Radius.circular(4),
            ),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 0),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: segment.backgroundColor,
          border: Border(
            left: BorderSide(
              color: segment.borderColor,
              width: segment.isPinned ? 3 : 0,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (segment.isPinned) ...[
              Row(
                children: [
                  Icon(
                    segment.isSafety ? Icons.warning_amber : Icons.push_pin,
                    color: segment.borderColor,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    segment.isSafety ? 'SAFETY ALERT' : 'WARNING',
                    style: TextStyle(
                      color: segment.borderColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  if (segment.matchedKeywords.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        segment.matchedKeywords.join(', '),
                        style: TextStyle(
                          color: segment.borderColor.withOpacity(0.7),
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
            ],
            Text(
              segment.text,
              style: TextStyle(
                color: segment.textColor,
                fontSize: 16,
                height: 1.4,
              ),
            ),
            if (showTimestamp) ...[
              const SizedBox(height: 4),
              Text(
                _formatTime(segment.timestamp),
                style: const TextStyle(
                  color: AppColors.greyLight,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
