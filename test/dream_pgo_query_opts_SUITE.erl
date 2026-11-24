-module(dream_pgo_query_opts_SUITE).

-compile(export_all).

-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

all() ->
    [default_rows_as_maps].

init_per_suite(Config) ->
    application:ensure_all_started(dream_pgo),

    {ok, _} = dream_pgo_sup:start_child(default, #{database => "test",
                                             user => "test",
                                             password => "password",
                                             pool_size => 1,
                                             decode_opts => [return_rows_as_maps]}),

    Config.

end_per_suite(_Config) ->
    dream_pgo:query("drop table tmp"),
    dream_pgo:query("drop table tmp_b"),
    dream_pgo:query("drop table foo"),
    dream_pgo:query("drop table types"),

    application:stop(dream_pgo),

    dream_pgo_test_utils:clear_types(default),

    ok.

default_rows_as_maps(_Config) ->
    ?assertMatch(#{command := create},
                 dream_pgo:query("create temporary table foo_1 (id integer primary key, some_text text)")),
    ?assertMatch(#{command := insert},
                 dream_pgo:query("insert into foo_1 (id, some_text) values (1, 'hello')")),

    ?assertMatch(#{command := select,rows := [#{<<"id">> := 1,<<"some_text">> := <<"hello">>}]},
                 dream_pgo:query("select * from foo_1")),

    ?assertMatch(#{command := select,rows := [#{id := 1, some_text := <<"hello">>}]},
                 dream_pgo:query("select * from foo_1", [], #{decode_opts => [column_name_as_atom]})).
