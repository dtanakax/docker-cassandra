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

### シングルノード構成使用例

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

### 3ノードクラスタ構成使用例

1. 3つのコンテナを起動

    下記の--linkオプションではcass2,cass3のコンテナとcass1のコンテナをリンクさせノードへ追加しています。  
    TOKEN環境変数によりユニークなトークン番号をそれぞれ割り当てます。
    (注:デフォルト9042ポートの場合のみ有効)

        $ docker run -d --name cass1 -e TOKEN=1 tanaka0323/cassandra
        $ docker run -d --name cass2 -e TOKEN=2 --link cass1:cass1 tanaka0323/cassandra
        $ docker run -d --name cass3 -e TOKEN=3 --link cass1:cass1 tanaka0323/cassandra

2. cass1へログインしnodetoolを使用しステータスを確認

        $ docker exec -ti cass1 nodetool -h localhost status

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

### Figでの使用方法

[Figとは？](http://www.fig.sh/ "Fidとは？")  

[設定ファイル記述例](https://bitbucket.org/tanaka0323/fig-examples "設定ファイル記述例")

### License

The MIT License
Copyright (c) 2015 Daisuke Tanaka

以下に定める条件に従い、本ソフトウェアおよび関連文書のファイル（以下「ソフトウェア」）の複製を取得するすべての人に対し、ソフトウェアを無制限に扱うことを無償で許可します。これには、ソフトウェアの複製を使用、複写、変更、結合、掲載、頒布、サブライセンス、および/または販売する権利、およびソフトウェアを提供する相手に同じことを許可する権利も無制限に含まれます。

上記の著作権表示および本許諾表示を、ソフトウェアのすべての複製または重要な部分に記載するものとします。

ソフトウェアは「現状のまま」で、明示であるか暗黙であるかを問わず、何らの保証もなく提供されます。ここでいう保証とは、商品性、特定の目的への適合性、および権利非侵害についての保証も含みますが、それに限定されるものではありません。 作者または著作権者は、契約行為、不法行為、またはそれ以外であろうと、ソフトウェアに起因または関連し、あるいはソフトウェアの使用またはその他の扱いによって生じる一切の請求、損害、その他の義務について何らの責任も負わないものとします。