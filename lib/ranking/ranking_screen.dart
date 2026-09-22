import 'package:flutter/material.dart';

import '../core/board.dart';
import '../core/local_store.dart';
import '../core/theme.dart';
import 'ranking_service.dart';

/// 랭킹 화면 — Swift RankingView 이식.
/// 솔로 랭킹(난이도별 내 기록 + 온라인 전체) / 대전·협동(전적).
///
/// ponytail: 협동('너에게 닿기를')은 모드 미이식이라 카드만 "준비 중"으로 둔다.
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  final RankingService _service = RankingService();
  final LocalStore _s = LocalStore.shared;

  int _tab = 0; // 0=솔로, 1=대전·협동
  Difficulty _diff = Difficulty.beginner;
  final Map<Difficulty, List<ScoreEntry>> _online = {};
  final Set<Difficulty> _loading = {};

  static const _gold = Color(0xFFF2C74D);
  static const _coopAccent = Color(0xFF66B38C);

  @override
  void initState() {
    super.initState();
    _loadOnline(_diff);
  }

  Color _accent(Difficulty d) => switch (d) {
        Difficulty.beginner => const Color(0xFF4DC773),
        Difficulty.intermediate => const Color(0xFF408CF2),
        Difficulty.expert => const Color(0xFFF28C40),
        Difficulty.ultimate => const Color(0xFFCC59D9),
      };

  String _timeLabel(int sec) =>
      sec < 60 ? '$sec초' : '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';

  String _rankBadge(int rank) => switch (rank) {
        1 => '🥇',
        2 => '🥈',
        3 => '🥉',
        _ => '#$rank',
      };

  Future<void> _loadOnline(Difficulty d) async {
    setState(() => _loading.add(d));
    try {
      final list = await _service.top(d);
      if (mounted) setState(() => _online[d] = list);
    } catch (_) {
      if (mounted) setState(() => _online[d] = const []);
    } finally {
      if (mounted) setState(() => _loading.remove(d));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            _header(t),
            const SizedBox(height: 8),
            _segment(t),
            const SizedBox(height: 12),
            Expanded(child: _tab == 0 ? _soloTab(t) : _versusTab(t)),
          ],
        ),
      ),
    );
  }

  Widget _header(AppTheme t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
      child: Row(
        children: [
          Material(
            color: t.fill,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).pop(),
              child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(Icons.close, color: t.textSecondary, size: 20)),
            ),
          ),
          Expanded(
            child: Text('🏆 랭킹',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: t.text, fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: t.fill, borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.account_circle, color: _gold, size: 16),
                const SizedBox(width: 5),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 90),
                  child: Text(_s.nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _segment(AppTheme t) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
          color: t.fill, borderRadius: BorderRadius.circular(13)),
      child: Row(
        children: [
          _segBtn(t, 0, '솔로 랭킹'),
          _segBtn(t, 1, '대전·협동'),
        ],
      ),
    );
  }

  Widget _segBtn(AppTheme t, int idx, String label) {
    final selected = _tab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = idx),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: selected ? _gold : Colors.transparent,
              borderRadius: BorderRadius.circular(9)),
          child: Text(label,
              style: TextStyle(
                  color: selected ? Colors.black : t.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  // ── 솔로 탭 ──
  Widget _soloTab(AppTheme t) {
    final list = _online[_diff] ?? const [];
    final isLoading = _loading.contains(_diff);
    return Column(
      children: [
        _diffPicker(t),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            children: [
              _myRecordCard(t),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('전체 랭킹',
                      style: TextStyle(
                          color: t.text,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    onPressed: isLoading ? null : () => _loadOnline(_diff),
                    icon: Icon(Icons.refresh, color: t.textSecondary, size: 20),
                  ),
                ],
              ),
              if (isLoading && list.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('아직 등록된 기록이 없어요.\n클리어하면 자동으로 등록됩니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: t.textTertiary, fontSize: 13)),
                )
              else
                for (var i = 0; i < list.length; i++) ...[
                  _rankRow(t, i + 1, list[i]),
                  const SizedBox(height: 6),
                ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _diffPicker(AppTheme t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final d in Difficulty.values) ...[
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _diff = d);
                  if (!_online.containsKey(d)) _loadOnline(d);
                },
                child: Container(
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _diff == d ? _accent(d) : t.fill,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(d.label,
                      style: TextStyle(
                          color: _diff == d ? Colors.black : t.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            if (d != Difficulty.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _myRecordCard(AppTheme t) {
    final best = _s.soloBest(_diff);
    final count = _s.soloClearCount(_diff);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent(_diff).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('내 최고 기록',
                  style: TextStyle(color: t.textSecondary, fontSize: 12)),
              const SizedBox(height: 4),
              Text(best != null ? _timeLabel(best) : '기록 없음',
                  style: TextStyle(
                      color: best != null ? t.text : t.textTertiary,
                      fontSize: best != null ? 30 : 22,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('클리어 횟수',
                  style: TextStyle(color: t.textSecondary, fontSize: 12)),
              const SizedBox(height: 4),
              Text('$count회',
                  style: TextStyle(
                      color: t.text,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rankRow(AppTheme t, int rank, ScoreEntry e) {
    final mine = e.deviceId == _s.deviceId;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: mine ? _gold.withValues(alpha: 0.12) : t.fill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(_rankBadge(rank),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: rank <= 3 ? _gold : t.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(e.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: mine ? _gold : t.text,
                    fontSize: 15,
                    fontWeight: mine ? FontWeight.bold : FontWeight.w500)),
          ),
          if (mine)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: _gold, borderRadius: BorderRadius.circular(10)),
              child: const Text('나',
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          Text(_timeLabel(e.timeSec),
              style: TextStyle(
                  color: t.text,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }

  // ── 대전·협동 탭 ──
  Widget _versusTab(AppTheme t) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      children: [
        _raceStatsCard(t),
        const SizedBox(height: 16),
        _coopCard(t),
        const SizedBox(height: 12),
        Text('대전은 레이스·지뢰 대결의 승패가 쌓여요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.textTertiary, fontSize: 12)),
      ],
    );
  }

  Widget _raceStatsCard(AppTheme t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('⚔️ 대전 전적',
                  style: TextStyle(
                      color: t.text,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${_s.raceTotal}전',
                  style: TextStyle(color: t.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _stat(t, '${_s.raceWins}', '승', const Color(0xFF4DC773)),
              _statDivider(t),
              _stat(t, '${_s.raceLosses}', '패', const Color(0xFFEB6661)),
              if (_s.raceDraws > 0) ...[
                _statDivider(t),
                _stat(t, '${_s.raceDraws}', '무', t.textSecondary),
              ],
              _statDivider(t),
              _stat(t, '${_s.raceWinRate}%', '승률', _gold),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(AppTheme t, String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(color: t.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _statDivider(AppTheme t) =>
      Container(width: 1, height: 30, color: t.fillElevated);

  Widget _coopCard(AppTheme t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _coopAccent.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          const Text('🤝', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('너에게 닿기를 · 협동 최고',
                    style: TextStyle(color: t.textSecondary, fontSize: 12)),
                const SizedBox(height: 3),
                Text('준비 중',
                    style: TextStyle(
                        color: t.textTertiary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
