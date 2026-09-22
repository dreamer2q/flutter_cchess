import 'dart:typed_data';

class RC4 {
  Uint8List s = Uint8List(256);
  int x = 0;
  int y = 0;

  // 用空密钥初始化密码流生成器
  RC4.initZero() {
    int i, j;
    int uc;
    x = y = j = 0;
    for (i = 0; i < 256; i++) {
      s[i] = i;
    }
    for (i = 0; i < 256; i++) {
      j = (j + s[i]) & 255;
      uc = s[i];
      s[i] = s[j];
      s[j] = uc;
    }
  }

  // 生成密码流的下一个字节
  int nextByte() {
    int uc;
    x = (x + 1) & 255;
    y = (y + s[x]) & 255;
    uc = s[x];
    s[x] = s[y];
    s[y] = uc;
    return s[(s[x] + s[y]) & 255];
  }

  // 生成密码流的下四个字节
  int nextLong() {
    int uc0, uc1, uc2, uc3;
    uc0 = nextByte();
    uc1 = nextByte();
    uc2 = nextByte();
    uc3 = nextByte();
    return uc0 + (uc1 << 8) + (uc2 << 16) + (uc3 << 24);
  }
}

class ZobristStruct {
  int dwKey = 0;
  int dwLock0 = 0;
  int dwLock1 = 0;

  ZobristStruct.initZero();

  ZobristStruct.initRC4(RC4 rc4) {
    dwKey = rc4.nextLong();
    dwLock0 = rc4.nextLong();
    dwLock1 = rc4.nextLong();
  }

  void xor(ZobristStruct zobr) {
    dwKey ^= zobr.dwKey;
    dwLock0 ^= zobr.dwLock0;
    dwLock1 ^= zobr.dwLock1;
  }

  void xor2(ZobristStruct zobr1, ZobristStruct zobr2) {
    dwKey ^= zobr1.dwKey ^ zobr2.dwKey;
    dwLock0 ^= zobr1.dwLock0 ^ zobr2.dwLock0;
    dwLock1 ^= zobr1.dwLock1 ^ zobr2.dwLock1;
  }
}

class Zobrist {
  ZobristStruct player = ZobristStruct.initZero();
  List<List<ZobristStruct>> table /*[14][256] */ = List.generate(
    14,
    (_) => List.generate(256, (_) => ZobristStruct.initZero()),
  );

  Zobrist.initZobrist() {
    RC4 rc4 = RC4.initZero();
    player = ZobristStruct.initRC4(rc4);
    for (int i = 0; i < 14; i++) {
      for (int j = 0; j < 256; j++) {
        table[i][j] = ZobristStruct.initRC4(rc4);
      }
    }
  }
}

class MoveStruct {
  int wmv = 0;
  int ucpcCaptured = 0;
  bool ucbCheck = false;
  int dwKey = 0;

  void set(int mv, int pcCaptured, bool bCheck, int dwKey_) {
    wmv = mv;
    ucpcCaptured = pcCaptured;
    ucbCheck = bCheck;
    dwKey = dwKey_;
  }
}
