# コード探索のルール

コードの場所を探す段階でファイルを全文読みしない。先に行番号を特定して、必要な範囲だけ読む。

1. **構造の把握**: `ast-grep outline <path>` で型・関数・クラスとその行番号の一覧を取る。
   Go / TypeScript / JavaScript / Python / Java / Rust / C# などは対応済み。
   Nix・シェル・Lua・Scala は outline ルールがなく `nothing found` になるので 2 へ進む。
2. **文字列検索**: `rg -n <pattern>`。前後の文脈が必要な場合も `-C 3` 程度に留める。
3. **構造検索**: 識別子ではなく「この形のコード」を探すときは
   `ast-grep run -p '<pattern>' -l <lang>`。`$NAME` / `$$$` でメタ変数を書ける。
4. **読む**: 1〜3 で得た行番号を使い、Read の `offset` / `limit` か `sed -n 'A,Bp'` で該当範囲のみ読む。

全文読みは、上記で当たりが付かないときとファイル全体を書き換えるときに限る。
