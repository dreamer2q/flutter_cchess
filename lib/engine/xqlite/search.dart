import 'dart:math';

import 'package:flutter_cchess/engine/xqlite/position.dart';

class HashItem {
  int ucDepth = 0;
  int ucFlag = 0;
  int svl = 0;
  int wmv = 0;
  int wReserved = 0;
  int dwLock0 = 0;
  int dwLock1 = 0;
}

class BookItem {
  int dwLock = 0;
  int wmv = 0;
  int wvl = 0;
}

class XqwlSearch {
  static const bool GEN_CAPTURE = true;
  static const bool NO_NULL = true;

  late List<int> nHistoryTable; // [65536] 历史表
  late List<List<int>> mvKillers; //[LIMIT_DEPTH][2] 杀手走法表
  late List<HashItem> hashTable; // [HASH_SIZE] 置换表
  late List<BookItem> bookTable; // [BOOK_SIZE] 开局库
  int nBookSize = 0; // 开局库大小
  int mvResult = 0; // 电脑走的棋
  final Stopwatch _searchClock = Stopwatch();
  int _maxThinkMs = 0;

  final pos = XqwlPosition();

  bool get _timeLimitReached =>
      _maxThinkMs > 0 && _searchClock.elapsedMilliseconds >= _maxThinkMs;

  // "qsort"按历史表排序的比较函数
  int _compareHistory(int lpmv1, int lpmv2) {
    return nHistoryTable[lpmv2] - nHistoryTable[lpmv1];
  }

  Future<void> loadBook() async {
    // TODO 加载开局库
    // sizeOf(BookItem);
    // rootBundle.loadStructuredBinaryData(key, (data) => null);
  }

  int searchBook() {
    if (nBookSize == 0) {
      return 0;
    }
    return 0;
  }

  int probeHash(int vlAlpha, int vlBeta, int nDepth, List<int> mv) {
    bool bMate; // 杀棋标志：如果是杀棋，那么不需要满足深度条件
    HashItem hsh;
    hsh = hashTable[pos.zobr.dwKey & (XqwlPosition.HASH_SIZE - 1)];
    if (hsh.dwLock0 != pos.zobr.dwLock0 || hsh.dwLock1 != pos.zobr.dwLock1) {
      mv[0] = 0;
      return -XqwlPosition.MATE_VALUE;
    }
    mv[0] = hsh.wmv;
    bMate = false;
    if (hsh.svl > XqwlPosition.WIN_VALUE) {
      if (hsh.svl > XqwlPosition.BAN_VALUE) {
        return -XqwlPosition.MATE_VALUE; // 可能导致搜索的不稳定性，立刻退出，但最佳着法可能拿到
      }
      hsh.svl -= pos.nDistance;
      bMate = true;
    } else if (hsh.svl < -XqwlPosition.WIN_VALUE) {
      if (hsh.svl > -XqwlPosition.BAN_VALUE) {
        return -XqwlPosition.MATE_VALUE;
      }
      hsh.svl += pos.nDistance;
      bMate = true;
    }
    if (hsh.ucDepth >= nDepth || bMate) {
      if (hsh.ucFlag == XqwlPosition.HASH_BETA) {
        return (hsh.svl >= vlBeta ? hsh.svl : -XqwlPosition.MATE_VALUE);
      } else if (hsh.ucFlag == XqwlPosition.HASH_ALPHA) {
        return (hsh.svl <= vlAlpha ? hsh.svl : -XqwlPosition.MATE_VALUE);
      }
      return hsh.svl;
    }
    return -XqwlPosition.MATE_VALUE;
  }

  // 保存置换表项
  void recordHash(int nFlag, int vl, int nDepth, int mv) {
    HashItem hsh;
    hsh = hashTable[pos.zobr.dwKey & (XqwlPosition.HASH_SIZE - 1)];
    if (hsh.ucDepth > nDepth) {
      return;
    }
    hsh.ucFlag = nFlag;
    hsh.ucDepth = nDepth;
    if (vl > XqwlPosition.WIN_VALUE) {
      if (mv == 0 && vl <= XqwlPosition.BAN_VALUE) {
        return; // 可能导致搜索的不稳定性，并且没有最佳着法，立刻退出
      }
      hsh.svl = vl + pos.nDistance;
    } else if (vl < -XqwlPosition.WIN_VALUE) {
      if (mv == 0 && vl >= -XqwlPosition.BAN_VALUE) {
        return; // 同上
      }
      hsh.svl = vl - pos.nDistance;
    } else {
      hsh.svl = vl;
    }
    hsh.wmv = mv;
    hsh.dwLock0 = pos.zobr.dwLock0;
    hsh.dwLock1 = pos.zobr.dwLock1;
    hashTable[pos.zobr.dwKey & (XqwlPosition.HASH_SIZE - 1)] = hsh;
  }

  // MVV/LVA每种子力的价值
  static const cucMvvLva /*[24]*/ = [
    0, 0, 0, 0, 0, 0, 0, 0, //
    5, 1, 1, 3, 4, 3, 2, 0,
    5, 1, 1, 3, 4, 3, 2, 0,
  ];

  // 求MVV/LVA值
  int mvvLva(int mv) {
    return (cucMvvLva[pos.ucpcSquares[XqwlPosition.getDst(mv)]] << 3) -
        cucMvvLva[pos.ucpcSquares[XqwlPosition.getSrc(mv)]];
  }

  /// "qsort"按MVV/LVA值排序的比较函数
  int compareMvvLva(int lpmv1, int lpmv2) {
    return mvvLva(lpmv2) - mvvLva(lpmv1);
  }

  // // "qsort"按历史表排序的比较函数
  // static int CompareHistory(const void *lpmv1, const void *lpmv2) {
  //   return Search.nHistoryTable[*(int *) lpmv2] - Search.nHistoryTable[*(int *) lpmv1];
  // }

  void setBestMove(int mv, int nDepth) {
    List<int> lpmvKillers;
    nHistoryTable[mv] += nDepth * nDepth;
    lpmvKillers = mvKillers[pos.nDistance];
    if (lpmvKillers[0] != mv) {
      lpmvKillers[1] = lpmvKillers[0];
      lpmvKillers[0] = mv;
    }
  }

  int searchQuiesc(int vlAlpha, int vlBeta) {
    if (_timeLimitReached) return pos.evaluate();
    int i, nGenMoves;
    int vl, vlBest;
    List<int> mvs = [];
    // 一个静态搜索分为以下几个阶段

    // 1. 检查重复局面
    vl = pos.repStatus();
    if (vl != 0) {
      return pos.repValue(vl);
    }

    // 2. 到达极限深度就返回局面评价
    if (pos.nDistance == XqwlPosition.LIMIT_DEPTH) {
      return pos.evaluate();
    }

    // 3. 初始化最佳值
    vlBest = -XqwlPosition.MATE_VALUE; // 这样可以知道，是否一个走法都没走过(杀棋)

    if (pos.inCheck()) {
      // 4. 如果被将军，则生成全部走法
      nGenMoves = pos.generateMoves(mvs);
      // qsort(mvs, nGenMoves, sizeof(int), CompareHistory);
      mvs.sort(_compareHistory);
    } else {
      // 5. 如果不被将军，先做局面评价
      vl = pos.evaluate();
      if (vl > vlBest) {
        vlBest = vl;
        if (vl >= vlBeta) {
          return vl;
        }
        if (vl > vlAlpha) {
          vlAlpha = vl;
        }
      }

      // 6. 如果局面评价没有截断，再生成吃子走法
      nGenMoves = pos.generateMoves(mvs, GEN_CAPTURE);
      // qsort(mvs, nGenMoves, sizeof(int), CompareMvvLva);
      mvs.sort(compareMvvLva);
    }

    // 7. 逐一走这些走法，并进行递归
    for (i = 0; i < nGenMoves; i++) {
      if (pos.makeMove(mvs[i])) {
        vl = -searchQuiesc(-vlBeta, -vlAlpha);
        pos.undoMakeMove();
        if (_timeLimitReached) break;

        // 8. 进行Alpha-Beta大小判断和截断
        if (vl > vlBest) {
          // 找到最佳值(但不能确定是Alpha、PV还是Beta走法)
          vlBest = vl; // "vlBest"就是目前要返回的最佳值，可能超出Alpha-Beta边界
          if (vl >= vlBeta) {
            // 找到一个Beta走法
            return vl; // Beta截断
          }
          if (vl > vlAlpha) {
            // 找到一个PV走法
            vlAlpha = vl; // 缩小Alpha-Beta边界
          }
        }
      }
    }

    // 9. 所有走法都搜索完了，返回最佳值
    return vlBest == -XqwlPosition.MATE_VALUE
        ? pos.nDistance - XqwlPosition.MATE_VALUE
        : vlBest;
  }

  /// 超出边界(Fail-Soft)的Alpha-Beta搜索过程
  int searchFull(int vlAlpha, int vlBeta, int nDepth, [bool bNoNull = false]) {
    if (_timeLimitReached) return pos.evaluate();
    int nHashFlag, vl, vlBest;
    int mv, mvBest, nNewDepth;
    List<int> mvHash = [0];
    // SortStruct Sort = SortStruct.init(this);
    // 一个Alpha-Beta完全搜索分为以下几个阶段

    // int i, nGenMoves, pcCaptured = 0;
    // int vl, vlBest, mvBest;
    // final List<int> mvs = [];
    // 一个Alpha-Beta完全搜索分为以下几个阶段

    // 1. 到达水平线，则返回局面评价值
    if (nDepth <= 0) {
      return searchQuiesc(vlAlpha, vlBeta);
    }

    // 1-1. 检查重复局面(注意：不要在根节点检查，否则就没有走法了)
    vl = pos.repStatus();
    if (vl != 0) {
      return pos.repValue(vl);
    }

    // 1-2. 到达极限深度就返回局面评价
    if (pos.nDistance == XqwlPosition.LIMIT_DEPTH) {
      return pos.evaluate();
    }

    // 1-3. 尝试置换表裁剪，并得到置换表走法
    vl = probeHash(vlAlpha, vlBeta, nDepth, mvHash);
    if (vl > -XqwlPosition.MATE_VALUE) {
      return vl;
    }

    // 1-4. 尝试空步裁剪(根节点的Beta值是"MATE_VALUE"，所以不可能发生空步裁剪)
    if (!bNoNull && !pos.inCheck() && pos.nullOkey()) {
      pos.nullMove();
      vl = -searchFull(
        -vlBeta,
        1 - vlBeta,
        nDepth - XqwlPosition.NULL_DEPTH - 1,
        NO_NULL,
      );
      pos.undoNullMove();
      if (_timeLimitReached) return pos.evaluate();
      if (vl >= vlBeta) {
        return vl;
      }
    }

    // 2. 初始化最佳值和最佳走法
    nHashFlag = XqwlPosition.HASH_ALPHA;
    vlBest = -XqwlPosition.MATE_VALUE; // 这样可以知道，是否一个走法都没走过(杀棋)
    mvBest = 0; // 这样可以知道，是否搜索到了Beta走法或PV走法，以便保存到历史表

    // 3. 初始化走法排序结构
    SortStruct sort = SortStruct.init(this, mvHash[0]);

    // 4. 逐一走这些走法，并进行递归
    while ((mv = sort.next()) != 0) {
      if (pos.makeMove(mv)) {
        // 将军延伸
        nNewDepth = pos.inCheck() ? nDepth : nDepth - 1;
        // PVS
        if (vlBest == -XqwlPosition.MATE_VALUE) {
          vl = -searchFull(-vlBeta, -vlAlpha, nNewDepth);
        } else {
          vl = -searchFull(-vlAlpha - 1, -vlAlpha, nNewDepth);
          if (vl > vlAlpha && vl < vlBeta) {
            vl = -searchFull(-vlBeta, -vlAlpha, nNewDepth);
          }
        }
        pos.undoMakeMove();
        if (_timeLimitReached) break;

        // 5. 进行Alpha-Beta大小判断和截断
        if (vl > vlBest) {
          // 找到最佳值(但不能确定是Alpha、PV还是Beta走法)
          vlBest = vl; // "vlBest"就是目前要返回的最佳值，可能超出Alpha-Beta边界
          if (vl >= vlBeta) {
            // 找到一个Beta走法
            nHashFlag = XqwlPosition.HASH_BETA;
            mvBest = mv; // Beta走法要保存到历史表
            break; // Beta截断
          }
          if (vl > vlAlpha) {
            // 找到一个PV走法
            nHashFlag = XqwlPosition.HASH_PV;
            mvBest = mv; // PV走法要保存到历史表
            vlAlpha = vl; // 缩小Alpha-Beta边界
          }
        }
      }
    }

    // 5. 所有走法都搜索完了，把最佳走法(不能是Alpha走法)保存到历史表，返回最佳值
    if (vlBest == -XqwlPosition.MATE_VALUE) {
      // 如果是杀棋，就根据杀棋步数给出评价
      return pos.nDistance - XqwlPosition.MATE_VALUE;
    }
    // 记录到置换表
    recordHash(nHashFlag, vlBest, nDepth, mvBest);
    if (mvBest != 0) {
      // 如果不是Alpha走法，就将最佳走法保存到历史表
      setBestMove(mvBest, nDepth);
    }

    return vlBest;
  }

  // 根节点的Alpha-Beta搜索过程
  int searchRoot(int nDepth) {
    int vl, vlBest, mv, nNewDepth;
    Random random = Random();
    vlBest = -XqwlPosition.MATE_VALUE;
    SortStruct sort = SortStruct.init(this, mvResult);

    while ((mv = sort.next()) != 0) {
      if (_timeLimitReached) break;
      if (pos.makeMove(mv)) {
        nNewDepth = pos.inCheck() ? nDepth : nDepth - 1;
        if (vlBest == -XqwlPosition.MATE_VALUE) {
          vl = -searchFull(
            -XqwlPosition.MATE_VALUE,
            XqwlPosition.MATE_VALUE,
            nNewDepth,
            NO_NULL,
          );
        } else {
          vl = -searchFull(-vlBest - 1, -vlBest, nNewDepth);
          if (vl > vlBest) {
            vl = -searchFull(
              -XqwlPosition.MATE_VALUE,
              -vlBest,
              nNewDepth,
              NO_NULL,
            );
          }
        }
        pos.undoMakeMove();
        if (_timeLimitReached) break;
        if (vl > vlBest) {
          vlBest = vl;
          mvResult = mv;
          if (vlBest > -XqwlPosition.WIN_VALUE &&
              vlBest < XqwlPosition.WIN_VALUE) {
            vlBest +=
                random.nextInt(XqwlPosition.RANDOM_MASK + 1) -
                random.nextInt(XqwlPosition.RANDOM_MASK + 1);
          }
        }
      }
    }
    recordHash(XqwlPosition.HASH_PV, vlBest, nDepth, mvResult);
    setBestMove(mvResult, nDepth);
    return vlBest;
  }

  // 迭代加深搜索过程
  void searchMain({
    int maxDepth = XqwlPosition.LIMIT_DEPTH,
    int maxThinkMs = 5000,
  }) {
    _maxThinkMs = maxThinkMs;
    _searchClock
      ..reset()
      ..start();
    List<int> mvs = [];

    // 初始化
    nHistoryTable = List.filled(65536, 0); // 清空历史表
    hashTable = List.generate(XqwlPosition.HASH_SIZE, (_) => HashItem());
    mvKillers = List.generate(
      XqwlPosition.LIMIT_DEPTH,
      (_) => List.filled(2, 0),
    );

    pos.nDistance = 0; // 初始步数

    // 搜索开局库
    // Search.mvResult = SearchBook();
    // if (Search.mvResult != 0) {
    //   pos.MakeMove(Search.mvResult);
    //   if (pos.RepStatus(3) == 0) {
    //     pos.UndoMakeMove();
    //     return;
    //   }
    //   pos.UndoMakeMove();
    // }

    // 检查是否只有唯一走法
    int vl = 0;
    int nGenMoves = pos.generateMoves(mvs);
    for (int i = 0; i < nGenMoves; i++) {
      if (pos.makeMove(mvs[i])) {
        pos.undoMakeMove();
        mvResult = mvs[i];
        vl++;
      }
    }
    if (vl == 1) {
      _searchClock.stop();
      return;
    }

    // 迭代加深过程
    for (int i = 1; i <= maxDepth && i <= XqwlPosition.LIMIT_DEPTH; i++) {
      // int vl = searchFull(-XqwlPosition.MATE_VALUE, XqwlPosition.MATE_VALUE, i);
      vl = searchRoot(i);
      // 搜索到杀棋，就终止搜索
      if (vl > XqwlPosition.WIN_VALUE || vl < -XqwlPosition.WIN_VALUE) {
        break;
      }
      // 超过一秒，就终止搜索
      if (_timeLimitReached) break;
    }
    _searchClock.stop();
  }
}

class SortStruct {
  // 走法排序阶段
  static const int PHASE_HASH = 0;
  static const int PHASE_KILLER_1 = 1;
  static const int PHASE_KILLER_2 = 2;
  static const int PHASE_GEN_MOVES = 3;
  static const int PHASE_REST = 4;

  int mvHash = 0;
  int mvKiller1 = 0;
  int mvKiller2 = 0;
  int nPhase = 0;
  int nIndex = 0;
  int nGenMoves = 0;
  List<int> mvs = [];
  final XqwlSearch s;

  SortStruct.init(this.s, int mvHash_) {
    mvHash = mvHash_;
    mvKiller1 = s.mvKillers[s.pos.nDistance][0];
    mvKiller2 = s.mvKillers[s.pos.nDistance][1];
    nPhase = PHASE_HASH;
  }

  int next() {
    int mv;
    // switch (nPhase)
    // "nPhase"表示着法启发的若干阶段，依次为：

    // 0. 置换表着法启发，完成后立即进入下一阶段；
    if (PHASE_HASH >= nPhase) {
      nPhase = PHASE_KILLER_1;
      if (mvHash != 0) {
        return mvHash;
      }
    }

    // 技巧：这里没有"break"，表示"switch"的上一个"case"执行完后紧接着做下一个"case"，下同

    // 1. 杀手着法启发(第一个杀手着法)，完成后立即进入下一阶段；
    if (PHASE_KILLER_1 >= nPhase) {
      nPhase = PHASE_KILLER_2;
      if (mvKiller1 != mvHash && mvKiller1 != 0 && s.pos.legalMove(mvKiller1)) {
        return mvKiller1;
      }
    }

    // 2. 杀手着法启发(第二个杀手着法)，完成后立即进入下一阶段；
    if (PHASE_KILLER_2 >= nPhase) {
      nPhase = PHASE_GEN_MOVES;
      if (mvKiller2 != mvHash && mvKiller2 != 0 && s.pos.legalMove(mvKiller2)) {
        return mvKiller2;
      }
    }

    // 3. 生成所有着法，完成后立即进入下一阶段；
    if (PHASE_GEN_MOVES >= nPhase) {
      nPhase = PHASE_REST;
      nGenMoves = s.pos.generateMoves(mvs);
      // qsort(mvs, nGenMoves, sizeof(int), CompareHistory);
      mvs.sort(s._compareHistory);
      nIndex = 0;
    }

    // 4. 对剩余着法做历史表启发；
    if (PHASE_REST >= nPhase) {
      while (nIndex < nGenMoves) {
        mv = mvs[nIndex];
        nIndex++;
        if (mv != mvHash && mv != mvKiller1 && mv != mvKiller2) {
          return mv;
        }
      }
    }

    // 5. 没有着法了，返回零。
    return 0;
  }
}
