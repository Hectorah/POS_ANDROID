import 'package:flutter/material.dart';
import '../../core/utils/responsive_helper.dart';
import '../../core/constants/app_colors.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final bool isPositiveTrend;
  final String? trendValue;
  final Color? color;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.isPositiveTrend = true,
    this.trendValue,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper(context);
    final theme = Theme.of(context);
    final cardColor = color ?? theme.colorScheme.primary;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: EdgeInsets.all(responsive.getPadding(12)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              cardColor.withValues(alpha: 0.1),
              cardColor.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: EdgeInsets.all(responsive.getPadding(8)),
                    decoration: BoxDecoration(
                      color: cardColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: cardColor,
                      size: responsive.getFontSize(20),
                    ),
                  ),
                ),
                if (trendValue != null) ...[
                  SizedBox(width: responsive.getPadding(4)),
                  Flexible(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: responsive.getPadding(6),
                        vertical: responsive.getPadding(3),
                      ),
                      decoration: BoxDecoration(
                        color: isPositiveTrend
                            ? AppColors.success.withValues(alpha: 0.2)
                            : AppColors.error.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPositiveTrend
                                ? Icons.trending_up
                                : Icons.trending_down,
                            color: isPositiveTrend
                                ? AppColors.success
                                : AppColors.error,
                            size: responsive.getFontSize(12),
                          ),
                          SizedBox(width: responsive.getPadding(2)),
                          Flexible(
                            child: Text(
                              trendValue!,
                              style: TextStyle(
                                color: isPositiveTrend
                                    ? AppColors.success
                                    : AppColors.error,
                                fontSize: responsive.getFontSize(10),
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: responsive.getHeight(1)),
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: responsive.getFontSize(11),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: responsive.getHeight(0.5)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontSize: responsive.getFontSize(18),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
