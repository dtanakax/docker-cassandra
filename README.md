![cassandra 2.1.4](https://img.shields.io/badge/cassandra-2.1.4-brightgreen.svg) ![License MIT](https://img.shields.io/badge/license-MIT-blue.svg)

# docker-cassandra

### Base Docker Image

[tanaka0323:java7](https://bitbucket.org/tanaka0323/docker-java7)

### 説明

Cassandra Dockerコンテナイメージです。

[Cassandraとは？](http://cassandra.apache.org/)  
[Dockerとは？](https://docs.docker.com/)  
[Docker Command Reference](https://docs.docker.com/reference/commandline/cli/)

### 使用方法

git pull後に

    $ cd docker-cassandra

イメージ作成

    $ docker build -t tanaka0323/cassandra .

### シングルノード構成時の使用例

1. cass1というコンテナ名で起動

        $ docker run -d -name cass1 tanaka0323/cassandra

2. cqlshコンソールへ接続

        $ docker exec -ti cass1 cqlsh

    下記の様な文字列が表示されます。このコンソール上でCQLを使用しデータ操作を行います。

        $ Connected to CassCluster at 127.0.0.1:9042.
        $ [cqlsh 5.0.1 | Cassandra 2.1.4 | CQL spec 3.2.0 | Native protocol v3]
        $ Use HELP for help.
        $ cqlsh>

3. スクリプトを使用してテーブルを事前に作成

    例として、テーブルを作成しデータを追加するCQLを作成します。

        $ mkdir -p /data/cassandra/scripts
        $ vi /data/cassandra/scripts/init.cql

    このスクリプトでは、Keyspaceを定義し、テーブルの作成とデータを追加を行います。

        CREATE KEYSPACE test_keyspace WITH REPLICATION = {'class': 'SimpleStrategy', 'replication_factor': 1};
        USE test_keyspace;

         CREATE TABLE test_table (
          id text,
          test_value text,
          PRIMARY KEY (id)
         );

        INSERT INTO test_table (id, test_value) VALUES ('1', 'one');

        INSERT INTO test_table (id, test_value) VALUES ('2', 'two');

        INSERT INTO test_table (id, test_value) VALUES ('3', 'three');

        SELECT * FROM test_table;

    このスクリプトが置かれたホストディレクトリをコンテナへマウント、そしてcqlshを実行し、データベースを初期化します。

        $ docker run -d --name cas -v /data/cassandra/scripts:/data -ti tanaka0323/cassandra
        $ docker exec -ti cas bash -c 'cqlsh -f /data/init.cql'

         id | test_value
        ----+------------
          3 |      three
          2 |        two
          1 |        one

        (3 rows)

### 3 ノードクラスタ構成時の使用例

1. 3つのコンテナを起動

    下記の--linkオプションではcass2,cass3のコンテナとcass1のコンテナをリンクさせノードへ追加しています。  
    TOKEN環境変数によりユニークなトークン番号をそれぞれ割り当てます。
    (注:デフォルト9042ポートの場合のみ有効)

        $ docker run -d --name cass1 -e TOKEN=1 tanaka0323/cassandra
        $ docker run -d --name cass2 -e TOKEN=2 --link cass1:cass1 tanaka0323/cassandra
        $ docker run -d --name cass3 -e TOKEN=3 --link cass1:cass1 tanaka0323/cassandra

2. cass1へログインしnodetoolを使用しステータスを確認

        $ docker exec -ti cass1 nodetool status

        Datacenter: datacenter1
        =======================
        Status=Up/Down
        |/ State=Normal/Leaving/Joining/Moving
        --  Address       Load       Tokens  Owns (effective)  Host ID                               Rack
        UN  172.17.0.166  51.29 KB   256     67.0%             8cf43307-02f0-431c-9015-706da6d92adb  rack1
        UN  172.17.0.167  51.31 KB   256     66.9%             ccd86997-29e0-4c69-9abb-b16974d455bc  rack1
        UN  172.17.0.168  51.3 KB    256     66.1%             f2136f9c-59ab-480e-b52e-a908ca3169cf  rack1

3. cass1コンテナでデータを作成

    cqlshを起動します。

        $ docker exec -ti cass1 cqlsh

        Connected to CassCluster at 127.0.0.1:9042.
        [cqlsh 5.0.1 | Cassandra 2.1.4 | CQL spec 3.2.0 | Native protocol v3]
        Use HELP for help.
        cqlsh>

    以下のCQLをペーストします。

        create keyspace demo with replication = {'class':'SimpleStrategy', 'replication_factor':2};
        use demo;
        create table names ( id int primary key, name text );
        insert into names (id,name) values (1, 'gibberish');
        quit

4. cass2コンテナへ接続し同じデータが作成されているか確認

        $ docker exec -ti cass2 cqlsh

        Connected to CassCluster at 127.0.0.1:9042.
        [cqlsh 5.0.1 | Cassandra 2.1.4 | CQL spec 3.2.0 | Native protocol v3]
        Use HELP for help.
        cqlsh>

    以下のCQLをペーストします。

        select * from demo.names;

         id | name
        ----+-----------
          1 | gibberish

        (1 rows)

### Snitch (スニッチ) によるノードのネットワーク位置設定

Cassandra の Snitch (スニッチ) は、ノードのネットワークの位置を設定します。
これを利用して、データのレプリケーションを行うことができます。

    docker run -d --name cass1 -e SNITCH=GossipingPropertyFileSnitch -e DATACENTER=dcname -e RACK=rackname tanaka0323/cassandra

Snitch には、以下のものがあります。

- SimpleSnitch  
    単一のデータセンター時に使用します。

- PropertyFileSnitch  
    ラックとデータセンターによりノードの位置を決定します。  

- Dynamic snitching  
    多数のレプリカからの使用履歴を読み取り、履歴に基づいて最高のパフォーマンスを発揮するレプリカを選択すように監視します。  

- RackInferringSnitch  
    ラックとデータセンターによりノードの位置を決定します。  
    [PropertyFileSnitchとの違い](http://docs.datastax.com/en/cassandra/1.2/cassandra/architecture/architectureSnitchRackInf_c.html)

- GossipingPropertyFileSnitch  
    新規ノードを追加する際に、Gossipプロトコルを使用して全てのノードを自動的に更新します。  

- EC2Snitch  
    Amazon EC2環境で、単一サーバーでの運用時に設定します。  

- EC2MultiRegionSnitch  
    Amazon EC2環境で、複数サーバーでの運用時に設定します。  

### OpsCenterを使用したモニタリング

1. 3ノードクラスタを起動

    ここでは[Fig設定サンプル](https://bitbucket.org/tanaka0323/fig-examples)を使用します。

        cd fig-examples/cass_3cluster
        fig up

2. OpsCenterコンテナを起動

        cd fig-examples/opscenter
        fig up

3. OpsCenterに接続＆設定

    * ブラウザで[http://ops.dockerhost.io:8888/](http://ops.dockerhost.io:8888/)を開きます。(注:あらかじめhostsファイルでDNS名を指定しておく必要があります。)
    * "Use Existing Cluster"ボタンを押して起動した3ノードクラスタの内の一つのIPを入力すると、(docker-scripts/ips.shスクリプトでIPアドレスを取得することができます。) 自動的にクラスタ構成を取得し設定が行われます。
    * "0 of 3 agents connected"メッセージが表示されているポップアップ画面の中の"Fix"をクリックします。
    * さらにポップアップ画面の中の"Enter Credentials"をクリックしusername <code>opscenter</code>、password <code>opscenter</code>を入力し、"Done"をクリックします。
    * "All agents connected"メッセージが表示されたら完了です。

### 環境変数

- <code>CASSANDRA_CONFIG</code>Cassandra設定ファイルディレクトリ
- <code>CLUSTERNAME</code>クラスタ名
- <code>TOKEN</code>トークン番号 多ノードクラスタ構成時ユニークな番号を指定
- <code>SNITCH</code>スニッチ
- <code>DATACENTER</code>データセンター名
- <code>RACK</code>ラック名

### Figでの使用方法

[Figとは？](http://www.fig.sh/)  

[設定ファイル記述例](https://bitbucket.org/tanaka0323/fig-examples)

### License

The MIT License
Copyright (c) 2015 Daisuke Tanaka

以下に定める条件に従い、本ソフトウェアおよび関連文書のファイル（以下「ソフトウェア」）の複製を取得するすべての人に対し、ソフトウェアを無制限に扱うことを無償で許可します。これには、ソフトウェアの複製を使用、複写、変更、結合、掲載、頒布、サブライセンス、および/または販売する権利、およびソフトウェアを提供する相手に同じことを許可する権利も無制限に含まれます。

上記の著作権表示および本許諾表示を、ソフトウェアのすべての複製または重要な部分に記載するものとします。

ソフトウェアは「現状のまま」で、明示であるか暗黙であるかを問わず、何らの保証もなく提供されます。ここでいう保証とは、商品性、特定の目的への適合性、および権利非侵害についての保証も含みますが、それに限定されるものではありません。 作者または著作権者は、契約行為、不法行為、またはそれ以外であろうと、ソフトウェアに起因または関連し、あるいはソフトウェアの使用またはその他の扱いによって生じる一切の請求、損害、その他の義務について何らの責任も負わないものとします。