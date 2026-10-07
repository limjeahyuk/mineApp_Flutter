import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide Title;

import '../core/board.dart';
import '../core/haptics.dart';
import '../core/local_store.dart';
import '../core/theme.dart';
import '../core/ui.dart';
import '../progression/title.dart';
import 'ranking_service.dart';

/// 랭킹 화면 — Swift RankingView 이식.
/// [솔로 랭킹 | 대전·협동] 세그먼트. 솔로는 난이도별 내 기록(로컬) + 전체 상위 기록(온라인)을
/// 좌우 스와이프로 넘기고, 대전·협동은 승패 전적 + 협동 최고 기록·전체 등수.
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key, this.service});
  final RankingService? service;

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  late final RankingService _svc = widget.service ?? RankingService();
  final LocalStore _s = LocalStore.shared;
  final PageController _pages = PageController();

  bool _soloTab = true;
  Difficulty _difficulty = Difficulty.beginner;
  final Map<Difficulty, List<ScoreEntry>> _online = {};
  final Set<Difficulty> _loading = {};
  int? _touchRank;

  static const _gold = AppTheme.gold;
  static const _coopAccent = Color.fromRGBO(102, 179, 140, 1);

  static Color _accent(Difficulty d) => switch (d) {
        Difficulty.beginner => const Color.fromRGBO(77, 199, 115, 1),
        Difficulty.intermediate => const Color.fromRGBO(64, 140, 242, 1),
        Difficulty.expert => const Color.fromRGBO(242, 140, 64, 1),
        Difficulty.ultimate => const Color.fromRGBO(204, 89, 217, 1),
      };

  @override
  void initState() {
    super.initState();
    _preloadAll();
    _svc.touchOnlineRank().then((r) {
      if (mounted) setState(() => _touchRank = r);
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// 처음 열릴 때 모든 난이도를 미리 불러와 스와이프가 끊기지 않게 한다(현재 난이도 우선).
  Future<void> _preloadAll() async {
    await _loadOnline(_difficulty);
    for (final d in Difficulty.values) {
      if (d != _difficulty) await _loadOnline(d);
    }
  }

  Future<void> _loadOnline(Difficulty d) async {
    setState(() => _loading.add(d));
    List<ScoreEntry> list;
    try {
      list = await _svc.top(d);
    } catch (_) {
      list = const [];
    }
    if (!mounted) return;
    setState(() {
      _online[d] = list;
      _loading.remove(d);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Material(
      color: t.bg,
      child: Column(
        children: [
          const SizedBox(height: 14),
          _header(t),
          const SizedBox(height: 16),
          _segment(t),
          const SizedBox(height: 16),
          Expanded(child: _soloTab ? _soloContent(t) : _versusContent(t)),
        ],
      ),
    );
  }

  Widget _header(AppTheme t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          PlainButton(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: t.fill, shape: BoxShape.circle),
              child: Icon(Icons.close, size: 17, color: t.textSecondary),
            ),
          ),
          const Spacer(),
          Text('🏆 랭킹',
              style: TextStyle(
                  color: t.text, fontSize: 20, fontWeight: FontWeight.w900)),
          const Spacer(),
          // 내 닉네임 표시(읽기 전용) — 변경은 '내 정보'에서.
          Container(
            height: 36,
            constraints: const BoxConstraints(maxWidth: 130),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
                color: t.fill, borderRadius: BorderRadius.circular(100)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.account_circle_outlined, size: 14, color: _gold),
              const SizedBox(width: 5),
              Flexible(
                child: Text(_s.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _segment(AppTheme t) {
    Widget btn(bool solo, String label) {
      final selected = _soloTab == solo;
      return Expanded(
        child: PlainButton(
          onTap: () {
            Haptics.tap();
            setState(() => _soloTab = solo);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
            color: t.fill, borderRadius: BorderRadius.circular(13)),
        child: Row(children: [
          btn(true, '솔로 랭킹'),
          const SizedBox(width: 6),
          btn(false, '대전·협동'),
        ]),
      ),
    );
  }

  // MARK: 솔로 — 난이도 선택 + 좌우 스와이프 페이지

  Widget _soloContent(AppTheme t) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final d in Difficulty.values) ...[
                if (d != Difficulty.beginner) const SizedBox(width: 8),
                Expanded(
                  child: PlainButton(
                    onTap: () {
                      Haptics.tap();
                      setState(() => _difficulty = d);
                      _pages.animateToPage(d.index,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: _difficulty == d ? _accent(d) : t.fill,
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(d.label,
                          style: TextStyle(
                              color: _difficulty == d
                                  ? Colors.black
                                  : t.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: PageView(
            controller: _pages,
            onPageChanged: (i) =>
                setState(() => _difficulty = Difficulty.values[i]),
            children: [
              for (final d in Difficulty.values)
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                  child: Column(
                    children: [
                      _myRecordCard(t, d),
                      const SizedBox(height: 16),
                      _onlineSection(t, d),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _myRecordCard(AppTheme t, Difficulty d) {
    final best = _s.soloBest(d);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent(d).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('내 최고 기록',
                  style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              if (best != null)
                Text(timeLabel(best),
                    style: TextStyle(
                        color: t.text,
                        fontSize: 30,
                        fontWeight: FontWeight.w900))
              else
                Text('기록 없음',
                    style: TextStyle(
                        color: t.textTertiary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('클리어 횟수',
                  style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('${_s.soloClearCount(d)}회',
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

  Widget _onlineSection(AppTheme t, Difficulty d) {
    final list = _online[d] ?? const [];
    final loading = _loading.contains(d);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('전체 랭킹',
              style: TextStyle(
                  color: t.text, fontSize: 15, fontWeight: FontWeight.bold)),
          const Spacer(),
          PlainButton(
            onTap: loading ? null : () => _loadOnline(d),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.refresh, size: 17, color: t.textSecondary),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        if (loading && list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
                child: CupertinoActivityIndicator(color: t.textSecondary)),
          )
        else if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('아직 등록된 기록이 없어요.\n클리어하면 자동으로 등록됩니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t.textTertiary, fontSize: 13)),
            ),
          )
        else
          for (var i = 0; i < list.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            _rankRow(t, i + 1, list[i]),
          ],
      ],
    );
  }

  String _rankBadge(int rank) => switch (rank) {
        1 => '🥇',
        2 => '🥈',
        3 => '🥉',
        _ => '#$rank',
      };

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
                    fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: mine ? _gold : t.text,
                        fontSize: 15,
                        fontWeight:
                            mine ? FontWeight.bold : FontWeight.w500)),
                if (e.title.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  TitleBadge(name: e.title, size: 9),
                ],
              ],
            ),
          ),
          if (mine) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: _gold, borderRadius: BorderRadius.circular(100)),
              child: const Text('나',
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ],
          const Spacer(),
          Text(timeLabel(e.timeSec),
              style: TextStyle(
                  color: t.text,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Menlo',
                  fontFamilyFallback: const ['Courier', 'monospace'])),
        ],
      ),
    );
  }

  // MARK: 대전·협동

  Widget _versusContent(AppTheme t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      child: Column(
        children: [
          _raceStatsCard(t),
          const SizedBox(height: 16),
          _coopBestCard(t),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Text(
                '대전은 레이스·지뢰 대결의 승패가, 협동은 ‘너에게 닿기를’을 함께 클리어한 기록이 쌓여요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: t.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _statItem(AppTheme t, String value, String label, Color color) =>
      Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _divider(AppTheme t) =>
      Container(width: 1, height: 30, color: t.fillElevated);

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
          Row(children: [
            Text('⚔️ 대전 전적',
                style: TextStyle(
                    color: t.text, fontSize: 13, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('${_s.raceTotal}전',
                style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _statItem(t, '${_s.raceWins}', '승',
                const Color.fromRGBO(77, 199, 115, 1)),
            _divider(t),
            _statItem(t, '${_s.raceLosses}', '패',
                const Color.fromRGBO(235, 102, 97, 1)),
            if (_s.raceDraws > 0) ...[
              _divider(t),
              _statItem(t, '${_s.raceDraws}', '무', t.textSecondary),
            ],
            _divider(t),
            _statItem(t, '${_s.raceWinRate}%', '승률', _gold),
          ]),
        ],
      ),
    );
  }

  Widget _coopBestCard(AppTheme t) {
    final best = _s.touchBest;
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('너에게 닿기를 · 협동 최고',
                  style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              if (best != null)
                Text(timeLabel(best),
                    style: TextStyle(
                        color: t.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w900))
              else
                Text('아직 기록 없음',
                    style: TextStyle(
                        color: t.textTertiary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
            ],
          ),
          const Spacer(),
          if (_touchRank != null)
            Column(children: [
              Text('전체',
                  style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('$_touchRank등',
                  style: const TextStyle(
                      color: _coopAccent,
                      fontSize: 20,
                      fontWeight: FontWeight.w900)),
            ]),
        ],
      ),
    );
  }
}
