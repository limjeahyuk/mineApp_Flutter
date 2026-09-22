import 'package:flutter/material.dart';

import '../core/theme.dart';

/// 우하단 아이템 도크 — 레이더 · 자동깃발. Swift AutoFlagDock 이식(플로팅형).
/// 티켓이 0이거나 게임 중이 아니면 흐리게. 자동깃발은 발동 대기(probing) 시 강조.
class ItemDock extends StatelessWidget {
  const ItemDock({
    super.key,
    required this.radarTickets,
    required this.autoFlagTickets,
    required this.isPlaying,
    required this.probing,
    required this.onRadar,
    required this.onToggleProbe,
  });

  final int radarTickets;
  final int autoFlagTickets;
  final bool isPlaying;
  final bool probing;
  final VoidCallback onRadar;
  final VoidCallback onToggleProbe;

  static const _radarColor = Color(0xFF3AA6A0);
  static const _flagColor = Color(0xFFA45CE0);

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 12, bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _pill(
            t,
            icon: Icons.wifi_tethering,
            label: '레이더',
            count: radarTickets,
            color: _radarColor,
            enabled: isPlaying && radarTickets > 0,
            highlighted: false,
            onTap: onRadar,
          ),
          const SizedBox(height: 10),
          _pill(
            t,
            icon: Icons.flag,
            label: '자동깃발',
            count: autoFlagTickets,
            color: _flagColor,
            enabled: isPlaying && autoFlagTickets > 0,
            highlighted: probing,
            onTap: onToggleProbe,
          ),
        ],
      ),
    );
  }

  Widget _pill(
    AppTheme t, {
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required bool enabled,
    required bool highlighted,
    required VoidCallback onTap,
  }) {
    final active = enabled;
    final base = t.fillElevated;
    return Opacity(
      opacity: active ? 1 : 0.5,
      child: Material(
        color: highlighted ? color : base,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: active ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: active ? color : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 20,
                    color: highlighted ? Colors.white : (active ? color : t.textSecondary)),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label,
                        style: TextStyle(
                            color: highlighted ? Colors.white : t.text,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                    Text('남은 $count개',
                        style: TextStyle(
                            color: highlighted
                                ? Colors.white70
                                : t.textSecondary,
                            fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
