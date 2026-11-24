-module(dream_pgo_basic_SUITE).

-compile(export_all).

-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").
-include("dream_pgo_internal.hrl").

-define(UUID, <<"727f42a6-e6a0-4223-9b72-6a5eb7436ab5">>).
-define(BIN_UUID, <<114,127,66,166,230,160,66,35,155,114,106,94,183,67,106,181>>).
-define(TXT_UUID, <<"727F42A6-E6A0-4223-9B72-6A5EB7436AB5">>).

all() ->
    [{group, clear}, {group, ssl}].

groups() ->
    [{clear, [], cases()},
     {ssl, [], [int4_range, exceptions, ssl_connect_failure_closes_socket,
                 ssl_ca_file_replaces_default_ca_certificates]},
     {domain_socket, [], [int4_range]}].

cases() ->
    [transaction_returns_value, transaction_aborted_raises,
     exceptions, select, insert_update, text_types,
     rows_as_maps, json_jsonb, types,
     int4_range, ts_range, tstz_range, numerics,
     hstore, records, circle, path, polygon, line,
     line_segment, tid, bit_string, arrays, tsvector,
     query_arity_4, set_parameter, netmask].

init_per_suite(Config) ->
    application:load(pg_types),
    application:set_env(pg_types, json_config, {jsone, [], [{keys, atom}]}),
    Config.

end_per_suite(_Config) ->
    application:stop(dream_pgo),
    ok.

init_per_group(clear, Config) ->
    application:ensure_all_started(dream_pgo),

    {ok, _} = dream_pgo_sup:start_child(dream_pgo_default, #{pool_size => 1,
                                                 port => 5432,
                                                 database => "test",
                                                 user => "test",
                                                 password => "password"}),

    Config;
init_per_group(ssl, Config) ->
    application:ensure_all_started(dream_pgo),
    {ok, _} = dream_pgo_sup:start_child(dream_pgo_default, #{pool_size => 1,
                                                 port => 5434,
                                                 ssl => true,
                                                 ssl_options => [{cacertfile, "../../../../test/certs/ca.crt"}],
                                                 database => "test",
                                                 user => "test",
                                                 password => "password"}),

    Config;
init_per_group(domain_socket, Config) ->
    application:ensure_all_started(dream_pgo),

    {ok, _} = dream_pgo_sup:start_child(dream_pgo_default, #{pool_size => 1,
                                                 port => 5432,
                                                 host => "/tmp/postgresql",
                                                 database => "test",
                                                 user => "test",
                                                 password => "password"}),

    Config.


end_per_group(Group, _Config) when Group =:= ssl ; Group =:= domain_socket ->
    application:stop(dream_pgo),
    dream_pgo_test_utils:clear_types(dream_pgo_default),
    ok;
end_per_group(_, _Config) ->
    dream_pgo:query("drop table tmp"),
    dream_pgo:query("drop table tmp_b"),
    dream_pgo:query("drop table foo"),
    dream_pgo:query("drop table types"),
    dream_pgo:query("drop table numeric_tmp"),
    dream_pgo:query("drop table hstore_tmp"),
    dream_pgo:query("drop extension hstore"),

    application:stop(dream_pgo),

    dream_pgo_test_utils:clear_types(dream_pgo_default),

    ok.

set_parameter(_Config) ->
    ?assertMatch(#{command := set}, dream_pgo:query("SET application_name = 'testset'")),
    ?assertMatch(#{command := select,
                   rows := [{<<"testset">>}]}, dream_pgo:query("SELECT current_setting('application_name')")),

    %% TODO: this should effect parameters in the connection somehow
    %% they are sent by postgres and decoded to update the parameters store don the
    %% conn but a copy of that is in the pool and it isn't updated when this happens

    ok.

int4_range(_Config) ->
    ?assertMatch(#{command := create},
                 dream_pgo:query("create temporary table foo_range (id integer primary key, some_range int4range)")
),

    ?assertMatch(#{rows := [{empty}]},
                 dream_pgo:query("select '[1,1)'::int4range")),

    ?assertMatch(#{rows := [{{{1, 3},
                              {true, false}}}]},
                 dream_pgo:query("select '[1,3)'::int4range")),

    ?assertMatch(#{rows := [{{{1, unbound},
                              {true, false}}}]},
                 dream_pgo:query("select '[1,]'::int4range")),

    ?assertMatch(#{command := insert},
                 dream_pgo:query("insert into foo_range (id, some_range) values (1, $1)", [{4, 12}])),
    ?assertMatch(#{rows := [{1, {{4, 13}, {true, false}}}]},
                 dream_pgo:query("select * from foo_range where id=1")),

    ?assertMatch(#{command := insert},
                 dream_pgo:query("insert into foo_range (id, some_range) values (2, $1)",
                           [{{4, 12}, {true, false}}])),
    ?assertMatch(#{rows := [{2, {{4, 12}, {true, false}}}]},
                 dream_pgo:query("select * from foo_range where id=2")),

    ?assertMatch(#{command := insert},
                 dream_pgo:query("insert into foo_range (id, some_range) values (3, $1)",
                           [{{4, unbound}, {true, false}}])),
    ?assertMatch(#{rows := [{3, {{4, unbound}, {true, false}}}]},
                 dream_pgo:query("select * from foo_range where id=3")),

    ?assertMatch(#{command := insert},
                 dream_pgo:query("insert into foo_range (id, some_range) values (4, $1)",
                           [empty])),
    ?assertMatch(#{rows := [{4, empty}]},
                 dream_pgo:query("select * from foo_range where id=4")).

ts_range(_Config) ->
    ?assertMatch(#{command := create},
                 dream_pgo:query("create temporary table foo_ts_range (id integer primary key, some_range tsrange)")),
    ?assertMatch(#{command := insert},
                  dream_pgo:query("insert into foo_ts_range (id, some_range) values (1, $1)", [{{{2001, 1, 1}, {4, 10, 0}},
                                                                                          {{2001, 1, 1}, {5, 10, 0.0}}}])),
    ?assertMatch(#{rows := [{1, {{{{2001, 1, 1}, {4, 10, 0}}, {{2001, 1, 1}, {5, 10, 0}}},
                                 {true, true}}}]},
                 dream_pgo:query("select * from foo_ts_range order by id asc")),


    ok.

tstz_range(_Config) ->
    ?assertMatch(#{rows := [{{{{{2019,6,22},{8,0,0}}, {{2019,6,22},{9,0,0}}},
                              {true, true}}}]}, dream_pgo:query("SELECT tstzrange('2019-06-22 08:00:00.000+00','2019-06-22 09:00:00.000+00', '[]');")),

    ?assertMatch(#{rows := [{{{{{2019,6,22},{8,0,0}}, {{2019,6,22},{9,0,0}}},
                              {true, false}}}]},dream_pgo:query("SELECT tstzrange('2019-06-22 08:00:00.000+00','2019-06-22 09:00:00.000+00', '[)');")),

    ?assertMatch(#{rows := [{{{{{2019,6,22},{8,0,0}}, infinity},
                              {true, true}}}]},dream_pgo:query("SELECT tstzrange('2019-06-22 08:00:00.000+00','infinity', '[]');")),

    ?assertMatch(#{rows := [{{{'-infinity', infinity},
                              {true, true}}}]}, dream_pgo:query("SELECT tstzrange('-infinity','infinity', '[]');")),

    ?assertMatch(#{command := create},
                 dream_pgo:query("create temporary table foo_tstz_range (id integer primary key, some_range tstzrange)")),
    ?assertMatch(#{command := insert},
                 dream_pgo:query("insert into foo_tstz_range (id, some_range) values (1, $1)", [{{{2001, 1, 1}, {4, 10, 0}},
                                                                                           {{2001, 1, 1}, {5, 10, 0.0}}}])),
    ?assertMatch(#{rows := [{1, {{{{2001, 1, 1}, {4, 10, 0}}, {{2001, 1, 1}, {5, 10, 0}}},
                                 {true, true}}}]},
                 dream_pgo:query("select * from foo_tstz_range order by id asc")),

    ?assertMatch(#{rows := [{{{{{2020,1,1},{0,0,0}},infinity},{true,false}}}]},
                 dream_pgo:query(<<"SELECT tstzrange($1, $2, '[)');">>, [{{2020,1,1},{0,0,0}}, infinity])),

    ?assertMatch(#{rows := [{{{'-infinity',{{2020,1,1},{0,0,0}}},{true,false}}}]},
                 dream_pgo:query(<<"SELECT tstzrange($1, $2, '[)');">>, ['-infinity', {{2020,1,1},{0,0,0}}])),

    ok.

exceptions(_Config) ->
    {error, Reason} = dream_pgo:query("select $1::interval", [none]),
    ?assertMatch("Error encoding type interval. Expected, infinity | '-infinity' | {interval {{Hours::integer(), Minutes::integer(), Seconds::integer()}, Days::integer(), months::integer()}}. Got, none.", lists:flatten(dream_pgo:format_error(Reason))),

    ok.

ssl_connect_failure_closes_socket(_Config) ->
    %% Connect with invalid SSL options to force ssl:connect/3 to fail
    %% after the server accepts the SSL request. Verify the TCP socket
    %% is properly closed and not leaked.
    TcpPortsBefore = [P || P <- erlang:ports(),
                           erlang:port_info(P, name) =:= {name, "tcp_inet"}],
    {error, _} = dream_pgo_handler:open(default,
                                  #{host => "127.0.0.1",
                                    port => 5434,
                                    user => "test",
                                    password => "password",
                                    database => "test",
                                    ssl => true,
                                    ssl_options => [{cacertfile, "/nonexistent/ca.pem"},
                                                    {verify, verify_peer}]}),
    TcpPortsAfter = [P || P <- erlang:ports(),
                          erlang:port_info(P, name) =:= {name, "tcp_inet"}],
    ?assertEqual(length(TcpPortsBefore), length(TcpPortsAfter)),
    ok.

ssl_ca_file_replaces_default_ca_certificates(_Config) ->
    %% The test CA is not in the system list of CA certificates. The
    %% connection succeeds only if the CA file from the caller replaces the
    %% default CA certificates. The host name check stays on.
    {ok, Conn} = dream_pgo_handler:open(default,
                                        #{host => "localhost",
                                          port => 5434,
                                          user => "test",
                                          password => "password",
                                          database => "test",
                                          ssl => true,
                                          ssl_options => [{cacertfile, "../../../../test/certs/ca.crt"}]}),
    dream_pgo_handler:close(Conn),
    ok.

select(_Config) ->
    {error, {Module, Reason}} = dream_pgo:query("select $1", []),
    ?assertEqual("parameters needed for query not equal to number of arguments 1 != 0", Module:format_error(Reason)),
    {error, {Module1, Reason1}} = dream_pgo:query("select $1", [1, 2]),
    ?assertEqual("parameters needed for query not equal to number of arguments 1 != 2", Module1:format_error(Reason1)),
    ?assertMatch(#{rows := [{null}]}, dream_pgo:query("select null")),
    ?assertMatch(#{rows := [{null}]}, dream_pgo:query("select null", [])),
    ?assertMatch(#{rows := [{null}]}, dream_pgo:query("select null")),
    ?assertMatch(#{rows := [{null}]}, dream_pgo:query("select null", [])).

insert_update(_Config) ->
    ?assertMatch(#{command := create},
                             dream_pgo:query("create temporary table foo (id integer primary key, some_text text)")),
    ?assertMatch(#{command := insert},
                  dream_pgo:query("insert into foo (id, some_text) values (1, 'hello')")),
    ?assertMatch(#{command := update},
                  dream_pgo:query("update foo set some_text = 'hello world'")),
    ?assertMatch(#{command := insert}, dream_pgo:query("insert into foo (id, some_text) values (2, 'hello again')")),
    ?assertMatch(#{}, dream_pgo:query("update foo set some_text = 'hello world' where id = 1")),
    ?assertMatch(#{}, dream_pgo:query("update foo set some_text = 'goodbye, all' where id = 3")),
    ?assertMatch(#{rows := [{1, <<"hello world">>}, {2, <<"hello again">>}]},
                  dream_pgo:query("select * from foo order by id asc")),
    ?assertMatch(#{rows := [{1, <<"hello world">>}, {2, <<"hello again">>}]},
                  dream_pgo:query("select id as the_id, some_text as the_text from foo order by id asc")),
    ?assertMatch(#{rows := [{<<"hello world">>, 1}, {<<"hello again">>, 2}]},
                  dream_pgo:query("select some_text, id from foo order by id asc")),
    ?assertMatch(#{rows := [{<<"hello again">>}]}, dream_pgo:query("select some_text from foo where id = 2")),
    ?assertMatch(#{}, dream_pgo:query("select * from foo where id = 3")).

text_types(_Config) ->
    ?assertMatch(#{command := select,rows := [{<<"foo">>}]}, dream_pgo:query("select 'foo'::text")),
    ?assertMatch(#{command := select,rows := [{<<"foo">>}]}, dream_pgo:query("select $1::text", [<<"foo">>])),
    ?assertMatch(#{command := select,rows := [{<<"foo         ">>}]}, dream_pgo:query("select 'foo'::char(12)")),
    ?assertMatch(#{command := select,rows := [{<<"foo         ">>}]}, dream_pgo:query("select $1::char(12)", [<<"foo">>])),
    ?assertMatch(#{command := select,rows := [{<<"foo">>}]}, dream_pgo:query("select 'foo'::varchar(12)")),
    ?assertMatch(#{command := select,rows := [{<<"foo">>}]}, dream_pgo:query("select $1::varchar(12)", [<<"foo">>])),
    ?assertMatch(#{command := select,rows := [{<<"foo">>}]}, dream_pgo:query("select 'foobar'::char(3)")),
    ?assertMatch(#{command := select,rows := [{<<"foo">>}]}, dream_pgo:query("select $1::char(3)", [<<"foobar">>])).

rows_as_maps(_Config) ->
    ?assertMatch(#{command := create},
                 dream_pgo:query("create temporary table foo_1 (id integer primary key, some_text text)")),
    ?assertMatch(#{command := insert},
                 dream_pgo:query("insert into foo_1 (id, some_text) values (1, 'hello')")),

    ?assertMatch(#{command := select,rows := [#{<<"id">> := 1,<<"some_text">> := <<"hello">>}]},
                 dream_pgo:query("select * from foo_1", [], #{decode_opts => [return_rows_as_maps]})).

json_jsonb(_Config) ->
    #{command := create} = dream_pgo:query("create table tmp (id integer primary key, a_json json, b_json jsonb)"),
    #{command := insert} = dream_pgo:query("insert into tmp (id, a_json, b_json) values ($1, $2, $3)",
                                     [3, #{<<"a">> => <<"foo">>}, #{<<"b">> => <<"bar">>}]),

    #{command := select, rows := [{#{b := <<"bar">>}}]} =
        dream_pgo:query("select b_json from tmp where id=3"),

    #{command := select, rows := Rows} =
        dream_pgo:query("select '[{\"a\":\"foo\"},{\"b\":\"bar\"},{\"c\":\"baz\"}]'::json"),
    ?assertMatch([{[#{a := <<"foo">>},
                    #{b := <<"bar">>},
                    #{c := <<"baz">>}]}], Rows).

types(_Config) ->
    ?assertMatch(#{command := create},
                  dream_pgo:query("create table types (id integer primary key, an_integer integer, a_bigint bigint, a_text text, a_uuid uuid, a_bytea bytea, a_real real)")),
    ?assertMatch(#{command := insert},
                  dream_pgo:query("insert into types (id, an_integer, a_bigint, a_text, a_uuid, a_bytea, a_real) values (1, null, null, null, null, null, null)")),
    ?assertMatch(#{rows := [{1, null, null, null, null, null, null}]},
                  dream_pgo:query("select * from types where id = 1")),
    ?assertMatch(#{command := insert},
                  dream_pgo:query("insert into types (id, an_integer, a_bigint, a_text, a_uuid, a_bytea, a_real) values ($1, $2, $3, $4, $5, $6, $7)", [2, null, null, null, null, null, null])),
    ?assertMatch(#{rows := [{2, null, null, null, null, null, null}]},
                  dream_pgo:query("select * from types where id = 2")),
    ?assertMatch(#{command := insert},
                  dream_pgo:query("insert into types (id, an_integer, a_bigint, a_text, a_uuid, a_bytea, a_real) values ($1, $2, $3, $4, $5, $6, $7)",
                            [3, 42, null, null, null, null, null])),
    ?assertMatch(#{command := insert},
                  dream_pgo:query("insert into types (id, an_integer, a_bigint, a_text, a_uuid, a_bytea, a_real) values ($1, $2, $3, $4, $5, $6, $7)",
                            [4, null, 1099511627776, null, null, null, null])),
    ?assertMatch(#{command := insert}, dream_pgo:query("insert into types (id, an_integer, a_bigint, a_text, a_uuid, a_bytea, a_real) values ($1, $2, $3, $4, $5, $6, $7)",
                                                  [6, null, null, <<"And in the end, the love you take is equal to the love you make">>, null, null, null])),
    ?assertMatch(#{command := insert}, dream_pgo:query("insert into types (id, an_integer, a_bigint, a_text, a_uuid, a_bytea, a_real) values ($1, $2, $3, $4, $5, $6, $7)",
                                                  [7, null, null, null, ?UUID, null, null])),
    ?assertMatch(#{command := insert}, dream_pgo:query("insert into types (id, an_integer, a_bigint, a_text, a_uuid, a_bytea, a_real) values ($1, $2, $3, $4, $5, $6, $7)",
                                                  [21, null, null, null, <<236,0,0,208,169,204,65,147,163,9,107,147,233,112,253,222>>, null, null])),
    ?assertMatch(#{command := insert}, dream_pgo:query("insert into types (id, an_integer, a_bigint, a_text, a_uuid, a_bytea, a_real) values ($1, $2, $3, $4, $5, $6, $7)",
                                                  [8, null, null, null, null, <<"deadbeef">>, null])),
    ?assertMatch(#{command := insert}, dream_pgo:query("insert into types (id, an_integer, a_bigint, a_text, a_uuid, a_bytea, a_real) values ($1, $2, $3, $4, $5, $6, $7)",
                                                  [9, null, null, null, null, null, 3.1415])),
    ?assertMatch(#{command := insert}, dream_pgo:query("insert into types (id, an_integer, a_bigint, a_text, a_uuid, a_bytea, a_real) values ($1, $2, $3, $4, $5, $6, $7)",
                                                  [19, null, null, null, null, null, 3.0])),
    ?assertMatch(#{command := insert}, dream_pgo:query("insert into types (id, an_integer, a_bigint, a_text, a_uuid, a_bytea, a_real) values ($1, $2, $3, $4, $5, $6, $7)",
                                                  [10, 42, 1099511627776, <<"And in the end, the love you take is equal to the love you make">>, ?BIN_UUID, <<"deadbeef">>, 3.1415])),


    ?assertMatch(#{command := insert}, dream_pgo:query("insert into types (id, an_integer, a_bigint, a_text, a_uuid, a_bytea, a_real) values ($1, $2, $3, $4, $5, $6, $7)", [101, null, null, null, null, "deadbeef", null])),

    R = dream_pgo:query("select * from types where id = 10"),
    ?assertMatch(#{command := select, rows := [_Row]}, R),
    #{command := select, rows := [Row]} = R,
    ?assertMatch({10, 42, 1099511627776, <<"And in the end, the love you take is equal to the love you make">>, _UUID, <<"deadbeef">>, _Float}, Row),
    {10, 42, 1099511627776, <<"And in the end, the love you take is equal to the love you make">>, UUID, <<"deadbeef">>, Float} = Row,
    ?assertMatch(?BIN_UUID, UUID),
    ?assert(Float > 3.1413),
    ?assert(Float < 3.1416),

    R1 = dream_pgo:query("select * from types where id = $1", [10]),
    ?assertMatch(#{command := select, rows := [_Row1]}, R1),
    #{command := select, rows := [Row1]} = R1,
    ?assertMatch({10, 42, 1099511627776, <<"And in the end, the love you take is equal to the love you make">>, _UUID, <<"deadbeef">>, _Float}, Row1),
    {10, 42, 1099511627776, <<"And in the end, the love you take is equal to the love you make">>, UUID1, <<"deadbeef">>, Float1} = Row1,
    ?assertMatch(?BIN_UUID, UUID1),
    ?assert(Float1 > 3.1413),
    ?assert(Float1 < 3.1416),
    ?assertMatch(#{command := insert},
                 dream_pgo:query("insert into types (id, an_integer, a_bigint, a_text, a_uuid, a_bytea, a_real) values ($1, $2, $3, $4, $5, $6, $7)",
                           [11, null, null, null, null, <<"deadbeef">>, null])),
    ?assertMatch(#{command := insert, rows := [{15}]},
                 dream_pgo:query("insert into types (id, an_integer, a_bigint, a_text, a_uuid, a_bytea, a_real) values ($1, $2, $3, $4, $5, $6, $7) RETURNING id",
                           [15, null, null, null, null, <<"deadbeef">>, null])),


    R2 = dream_pgo:query("select * from types where id = $1", [11]),
    ?assertMatch(#{command := select, rows := [_Row2]}, R2),
    #{command := select, rows := [Row2]} = R2,
    ?assertMatch({11, null, null, null, null, <<"deadbeef">>, null}, Row2),

    ?assertMatch(#{command := insert}, dream_pgo:query("insert into types (id, an_integer, a_bigint, a_text, a_uuid, a_bytea, a_real) values ($1, $2, $3, $4, $5, $6, $7)",
                                                 [199, null, null, null, <<"00000000-0000-0000-0000-000000000000">>, null, null])),

    ?assertMatch(#{command := insert}, dream_pgo:query("insert into types (id, an_integer, a_bigint, a_text, a_uuid, a_bytea, a_real) values ($1, $2, $3, $4, $5, $6, $7)",
                                                 [16, null, null, null, ?UUID, null, null])),
    ?assertMatch(#{command := insert}, dream_pgo:query("insert into types (id, an_integer, a_bigint, a_text, a_uuid, a_bytea, a_real) values ($1, $2, $3, $4, $5, $6, $7)",
                                                 [17, null, null, ?TXT_UUID, null, null, null])),
    ?assertMatch(#{command := insert}, dream_pgo:query("insert into types (id, an_integer, a_bigint, a_text, a_uuid, a_bytea, a_real) values ($1, $2, $3, $4, $5, $6, $7)",
                                                 [18, null, null, ?TXT_UUID, null, null, null])),


    R3 = dream_pgo:query("select a_text from types where id IN ($1, $2) order by id", [17, 18]),
    ?assertMatch(#{command := select, rows := [_Row17, _Row18]}, R3),
    #{command := select, rows := [Row17, Row18]} = R3,
    ?assertMatch({?TXT_UUID}, Row17),
    ?assertMatch({?TXT_UUID}, Row18).

numerics(_Config) ->
    BasicQuery = "select $1::numeric",
    ?assertMatch(#{rows := [{1}]}, dream_pgo:query(BasicQuery, [1])),
    ?assertMatch(#{rows := [{-1}]}, dream_pgo:query(BasicQuery, [-1])),
    ?assertMatch(#{rows := [{1.1}]}, dream_pgo:query(BasicQuery, [1.1])),
    ?assertMatch(#{rows := [{-1.1}]}, dream_pgo:query(BasicQuery, [-1.1])),
    ?assertMatch(#{rows := [{1.12345}]}, dream_pgo:query(BasicQuery, [1.12345])),
    ?assertMatch(#{rows := [{1.0e-9}]}, dream_pgo:query(BasicQuery, [0.000000001])),
    ?assertMatch(#{rows := [{-1.0e-9}]}, dream_pgo:query(BasicQuery, [-0.000000001])),
    ?assertMatch(#{rows := [{1.0e-10}]}, dream_pgo:query(BasicQuery, [0.0000000001])),
    ?assertMatch(#{rows := [{-1.0e-10}]}, dream_pgo:query(BasicQuery, [-0.0000000001])),
    ?assertMatch(#{rows := [{1.0e-11}]}, dream_pgo:query(BasicQuery, [0.00000000001])),
    ?assertMatch(#{rows := [{-1.0e-11}]}, dream_pgo:query(BasicQuery, [-0.00000000001])),
    ?assertMatch(#{rows := [{1.0e-32}]}, dream_pgo:query(BasicQuery, [1.0e-32])),

    ?assertMatch(#{rows := [{1.0e-32}]}, dream_pgo:query(BasicQuery, [<<"1.0e-32">>])),
    ?assertMatch(#{rows := [{1.0e+32}]}, dream_pgo:query(BasicQuery, [<<"1.0e+32">>])),

    ?assertMatch(#{rows := [{infinity}]}, dream_pgo:query(BasicQuery, [infinity])),
    ?assertMatch(#{rows := [{'-infinity'}]}, dream_pgo:query(BasicQuery, ['-infinity'])),

    #{command := create} = dream_pgo:query("create table numeric_tmp (id integer primary key, a_int integer, a_num numeric,
                                      b_num numeric(5,3))"),
    ?assertMatch(#{command := insert}, dream_pgo:query("insert into numeric_tmp (id, a_int, a_num) values ($1, $2, $3)", [1,1,
                                                                                                                    0.010000001])),

    ?assertMatch(#{command := insert}, dream_pgo:query("insert into numeric_tmp (id, a_int, a_num) values ($1, $2, $3)", [2,1,
                                                                                                                    0.00000000000000000000000000000001])),
    ?assertMatch(#{rows := [{1.0}]}, dream_pgo:query("select a_int::numeric(2, 1) from numeric_tmp where id = 1", [])),
    ?assertMatch(#{rows := [{1.00}]}, dream_pgo:query("select a_int::numeric(3, 1) from numeric_tmp where id = 1", [])),
    ?assertMatch(#{rows := [{0.01}]}, dream_pgo:query("select a_num::numeric(10, 3) from numeric_tmp where id = 1", [])),
    ?assertMatch(#{rows := [{0.01}]}, dream_pgo:query("select a_num::numeric(10, 3) from numeric_tmp where id = 1", [])),

    ?assertMatch(#{rows := [{1.0e-32}]}, dream_pgo:query("select a_num::numeric from numeric_tmp where id = 2", [])).

hstore(_Config) ->
    #{command := create} = dream_pgo:query("CREATE EXTENSION hstore"),
    #{command := create} = dream_pgo:query("create table hstore_tmp (id integer primary key, labels hstore)"),

    ?assertMatch(#{command := insert}, dream_pgo:query("insert into hstore_tmp (id, labels) values ($1, $2)", [1, #{<<"key-1">> => <<"value-1">>, <<"key-2">> => <<"value-2">>}])),
    ?assertMatch(#{command := select,
                   rows := [{1, #{<<"key-1">> := <<"value-1">>, <<"key-2">> := <<"value-2">>}}]},
                 dream_pgo:query("select id, labels from hstore_tmp where id=1")),

    ok.

records(_Config) ->
    dream_pgo:query("DROP TABLE IF EXISTS composite1"),
    #{command := create} = dream_pgo:query("CREATE TABLE composite1 (a int, b text)"),

    ?assertMatch(#{rows := [{{null, 1}}]}, dream_pgo:query("SELECT (NULL, 1)", [])),
    ?assertMatch(#{rows := [{{1, <<"2">>}}]}, dream_pgo:query("SELECT (1, '2')::composite1", [])),
    ?assertMatch(#{rows := [{[{1, <<"2">>}]}]}, dream_pgo:query("SELECT ARRAY[(1, '2')::composite1]", [])),

    ?assertMatch(#{rows := [{{null, <<"2">>}}]},dream_pgo:query("SELECT $1::composite1", [{null, <<"2">>}])),
    ?assertMatch(#{rows := [{{1, <<"2">>}}]},dream_pgo:query("SELECT $1::composite1", [{1, <<"2">>}])),

    ok.

circle(_Config) ->
    ?assertMatch(#{rows := [{#{center := #{x := 1.0,
                                           y := 1.0},
                               radius := 10.0}}]}, dream_pgo:query("SELECT $1::circle", [#{center => #{x => 1,
                                                                                                 y => 1},
                                                                                     radius => 10}])).

path(_Config) ->
    ?assertMatch(#{rows := [{#{open := true,
                               points := [#{x := 1.0, y := 1.0}, #{x := 2.0, y:= 3.0}]}}]},
                 dream_pgo:query("SELECT $1::path", [#{points => [#{x => 1, y => 1}, #{x => 2, y => 3}],
                                                 open => true}])).

polygon(_Config) ->
    ?assertMatch(#{rows := [{#{vertices := [#{x := 1.0, y := 1.0}, #{x := 2.0, y:= 3.0}]}}]},
                 dream_pgo:query("SELECT $1::polygon", [#{vertices => [#{x => 1, y => 1}, #{x => 2, y => 3}]}])).

line(_Config) ->
    ?assertMatch(#{rows := [{#{a := 1.0, b := 2.0, c := 3.0}}]},
                 dream_pgo:query("SELECT $1::line", [#{a => 1, b => 2, c => 3}])).

line_segment(_Config) ->
    ?assertMatch(#{rows := [{#{point1 := #{x := 1.0, y := 1.0}, point2 := #{x := 2.0, y := 3.0}}}]},
                 dream_pgo:query("SELECT $1::lseg", [#{point1 => #{x => 1, y => 1},
                                                 point2 => #{x => 2, y => 3}}])).

tid(_Config) ->
    ?assertMatch(#{rows := [{{1, 2}}]},
                 dream_pgo:query("SELECT $1::tid", [{1, 2}])).

bit_string(_Config) ->
    ?assertMatch(#{rows := [{<<1:1,0:1,1:1,0:1,0:1>>}]},
                 dream_pgo:query("SELECT bit '101'::bit(5)", [])),

    ?assertMatch(#{rows := [{<<1:1,0:1,1:1,0:1,0:1>>}]},
                 dream_pgo:query("SELECT $1::bit(5)", [<<1:1,0:1,1:1>>])),

    ?assertMatch(#{rows := [{<<1:1,1:1,0:1>>}]}, dream_pgo:query("SELECT bit '110' :: varbit", [])).

arrays(_Config) ->
    ?assertMatch(#{rows := [{[<<"s1">>,null]}]}, dream_pgo:query("SELECT $1::text[]", [[<<"s1">>, null]])),
    ?assertMatch(#{rows := [{[{array,[{array,[<<"s1">>,null]}]}]}]}, dream_pgo:query("SELECT $1::text[][][]", [[{array, [{array, [<<"s1">>, null]}]}]])).

tsvector(_Config) ->
    ?assertMatch(#{rows := [{[{<<"fat">>,[{2,null}]},{<<"rat">>,[{3,null}]}]}]},
                 dream_pgo:query("SELECT to_tsvector('english', 'The Fat Rats')")),
    ?assertMatch(#{rows := [{[{<<"a">>,[{1,'A'}]},
                              {<<"cat">>,[{5,null}]},
                              {<<"fat">>,[{2,'B'},{4,'C'}]}]}]},
                 dream_pgo:query("SELECT 'a:1A fat:2B,4C cat:5D'::tsvector")),
    ?assertMatch(#{rows := [{[{<<"a">>,[{1,'A'}]},
                              {<<"cat">>,[{5,null}]},
                              {<<"fat">>,[{2,'B'},{4,'C'}]}]}]},
                 dream_pgo:query("SELECT $1::tsvector", [[{<<"a">>,[{1,'A'}]},
                                                    {<<"cat">>,[{5,null}]},
                                                    {<<"fat">>,[{2,'B'},{4,'C'}]}]])).

query_arity_4(_Config) ->
    {ok, Ref, Conn} = dream_pgo:checkout(dream_pgo_default),

    ?assertMatch(#{rows := [{1}]}, dream_pgo:query("select 1", [], #{}, Conn)),

    dream_pgo:checkin(Ref, Conn),

    ok.

netmask(_Config) ->
    ?assertMatch(#{rows := [{{{192,168,0,1},24}}]},
                 dream_pgo:query("SELECT '192.168.0.1/24'::inet")),

    ok.

transaction_returns_value(_Config) ->
    ?assertEqual(42, dream_pgo:transaction(fun() -> 42 end)),
    ?assertEqual(ok, dream_pgo:transaction(fun() ->
                                         ?assertMatch(#{rows := [{1}]}, dream_pgo:query("select 1::int")),
                                         ok
                                     end)),
    ok.

transaction_aborted_raises(_Config) ->
    ?assertError(transaction_rolled_back,
                 dream_pgo:transaction(fun() ->
                                     {error, _} = dream_pgo:query("select 1/0"),
                                     ok
                                 end)),

    ?assertMatch(#{rows := [{1}]}, dream_pgo:query("select 1::int")),
    ok.
