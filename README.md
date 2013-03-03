スクレイピングソフト
============================

scrape - Ruby スクレイピングソフト
----------------------------

Web スクレイピングソフトです。 
ruby 1.9.3p374 にて動作確認しています。
scrape を利用すれば、以下のように html の DOM に対して、擬似ファイルシステムとしてアクセスできます。

    $ ruby command.rb html/index.html
    
    # 実行するとインタラクティブシェルに入る, ls で現在のノードを表示できる
    sp > ls
    
    # html ノードが表示された。
    # >> は以下に複数ノード存在することを示している。
    html >> 
    
    # 下層の DOM へ移動する
    sp > cd html
    
    # 現在の位置を表示する
    sp > pwd
    /html     # /html のノードに現在いることが分かる
    
    # さらに移動する
    sp > ls
    head >>   body >>
    sp > cd body
    
    # info ノードのプロパティを表示できる
    sp > info
    path => /html/body 
    marginheight => 0
    topmargin => 0 
    style => width:950px;

    # 下層の html を全てテキスト表示で出力したい場合
    sp > cat
    ...   # ずらずらと下層の html が出力される

このように、html の DOM ノードに対してファイルシステムのようにアクセスすることが出来ます。

