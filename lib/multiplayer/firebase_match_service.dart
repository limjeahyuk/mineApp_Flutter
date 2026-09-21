import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../core/auth_service.dart';
import '../core/board.dart';
import '../core/local_store.dart';
import 'multiplayer.dart';

/// Firestore(named DB `mineappdatabase`) 매치메이킹 + RTDB 공유보드 동기화.
/// Swift `FirebaseMatchService`를 그대로 이식 — **같은 컬렉션/노드 스키마**라 iOS와 크로스플레이된다.
/// (Swift의 Firestore 보드 폴백 #else 경로는 RTDB가 항상 있는 Dart에선 죽은 코드라 생략)
class FirebaseMatchService extends MatchService {
  /// 실사용은 인자 없이 생성(LocalStore/Firebase 기본값). 테스트는 firestore/signIn/이름을
  /// 주입해 인메모리 Firestore로 매칭을 재현한다(RTDB는 지연 생성이라 매칭 테스트에선 안 건드림).
  FirebaseMatchService({
    this.kind = 'mine',
    String? deviceIdOverride,
    FirebaseFirestore? firestore,
    FirebaseDatabase? database,
    String? myName,
    String? myTitle,
    Future<void> Function()? signIn,
  })  : myId = deviceIdOverride ?? LocalStore.shared.deviceId,
        _db = firestore ??
            FirebaseFirestore.instanceFor(
                app: Firebase.app(), databaseId: 'mineappdatabase'),
        _databaseOverride = database,
        _myName = myName ?? LocalStore.shared.nickname,
        _myTitle = myTitle ?? LocalStore.shared.equippedTitleName,
        _signIn = signIn ?? AuthService.ensureSignedIn;

  /// 같은 종류끼리만 매칭("mine"=미니스위퍼, "treasure"=보물찾기).
  final String kind;
  final String myId;

  final FirebaseFirestore _db;
  final String _myName;
  final String _myTitle;
  final Future<void> Function() _signIn;

  // RTDB는 공유 보드 동기화에서만 쓴다 → 매칭만 하는 테스트가 Firebase init 없이 돌게 지연 생성.
  FirebaseDatabase? _databaseOverride;
  FirebaseDatabase get _rtdb => _databaseOverride ??= FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://mineapp-aabc8-default-rtdb.firebaseio.com',
      );

  CollectionReference<Map<String, dynamic>> get _matches =>
      _db.collection('matches');

  DocumentReference<Map<String, dynamic>>? _matchRef;
  String? _opponentId;
  bool _isHost = false;
  int _round = 0;
  bool _opponentDone = false;
  StreamSubscription? _listener;
  Completer<MatchInfo>? _rematchCont;
  int _lastAdvancedRound = 0;

  // RTDB 공유 보드 노드: boards/<id>/r<round>, 이벤트: .../events
  DatabaseReference? _boardRef;
  StreamSubscription? _boardSub;
  StreamSubscription? _eventsSub;

  static int _randomSeed() {
    // 0..<2^62 비음수 (Swift Int64.random(0...Int64.max) 대응, 비트패턴 동일 해석).
    final r = Random();
    return (r.nextInt(1 << 31) << 31) | r.nextInt(1 << 31);
  }

  // MARK: - 인증

  Future<void> _ensureSignedIn() => _signIn();

  // MARK: - 매칭

  @override
  Future<MatchInfo> find(Difficulty difficulty, RaceRule rule) async {
    await _ensureSignedIn();
    final claimed =
        await _scanAndClaim(difficulty, rule, hostRoom: null);
    if (claimed != null) return claimed.$1;
    return _hostAndWait(
        difficulty: difficulty,
        roomCode: null,
        rule: rule,
        rescan: true,
        waitTimeout: 90);
  }

  /// 대기열에서 같은 난이도·규칙 방을 찾아 점유. hostRoom이 있으면 그보다 '큰' id만(타이브레이커).
  Future<(MatchInfo, DocumentReference<Map<String, dynamic>>)?> _scanAndClaim(
      Difficulty difficulty, RaceRule rule,
      {DocumentReference<Map<String, dynamic>>? hostRoom}) async {
    final waiting = await _matches
        .where('status', isEqualTo: 'waiting')
        .where('difficulty', isEqualTo: difficulty.label)
        .limit(8)
        .get();
    for (final doc in waiting.docs) {
      if (hostRoom != null && doc.id.compareTo(hostRoom.id) <= 0) continue;
      if (_isStale(doc)) continue;
      final info = await _claim(doc, desiredRule: rule);
      if (info != null) return (info, _matches.doc(doc.id));
    }
    return null;
  }

  /// 오래 방치된(호스트 사라진) 유령 대기방인지. 180초 초과면 유령. createdAt 미기록이면 최신 취급.
  bool _isStale(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final ts = doc.data()['createdAt'];
    if (ts is! Timestamp) return false;
    return DateTime.now().difference(ts.toDate()) > const Duration(seconds: 180);
  }

  // MARK: - 방 코드(친구 초대)

  @override
  Future<MatchInfo> createRoom(Difficulty difficulty, RaceRule rule) async {
    await _ensureSignedIn();
    final code = RoomCode.generate();
    onRoomCode?.call(code);
    return _hostAndWait(
        difficulty: difficulty,
        roomCode: code,
        rule: rule,
        rescan: false,
        waitTimeout: null);
  }

  @override
  Future<MatchInfo> joinRoom(String code) async {
    final normalized = RoomCode.normalize(code);
    return _firstResult(const Duration(seconds: 10), () async {
      await _ensureSignedIn();
      return _lookupRoom(normalized);
    });
  }

  Future<MatchInfo> _lookupRoom(String normalized) async {
    var sawRoom = false;
    for (var attempt = 0; attempt < 4; attempt++) {
      final found = await _matches
          .where('roomCode', isEqualTo: normalized)
          .limit(8)
          .get();
      if (found.docs.isNotEmpty) sawRoom = true;
      for (final doc in found.docs) {
        final info = await _claim(doc);
        if (info != null) return info;
      }
      if (attempt < 3) {
        await Future.delayed(const Duration(milliseconds: 700));
      }
    }
    throw sawRoom ? MatchError.roomFull : MatchError.roomNotFound;
  }

  /// work를 실행하되 timeout 안에 안 끝나면 roomNotFound를 던진다(멈춘 읽기 대비).
  Future<MatchInfo> _firstResult(
      Duration timeout, Future<MatchInfo> Function() work) {
    final completer = Completer<MatchInfo>();
    work().then((info) {
      if (!completer.isCompleted) completer.complete(info);
    }).catchError((Object e) {
      if (!completer.isCompleted) completer.completeError(e);
    });
    Future.delayed(timeout, () {
      if (!completer.isCompleted) completer.completeError(MatchError.roomNotFound);
    });
    return completer.future;
  }

  /// 대기 매치를 점유한다. 쿼리 스냅샷 데이터를 그대로 쓰고 update로만 점유(named DB 안정 경로).
  Future<MatchInfo?> _claim(QueryDocumentSnapshot<Map<String, dynamic>> doc,
      {RaceRule? desiredRule}) async {
    final d = doc.data();
    final status = d['status'] as String?;
    final rule = RaceRuleX.fromKey(d['rule'] as String?);
    final docKind = d['kind'] as String? ?? 'mine';
    final hostId = d['hostId'] as String?;
    final seedNum = d['seed'];
    final diffRaw = d['difficulty'] as String?;
    final difficulty =
        diffRaw == null ? null : Difficulty.fromLabel(diffRaw);
    final safeR = (d['safeR'] as num?)?.toInt();
    final safeC = (d['safeC'] as num?)?.toInt();

    if (docKind != kind ||
        status != 'waiting' ||
        (desiredRule != null && desiredRule != rule) ||
        hostId == null ||
        hostId == myId ||
        seedNum is! num ||
        difficulty == null ||
        safeR == null ||
        safeC == null) {
      return null;
    }

    final ref = _matches.doc(doc.id);
    await ref.update({
      'status': 'active',
      'guestId': myId,
      'players.$myId': {
        'name': _myName,
        'title': _myTitle,
        'progress': 0,
        'phase': 'playing',
        'elapsed': 0,
        'score': 0,
      },
    });

    _matchRef = ref;
    _opponentId = hostId;
    _isHost = false;
    _round = 0;
    final players = d['players'] as Map?;
    final host = players?[hostId] as Map?;
    return MatchInfo(
      seed: seedNum.toInt(),
      difficulty: difficulty,
      safeR: safeR,
      safeC: safeC,
      opponentName: (host?['name'] as String?) ?? '상대',
      rule: rule,
      opponentTitle: (host?['title'] as String?) ?? '',
    );
  }

  /// 새 매치(status=waiting)를 만들고 상대 입장을 기다린다. 세 경로(입장/재훑기/타임아웃)를 경쟁.
  Future<MatchInfo> _hostAndWait({
    required Difficulty difficulty,
    required String? roomCode,
    required RaceRule rule,
    required bool rescan,
    required int? waitTimeout,
  }) async {
    final seed = _randomSeed();
    final safeR = difficulty.rows ~/ 2;
    final safeC = difficulty.cols ~/ 2;
    final ref = _matches.doc();
    _matchRef = ref;

    final data = <String, dynamic>{
      'status': 'waiting',
      'kind': kind,
      'difficulty': difficulty.label,
      'seed': seed,
      'safeR': safeR,
      'safeC': safeC,
      'rule': rule.ruleKey,
      'hostId': myId,
      'createdAt': FieldValue.serverTimestamp(),
      'players': {
        myId: {
          'name': _myName,
          'title': _myTitle,
          'progress': 0,
          'phase': 'playing',
          'elapsed': 0,
          'score': 0,
        }
      },
    };
    if (roomCode != null) data['roomCode'] = roomCode;
    await ref.set(data);

    final completer = Completer<MatchInfo>();

    // (A) 내 방에 상대가 입장(status=active)하면 내가 호스트.
    final sub = ref.snapshots().listen((snap) {
      if (completer.isCompleted) return;
      final d = snap.data();
      if (!snap.exists || d == null) return;
      if (d['status'] != 'active') return;
      final gid = d['guestId'] as String?;
      if (gid == null) return;
      final players = d['players'] as Map?;
      final guest = players?[gid] as Map?;
      _listener?.cancel();
      _listener = null;
      _matchRef = ref;
      _opponentId = gid;
      _isHost = true;
      _round = 0;
      completer.complete(MatchInfo(
        seed: seed,
        difficulty: difficulty,
        safeR: safeR,
        safeC: safeC,
        opponentName: (guest?['name'] as String?) ?? '상대',
        rule: rule,
        isHost: true,
        opponentTitle: (guest?['title'] as String?) ?? '',
      ));
    }, onError: (Object e) {
      if (!completer.isCompleted) {
        _listener?.cancel();
        _listener = null;
        completer.completeError(e);
      }
    });
    _listener = sub;

    // (B) 큐 재훑기 — 동시에 방을 만든 다른 호스트를 점유(작은 id만 점유자).
    if (rescan) {
      Future(() async {
        while (!completer.isCompleted) {
          await Future.delayed(const Duration(seconds: 1));
          if (completer.isCompleted) return;
          (MatchInfo, DocumentReference<Map<String, dynamic>>)? claimed;
          try {
            claimed = await _scanAndClaim(difficulty, rule, hostRoom: ref);
          } catch (_) {
            continue;
          }
          if (claimed == null) continue;
          if (completer.isCompleted) {
            // 호스트 리스너가 이미 이김 → 방금 점유한 방을 대기로 복구.
            await claimed.$2.update({
              'status': 'waiting',
              'guestId': FieldValue.delete(),
              'players.$myId': FieldValue.delete(),
            });
          } else {
            // 내가 게스트로 매칭됨(_claim이 상태 세팅). 내 대기방 정리.
            completer.complete(claimed.$1);
            await _listener?.cancel();
            _listener = null;
            await ref.delete();
          }
          return;
        }
      });
    }

    // (C) 타임아웃 → 무한 로딩 대신 noOpponent.
    if (waitTimeout != null) {
      Future.delayed(Duration(seconds: waitTimeout), () async {
        if (completer.isCompleted) return;
        await _listener?.cancel();
        _listener = null;
        await ref.delete();
        _matchRef = null;
        completer.completeError(MatchError.noOpponent);
      });
    }

    return completer.future;
  }

  // MARK: - 재대결

  @override
  Future<MatchInfo> rematch() async {
    final ref = _matchRef;
    final oppId = _opponentId;
    if (ref == null || oppId == null) throw MatchError.opponentLeft;

    _listener?.cancel();
    _listener = null;
    _boardSub?.cancel();
    _boardSub = null;
    _eventsSub?.cancel();
    _eventsSub = null;
    _boardRef = null; // 다음 라운드 노드(r<round>)로 다시 만든다

    final targetRound = _round + 1;
    await ref.update({
      'players.$myId.rematch': targetRound,
      'players.$myId.progress': 0,
      'players.$myId.phase': 'playing',
      'players.$myId.elapsed': 0,
      'players.$myId.score': 0,
    });

    final completer = Completer<MatchInfo>();
    _rematchCont = completer;
    _listener = ref.snapshots().listen((snap) {
      if (!snap.exists) {
        _resolveRematchError(MatchError.opponentLeft);
        return;
      }
      final d = snap.data();
      final players = d?['players'] as Map?;
      final opp = players?[oppId] as Map?;
      if ((opp?['phase'] as String?) == 'left') {
        _resolveRematchError(MatchError.opponentLeft);
        return;
      }
      final curRound = (d?['round'] as num?)?.toInt() ?? 0;
      if (curRound >= targetRound) {
        final info = _matchInfo(d, oppId);
        if (info != null) _resolveRematch(info);
        return;
      }
      final mine = (players?[myId] as Map?)?['rematch'] as num?;
      final theirs = opp?['rematch'] as num?;
      if (_isHost &&
          _lastAdvancedRound < targetRound &&
          mine?.toInt() == targetRound &&
          theirs?.toInt() == targetRound) {
        _lastAdvancedRound = targetRound;
        _advanceRound(ref, oppId, targetRound);
      }
    }, onError: (Object e) => _resolveRematchError(e));

    final info = await completer.future;
    _round = targetRound;
    _opponentDone = false;
    return info;
  }

  void _resolveRematch(MatchInfo info) {
    final c = _rematchCont;
    if (c == null || c.isCompleted) return;
    _rematchCont = null;
    _listener?.cancel();
    _listener = null;
    c.complete(info);
  }

  void _resolveRematchError(Object error) {
    final c = _rematchCont;
    if (c == null || c.isCompleted) return;
    _rematchCont = null;
    _listener?.cancel();
    _listener = null;
    c.completeError(error);
  }

  void _advanceRound(DocumentReference<Map<String, dynamic>> ref, String oppId,
      int round) {
    final seed = _randomSeed();
    ref.update({
      'round': round,
      'seed': seed,
      'players.$myId.rematch': FieldValue.delete(),
      'players.$oppId.rematch': FieldValue.delete(),
      'players.$myId.progress': 0,
      'players.$myId.phase': 'playing',
      'players.$myId.elapsed': 0,
      'players.$myId.score': 0,
      'players.$oppId.progress': 0,
      'players.$oppId.phase': 'playing',
      'players.$oppId.elapsed': 0,
      'players.$oppId.score': 0,
    });
  }

  MatchInfo? _matchInfo(Map<String, dynamic>? d, String oppId) {
    if (d == null) return null;
    final seedNum = d['seed'];
    final diffRaw = d['difficulty'] as String?;
    final difficulty =
        diffRaw == null ? null : Difficulty.fromLabel(diffRaw);
    final safeR = (d['safeR'] as num?)?.toInt();
    final safeC = (d['safeC'] as num?)?.toInt();
    if (seedNum is! num ||
        difficulty == null ||
        safeR == null ||
        safeC == null) {
      return null;
    }
    final rule = RaceRuleX.fromKey(d['rule'] as String?);
    final players = d['players'] as Map?;
    final opp = players?[oppId] as Map?;
    return MatchInfo(
      seed: seedNum.toInt(),
      difficulty: difficulty,
      safeR: safeR,
      safeC: safeC,
      opponentName: (opp?['name'] as String?) ?? '상대',
      rule: rule,
      isHost: _isHost,
      opponentTitle: (opp?['title'] as String?) ?? '',
    );
  }

  // MARK: - 레이스 동기화

  @override
  void beginRace() {
    final ref = _matchRef;
    if (ref == null) return;
    _listener?.cancel();
    _listener = ref.snapshots().listen((snap) {
      if (!snap.exists) return;
      final d = snap.data();
      final oppId = _opponentId;
      final players = d?['players'] as Map?;
      final opp = oppId == null ? null : players?[oppId] as Map?;
      if (opp != null) {
        if ((opp['phase'] as String?) == 'left') {
          _opponentDone = true;
          onOpponentLeft?.call();
          return;
        }
        final status = OpponentStatus(
          progress: (opp['progress'] as num?)?.toDouble() ?? 0,
          phase: RacerPhase.fromKey(opp['phase'] as String?),
          elapsed: (opp['elapsed'] as num?)?.toInt() ?? 0,
          score: (opp['score'] as num?)?.toInt() ?? 0,
        );
        if (status.phase != RacerPhase.playing) _opponentDone = true;
        onOpponent?.call(status);
      }
    });
    _observeBoardRtdb();
    _observeEventsRtdb();
  }

  DatabaseReference? get _boardNode {
    final id = _matchRef?.id;
    if (id == null) return null;
    return _boardRef ??=
        _rtdb.ref('boards').child(id).child('r$_round');
  }

  void _observeBoardRtdb() {
    final node = _boardNode;
    if (node == null) return;
    _boardSub?.cancel();
    _boardSub = node.onValue.listen((event) {
      final onBoard = onRemoteBoard;
      if (onBoard == null) return;
      final snap = event.snapshot;
      final board = SharedBoardState();
      // children 순회로 인덱스 획득(RTDB의 배열 변환에 영향받지 않게).
      for (final child in snap.child('reveal').children) {
        final idx = int.tryParse(child.key ?? '');
        if (idx != null) board.revealed.add(idx);
      }
      for (final child in snap.child('exploded').children) {
        final idx = int.tryParse(child.key ?? '');
        if (idx != null) board.exploded.add(idx);
      }
      for (final child in snap.child('flags').children) {
        final idx = int.tryParse(child.key ?? '');
        if (idx == null) continue;
        if (child.value == myId) {
          board.myFlags.add(idx);
        } else {
          board.oppFlags.add(idx);
        }
      }
      onBoard(board);
    });
  }

  void _observeEventsRtdb() {
    final node = _boardNode?.child('events');
    if (node == null) return;
    _eventsSub?.cancel();
    _eventsSub = node.onChildAdded.listen((event) {
      final dict = event.snapshot.value;
      if (dict is! Map) return;
      final from = dict['from'] as String?;
      if (from == null || from == myId) return;
      final type = dict['type'] as String?;
      switch (type) {
        case 'ping':
          final idx = (dict['idx'] as num?)?.toInt();
          if (idx != null) onPing?.call(idx);
        case 'penalty':
          onFlagPenalty?.call();
      }
    });
  }

  @override
  void report(
      {required double progress,
      required RacerPhase phase,
      required int elapsed,
      required int score}) {
    final ref = _matchRef;
    if (ref == null) return;
    ref.update({
      'players.$myId.progress': progress,
      'players.$myId.phase': phase.key,
      'players.$myId.elapsed': elapsed,
      'players.$myId.score': score,
    });
  }

  // MARK: - 지뢰 대결(공유 보드) 동기화 — RTDB

  @override
  void pushReveal(List<int> safe, List<int> exploded) {
    if (safe.isEmpty && exploded.isEmpty) return;
    final node = _boardNode;
    if (node == null) return;
    final updates = <String, Object?>{};
    for (final idx in safe) {
      updates['reveal/$idx'] = true;
    }
    for (final idx in exploded) {
      updates['exploded/$idx'] = true;
    }
    node.update(updates);
  }

  @override
  void pushFlag(int index, {required bool set}) {
    final node = _boardNode;
    if (node == null) return;
    node.child('flags').child('$index').set(set ? myId : null);
  }

  @override
  void pushPing(int index) {
    final node = _boardNode?.child('events');
    if (node == null) return;
    node.push().set({'from': myId, 'type': 'ping', 'idx': index});
  }

  @override
  void pushFlagPenalty() {
    final node = _boardNode?.child('events');
    if (node == null) return;
    node.push().set({'from': myId, 'type': 'penalty'});
  }

  @override
  void leave() {
    _resolveRematchError(MatchError.cancelled);
    _listener?.cancel();
    _listener = null;
    final ref = _matchRef;
    final isLast = _opponentId == null || _opponentDone;

    _boardSub?.cancel();
    _boardSub = null;
    _eventsSub?.cancel();
    _eventsSub = null;
    // RTDB를 실제로 쓴 적이 있을 때만(=보드 노드가 생겼을 때만) 정리한다.
    // 매칭만 하고 레이스를 시작하지 않았으면 보드 노드가 없어 지울 것도 없다.
    if (isLast && ref != null && _databaseOverride != null) {
      _databaseOverride!.ref('boards').child(ref.id).remove();
    }
    _boardRef = null;

    if (ref != null) {
      if (isLast) {
        ref.delete();
      } else {
        ref.update({'players.$myId.phase': 'left'});
      }
    }
    _matchRef = null;
    _opponentId = null;
    _opponentDone = false;
  }
}
