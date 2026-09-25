# Warm Wood Theme Source

The repository owner confirmed permission to reuse the selected resources from
the locally supplied Tencent Chinese Chess APK (`com.tencent.qqgame.xq`,
version `4.4.6.2`). The APK itself is not included in this repository.

- Board: `Bundle-BattleBase`, sprite `M_ChessBoard_Board_JDXQ`.
- Pieces: `Bundle-BattleBase` atlas `xiangqiqizi_01`; the fourteen standard red
  and black Xiangqi piece sprites are exported separately and atlas-rotated
  entries are restored to their display orientation.
- Background textures: two wood textures from `Bundle-ThemeDefault`.
- Sound effects: `luozi` (move), `tizi` (capture), and `goerror` (invalid
  move) from `Bundle-BattleBase`. They are attenuated by 4 dB and low-pass
  filtered at 6 kHz before being encoded as MP3 for this app.

The bundled font and unrelated application resources were not copied. This
theme is an independent option and does not imply affiliation with Tencent.
