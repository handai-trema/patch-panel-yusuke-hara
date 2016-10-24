#第3回課題レポート課題1
##目次
* [課題内容](##課題内容)
* [解答](##解答)
    * [サブコマンドの仕様](###サブコマンドの仕様)
        * [1.ポートのミラーリング](####1.ポートのミラーリング)
        * [2.パッチとポートミラーリングの一覧](####2.パッチとポートミラーリングの一覧)
        * [3.ミラーリングの削除](####3.ミラーリングの削除)
    * [bin/patch\_panelの変更](###bin/patch_panelの変更)
    * [lib/patch\_panel.rbの変更](###lib/patch\_panel.rbの変更)
    * [動作確認](###動作確認)

##課題内容
パッチパネルに機能を追加しよう。

授業で説明したパッチの追加と削除以外に、以下の機能をパッチパネルに追加してください。  

1. ポートのミラーリング
2. パッチとポートミラーリングの一覧


それぞれ patch_panel のサブコマンドとして実装してください。

なお 1 と 2 以外にも機能を追加した人には、ボーナス点を加点します。
##解答
###サブコマンドの仕様
####1.ポートのミラーリング
ポートのミラーリングを行う．例えばポートAをポートBにミラーリングすると，ポートAに入っていくパケットとポートAからでていくパケットをコピーしてポートBに出力する．  
#####使い方
```
patch_panel mirror dpid port mirror_port  
```
dpid:データパスID  
port:ミラーリングされるポート番号  
mirror\_port:ミラーリングしたパケットの出力ポート番号


####2.パッチとポートミラーリングの一覧
現在設定されているパッチとミラーリングポートを出力する．  
#####使い方
```patch_panel show dpid  ```  
dpid:データパスID  
#####出力
設定されているパッチの組と，ミラーリングされているポートと
ミラーリングの出力先ポートの一覧を出力する．  
例えばポート1とポート2がパッチされており，ポート2がミラーリングされており，その出力先がポート3の場合は以下のように出力される．

```
:patch  
1:2  
:mirror  
2 -> 3  
```
####3.ミラーリングの削除
設定されているミラーリングを削除する．
#####使い方
```patch_panel delete_mirror dpid port mirror_port  ```  
dpid:データパスID  
port:ミラーリングされるポート番号  
mirror\_port:ミラーリングしたパケットの出力ポート番号
#####出力
引数に指定したミラーリングが存在しないその旨を表示する．
正常にミラーリングが削除された場合は何も出力されない．


###bin/patch\_panelの変更
サブコマンドを追加するためにbin/patch\_panelを変更する．
基本的には既にあるサブコマンド`create`などの記述を参考にする．
以下にcreateの記述を示す．
<pre class=“prettyprint linenums:”>  desc 'Creates a new patch'
  arg_name 'dpid port#1 port#2'
  command :create do |c|
    c.desc 'Location to find socket files'
    c.flag [:S, :socket\_dir], default\_value: Trema::DEFAULT\_SOCKET\_DIR
    c.action do |\_global\_options, options, args|
      dpid = args[0].hex
      port1 = args[1].to\_i
      port2 = args[2].to\_i
      Trema.trema\_process('PatchPanel',options[:socket\_dir]).controller.
        create\_patch(dpid, port1, port2)
    end
  end
</pre>

- 1行目 desc:コマンドの説明
- 2行目 argname:引数名
- 3行目 :サブコマンド名
- 7~9行目 :引数の数だけ適宜記述
- 11行目 :lib/patch\_panel.rbのメソッド名を記述

サブコマンドmirror,show,delete\_mirrorの3つ分追加する．  
ただし，show,delete\_mirrorコマンドは出力を行うので11行目以下を以下のように変更する．

```
      str = Trema.trema_process('PatchPanel', options[:socket_dir]).controller.
        それぞれのメソッド名
      print str
```
それぞれのメソッドでは出力する文字列を戻り値として返すので，
返された文字列を出力する．

###lib/patch\_panel.rbの変更
ミラーリングを管理する変数にはハッシュ関数を用いる．スイッチのIDであるデータパスIDをキーとし，ミラーリングのポートの組を要素とした配列をオブジェクトに持つインスタンス変数@mirrorを定義する．これをstartメソッドに記述する．

```
  def start(_args)
    @patch = Hash.new {|hash,key| hash[key] = []  }
    @mirror = Hash.new {|hash,key| hash[key] = []  }
    logger.info 'PatchPanel started.'
  end
```
これ以降はそれぞれのサブコマンド毎の追加箇所を示す．
####1.ポートのミラーリング
ポートのミラーリングのメソッドはmirrorメソッドと，そこから呼び出されるadd\_mirrorメソッドである．  
mirrorメソッドではインスタンス変数@mirrorにミラーリングするポート，出力先ポートの順になっている配列を追加する．  
次にミラーリングするポートとパッチされているポートを検索する．
これは，ミラーリングを行うにはミラーリングポートから出ていくパケットと入ってくるパケットを知る必要があり，ミラーリングポートに入ってくるパケットはパッチされているポートからのパケットであるからである．  
パッチされているポート番号は変数patch\_portに入る．もしパッチされているポートがない場合はnilが入る．そしてデータパスID，ミラーリングするポート番号，前述のpatch\_port,出力先ポートを引数にadd\_mirrorメソッドが呼ばれる．

```
  def mirror(dpid, port, mirror_port)
    @mirror[dpid] << [port,mirror_port]
    patch_port =nil
    @patch[dpid].each do |port_c, port_d|
      if port_c == port then
        patch_port = port_d
      elsif port_d == port then
        patch_port = port_c
      end
    end
    add_mirror dpid,port,patch_port,mirror_port
  end
```
add\_mirrorメソッドではflow modメッセージを送る．
ミラーリングポートとそのパッチポート宛のパケットに対する
flow modを削除し，新たにミラーリングポート，またはパッチポートと同時にミラー先ポートにもパケットを送るようなflow modを追加する．
ただし，patch\_portがnilの場合はパッチポートに関する処理は行わないようになっている．


```
def add_mirror(dpid, port, patch_port, mirror)
    send_flow_mod_delete(dpid, match: Match.new(in_port: port))
    send_flow_mod_delete(dpid, match: Match.new(in_port: patch_port)) if ! patch_port.nil?
    send_flow_mod_add(dpid,
                      match: Match.new(in_port: port),
                      actions: [SendOutPort.new(patch_port), SendOutPort.new(mirror),])
    send_flow_mod_add(dpid,
                      match: Match.new(in_port: patch_port),
                      actions: [SendOutPort.new(port), SendOutPort.new(mirror),]) if ! patch_port.nil?
  end
```

####2.パッチとポートミラーリングの一覧
パッチの組が保存されているインスタンス変数@patchとミラーリングの情報が保存されているインスタンス変数@mirrorからパッチとミラーリングの情報を取り出し，表示用の文字列に変換する．
その文字列を戻り値として返している．

```
  def show_ports(dpid)
    str = ""
    str += ":patch\n"
    @patch[dpid].each do |port_c, port_d|
      str += "#{port_c}:#{port_d}\n"
    end
    str += ":mirror\n"
    @mirror[dpid].each do |port_c, port_d|
      str += "#{port_c} -> #{port_d}\n"
    end
    return str
  end

```
####3.ミラーリングの削除
ミラーリングを削除する．@mirrorからミラーリングポートとその出力先の組を削除する．もしそのような要素がなかった場合はその旨を示す文字列を返し，終了する．次にミラーリングの追加と同じようにパッチポートを検索する．パッチが設定されていない場合は変数はnilとなる．
データパスID，ミラーリングポート，検索したパッチポートを引数にして
delete\_mirror\_flow\_entryメソッドを呼び出す．

```
  def delete_mirror(dpid, port, mirror)
    return "No such mirror\n" if @mirror[dpid].delete([port, mirror]).nil?
    patch_port =nil
    @patch[dpid].each do |port_c, port_d|
      if port_c == port then
        patch_port = port_d
      elsif port_d == port then
        patch_port = port_c
      end
    end
    delete_mirror_flow_entry dpid,port,patch_port
    return ""
  end
```
delete\_mirror\_flow\_entryメソッドでは今までのミラーリングポートとそのパッチポート宛のパケットに対する
flow modを削除する．その後，それぞれのポート宛のパケットは自身のポートのみにパケットを送るようなflow modを追加する．こうすることでミラーリングを削除する．

```
def delete_mirror_flow_entry(dpid, port, patch_port)
    send_flow_mod_delete(dpid, match: Match.new(in_port: port))
    send_flow_mod_delete(dpid, match: Match.new(in_port: patch_port)) if ! patch_port.nil?
    send_flow_mod_add(dpid,
                      match: Match.new(in_port: port),
                      actions: SendOutPort.new(patch_port))
    send_flow_mod_add(dpid,
                      match: Match.new(in_port: patch_port),
                      actions: SendOutPort.new(port)) if ! patch_port.nil?
  end
```

###動作確認
以下のような構成で動作確認を行った．ホストの設定においてpromisc trueオプションを付けることで，自分宛てでないパケットでも受け取れるようにしている．

```
vswitch('patch_panel') { datapath_id 0xabc }

vhost ('host1') {
ip '192.168.0.1'
promisc true

}
vhost ('host2') {
ip '192.168.0.2'
promisc true

}

vhost ('host3') {
ip '192.168.0.3'
promisc true
}

link 'patch_panel', 'host1'
link 'patch_panel', 'host2'
link 'patch_panel', 'host3'

```
以下の手順で動作確認を行った．

```
1.ポート1と2にパッチを作成する
2.ポート1をポート3にミラーリングする
3.パッチとポートミラーリングの一覧を表示する
4.ポート1から2にパケットを送る
5.ポート2から1にパケットを送る 

6.ポート1から3へのミラーリングを削除する
7.パッチとポートミラーリングの一覧を表示する
8.ポート1から2にパケットを送る
9.ポート2から1にパケットを送る

10.ポート1と2のパッチを削除する
11.パッチとポートミラーリングの一覧を表示する
12.ポート1から2にパケットを送る
13.ポート2から1にパケットを送る
```
5,9,13を実行した後にそれぞれのポートのパケット送受信確認を行う．  
それでは以下1~5の実行結果を示す．

```
$ ./bin/patch_panel  create 0xabc 1 2
$ ./bin/patch_panel mirror 0xabc 1 3
$ ./bin/patch_panel  show 0xabc
:patch
1:2
:mirror
1 -> 3
$ ./bin/trema send_packets --source host1 --dest host2
$ ./bin/trema send_packets --source host2 --dest host1
$ ./bin/trema show_stats host1
Packets sent:
  192.168.0.1 -> 192.168.0.2 = 1 packet
Packets received:
  192.168.0.2 -> 192.168.0.1 = 1 packet
$ ./bin/trema show_stats host2
Packets sent:
  192.168.0.2 -> 192.168.0.1 = 1 packet
Packets received:
  192.168.0.1 -> 192.168.0.2 = 1 packet
$ ./bin/trema show_stats host3
Packets received:
  192.168.0.1 -> 192.168.0.2 = 1 packet
  192.168.0.2 -> 192.168.0.1 = 1 packet
```
showコマンドでパッチとミラーリングが正しく表示されていることがわかる．また，パッチを行ったポート1と2間でパケットが送受信できている事がわかる．また，ポート3ではポート1のパケットをミラーリングできていることがわかる．  

次に6~9の実行結果を示す．

```
$ ./bin/patch_panel delete_mirror 0xabc 1 3
$ ./bin/patch_panel show 0xabc
:patch
1:2
:mirror
$ ./bin/trema send_packets --source host1 --dest host2
$ ./bin/trema send_packets --source host2 --dest host1
$ ./bin/trema show_stats host1
Packets sent:
  192.168.0.1 -> 192.168.0.2 = 2 packets
Packets received:
  192.168.0.2 -> 192.168.0.1 = 2 packets
$ ./bin/trema show_stats host2
Packets sent:
  192.168.0.2 -> 192.168.0.1 = 2 packets
Packets received:
  192.168.0.1 -> 192.168.0.2 = 2 packets
$ ./bin/trema show_stats host3
Packets received:
  192.168.0.1 -> 192.168.0.2 = 1 packet
  192.168.0.2 -> 192.168.0.1 = 1 packet
```
showコマンドでミラーリングが削除されていると正しく表示されている．
また，ポート1,2間でパケットの送受信を行った結果，ポート1,2間ではパケットの送受信ができているが，ポート3の送受信履歴は先程と変わらないのでパケットを受信しておらず，ミラーリングが削除されていることが確認できる．

最後に10~13の実行結果を示す．

```
$ ./bin/patch_panel delete 0xabc 1 2
$ ./bin/patch_panel show 0xabc
:patch
:mirror
$ ./bin/trema send_packets --source host1 --dest host2
$ ./bin/trema send_packets --source host2 --dest host1
$ ./bin/trema show_stats host1
Packets sent:
  192.168.0.1 -> 192.168.0.2 = 3 packets
Packets received:
  192.168.0.2 -> 192.168.0.1 = 2 packets
$ ./bin/trema show_stats host2
Packets sent:
  192.168.0.2 -> 192.168.0.1 = 3 packets
Packets received:
  192.168.0.1 -> 192.168.0.2 = 2 packets
$ ./bin/trema show_stats host3
Packets received:
  192.168.0.1 -> 192.168.0.2 = 1 packet
  192.168.0.2 -> 192.168.0.1 = 1 packet
```
パッチを削除し，その後ポート1,2間でパケットの送受信を行っているが，パケットの受信ができておらず，正しくパッチの削除ができていることがわかる．







