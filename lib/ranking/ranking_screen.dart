import 'package:flutter/material.dart' hide Title;

import '../core/board.dart';
import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../progression/title.dart';
import 'ranking_service.dart';

/// 랭킹 화면 — Swift RankingView 이식.
/// 솔로 랭킹(난이도 스와이프 · 내 기록 + 전체 랭킹) / 대전·협동(전적 + 협동 최고 기록).
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  RankingService? _service;
  final LocalStore _s = LocalStore.shared;

  int _tab = 0;
  Difficulty _diff = Difficulty.beginner;
  final _pager = PageController();
  final Map<Difficulty, List<ScoreEntry>> _online = {};
  final Set<Difficulty> _loading = {};
  int? _touchRank;

  static const gold = Color.fromRGBO(242, 199, 77, 1);
  static const coopAccent = Color.fromRGBO(102, 179, 140, 1); // (0.40,0.70,0.55)

  @override
  void initState() {
    super.initState();
    try {
      _service = RankingService();
    } catch (_) {}
    _preloadAll();
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  Future<void> _preloadAll() async {
    await _load(_diff);
    for (final d in Difficulty.values) {
      if (d != _diff) await _load(d);
    }
    final r = await _service?.touchOnlineRank(_s.touchBest, _s.deviceId);
    if (mounted) setState(() => _touchRank = r);
  }

  Future<void> _load(Difficulty d) async {
    if (_service == null) return;
    setState(() => _loading.add(d));
    List<ScoreEntry> list = [];
    try {
      list = await _service!.top(d);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _online[d] = list;
      _loading.remove(d);
    });
  }

  static Color accent(Difficulty d) => switch (d) {
        Difficulty.beginner => const Color.fromRGBO(77, 199, 115, 1),
        Difficulty.intermediate => const Color.fromRGBO(64, 140, 242, 1),
        Difficulty.expert => const Color.fromRGBO(242, 140, 64, 1),
        Difficulty.ultimate => const Color.fromRGBO(204, 89, 217, 1),
      };

  static String timeLabel(int sec) =>
      sec < 60 ? '$sec초' : '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return ColoredBox(
      color: t.bg,
      child: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(children: [
          _header(t),
          const SizedBox(height: 16),
          _segment(t),
          const SizedBox(height: 16),
          Expanded(child: _tab == 0 ? _soloContent(t) : _versusContent(t)),
        ]),
      ),
    );
  }

  Widget _header(AppTheme t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Tap(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: t.fill, shape: BoxShape.circle),
            child: Icon(SF.xmark, size: 15, color: t.textSecondary),
          ),
        ),
        Expanded(
          child: Text('🏆 랭킹',
              textAlign: TextAlign.center,
              style: sf(20, weight: W.heavy, color: t.text)),
        ),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          constraints: const BoxConstraints(maxWidth: 140),
          decoration: BoxDecoration(color: t.fill, borderRadius: BorderRadius.circular(100)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(SF.personCropCircle, size: 13, color: gold),
            const SizedBox(width: 5),
            Flexible(
              child: Text(_s.nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: sf(12, weight: W.semibold, color: gold)),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _segment(AppTheme t) {
    Widget btn(int i, String label) {
      final sel = _tab == i;
      return Expanded(
        child: Tap(
          onTap: () {
            Haptics.tap();
            setState(() => _tab = i);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 38,
            alignment: Alignment.center,
            decoration: rr(9, sel ? gold : Colors.transparent),
            child: Text(label,
                style: sf(14, weight: W.bold, color: sel ? Colors.black : t.textSecondary)),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(5),
      decoration: rr(13, t.fill),
      child: Row(children: [btn(0, '솔로 랭킹'), const SizedBox(width: 6), btn(1, '대전·협동')]),
    );
  }

  // ── 솔로 ──
  Widget _soloContent(AppTheme t) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          for (final d in Difficulty.values) ...[
            if (d != Difficulty.beginner) const SizedBox(width: 8),
            Expanded(
              child: Tap(
                onTap: () {
                  Haptics.tap();
                  setState(() => _diff = d);
                  _pager.animateToPage(d.index,
                      duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 38,
                  alignment: Alignment.center,
                  decoration: rr(10, _diff == d ? accent(d) : t.fill),
                  child: Text(d.label,
                      style: sf(14,
                          weight: W.bold,
                          color: _diff == d ? Colors.black : t.textSecondary)),
                ),
              ),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 16),
      Expanded(
        child: PageView(
          controller: _pager,
          onPageChanged: (i) => setState(() => _diff = Difficulty.values[i]),
          children: [
            for (final d in Difficulty.values)
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                child: Column(children: [
                  _myRecordCard(t, d),
                  const SizedBox(height: 16),
                  _onlineSection(t, d),
                ]),
              ),
          ],
        ),
      ),
    ]);
  }

  Widget _myRecordCard(AppTheme t, Difficulty d) {
    final best = _s.soloBest(d);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: rr(16, t.fill, stroke: accent(d).withValues(alpha: 0.35)),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('내 최고 기록', style: sf(12, weight: W.semibold, color: t.textSecondary)),
          const SizedBox(height: 4),
          best != null
              ? Text(timeLabel(best), style: sf(30, weight: W.heavy, color: t.text, height: 1.15))
              : Text('기록 없음', style: sf(22, weight: W.bold, color: t.textTertiary)),
        ]),
        const Spacer(),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('클리어 횟수', style: sf(12, weight: W.semibold, color: t.textSecondary)),
          const SizedBox(height: 4),
          Text('${_s.soloClearCount(d)}회', style: sf(22, weight: W.bold, color: t.text)),
        ]),
      ]),
    );
  }

  Widget _onlineSection(AppTheme t, Difficulty d) {
    final list = _online[d] ?? const [];
    final loading = _loading.contains(d);
    Widget body;
    if (loading && list.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: t.textSecondary))),
      );
    } else if (list.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('아직 등록된 기록이 없어요.\n클리어하면 자동으로 등록됩니다.',
              textAlign: TextAlign.center, style: sf(13, color: t.textTertiary)),
        ),
      );
    } else {
      body = Column(children: [
        for (var i = 0; i < list.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          _rankRow(t, i + 1, list[i]),
        ],
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('전체 랭킹', style: sf(15, weight: W.bold, color: t.text)),
        const Spacer(),
        Tap(
          onTap: loading ? null : () => _load(d),
          child: Icon(SF.arrowClockwise, size: 14, color: t.textSecondary),
        ),
      ]),
      const SizedBox(height: 10),
      body,
    ]);
  }

  Widget _rankRow(AppTheme t, int rank, ScoreEntry e) {
    final mine = e.deviceId == _s.deviceId;
    final badge = switch (rank) { 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => '#$rank' };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: rr(12, mine ? gold.withValues(alpha: 0.12) : t.fill),
      child: Row(children: [
        SizedBox(
          width: 34,
          child: Text(badge,
              textAlign: TextAlign.center,
              style: sf(15, weight: W.heavy, color: rank <= 3 ? gold : t.textSecondary)),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: sf(15, weight: mine ? W.bold : W.medium, color: mine ? gold : t.text)),
            if (e.title.isNotEmpty) ...[
              const SizedBox(height: 2),
              TitleBadge(name: e.title, size: 9),
            ],
          ]),
        ),
        if (mine) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: gold, borderRadius: BorderRadius.circular(100)),
            child: Text('나', style: sf(10, weight: W.bold, color: Colors.black)),
          ),
        ],
        const Spacer(),
        Text(timeLabel(e.timeSec), style: sf(15, weight: W.bold, color: t.text, mono: true)),
      ]),
    );
  }

  // ── 대전·협동 ──
  Widget _versusContent(AppTheme t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      child: Column(children: [
        _raceStatsCard(t),
        const SizedBox(height: 16),
        _coopBestCard(t),
        const SizedBox(height: 16 + 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('대전은 레이스·지뢰 대결의 승패가, 협동은 ‘너에게 닿기를’을 함께 클리어한 기록이 쌓여요.',
              textAlign: TextAlign.center,
              style: sf(12, weight: W.medium, color: t.textTertiary)),
        ),
      ]),
    );
  }

  Widget _raceStatsCard(AppTheme t) {
    Widget item(String v, String l, Color c) => Expanded(
          child: Column(children: [
            Text(v, style: sf(22, weight: W.heavy, color: c)),
            const SizedBox(height: 3),
            Text(l, style: sf(11, weight: W.semibold, color: t.textSecondary)),
          ]),
        );
    Widget div() => Container(width: 1, height: 30, color: t.fillElevated);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: rr(16, t.fill, stroke: gold.withValues(alpha: 0.25)),
      child: Column(children: [
        Row(children: [
          Text('⚔️ 대전 전적', style: sf(13, weight: W.bold, color: t.text)),
          const Spacer(),
          Text('${_s.raceTotal}전', style: sf(12, weight: W.semibold, color: t.textSecondary)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          item('${_s.raceWins}', '승', const Color.fromRGBO(77, 199, 115, 1)),
          div(),
          item('${_s.raceLosses}', '패', const Color.fromRGBO(235, 102, 97, 1)),
          if (_s.raceDraws > 0) ...[div(), item('${_s.raceDraws}', '무', t.textSecondary)],
          div(),
          item('${_s.raceWinRate}%', '승률', gold),
        ]),
      ]),
    );
  }

  Widget _coopBestCard(AppTheme t) {
    final best = _s.touchBest;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: rr(16, t.fill, stroke: coopAccent.withValues(alpha: 0.30)),
      child: Row(children: [
        const Text('🤝', style: TextStyle(fontSize: 26)),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('너에게 닿기를 · 협동 최고',
              style: sf(12, weight: W.semibold, color: t.textSecondary)),
          const SizedBox(height: 3),
          best != null
              ? Text(timeLabel(best), style: sf(24, weight: W.heavy, color: t.text))
              : Text('아직 기록 없음', style: sf(17, weight: W.bold, color: t.textTertiary)),
        ]),
        const Spacer(),
        if (_touchRank != null)
          Column(children: [
            Text('전체', style: sf(11, weight: W.semibold, color: t.textSecondary)),
            const SizedBox(height: 2),
            Text('$_touchRank등', style: sf(20, weight: W.heavy, color: coopAccent)),
          ]),
      ]),
    );
  }
}
