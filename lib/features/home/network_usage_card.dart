import 'package:flutter/material.dart';

import '../../core/app_strings.dart';
import '../../core/recognition_mode.dart';
import '../../services/network/network_status.dart';

/// Explains whether the selected recognition mode sends audio over the network.
class NetworkUsageCard extends StatelessWidget {
  const NetworkUsageCard({
    required this.mode,
    this.network,
    super.key,
  });

  final RecognitionMode mode;
  final NetworkStatus? network;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onlineMode = mode == RecognitionMode.device;
    final online = network?.online;
    final connection = switch (online) {
      true => AppStrings.networkOnline,
      false => AppStrings.networkOffline,
      null => null,
    };
    final icon = onlineMode ? Icons.wifi : Icons.wifi_off;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.onSurface),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppStrings.internetTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            onlineMode ? AppStrings.internetDevice : AppStrings.internetWhisper,
            style: theme.textTheme.titleMedium,
          ),
          if (connection != null) ...[
            const SizedBox(height: 8),
            Text(
              connection,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (onlineMode && online == false) ...[
            const SizedBox(height: 8),
            Text(
              AppStrings.networkNeeded,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
