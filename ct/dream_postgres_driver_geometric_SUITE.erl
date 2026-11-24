-module(dream_postgres_driver_geometric_SUITE).

-compile(export_all).

-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

all() -> [select, insert].

init_per_suite(Config) ->
    application:ensure_all_started(dream_postgres_driver),

    {ok, _} = dream_postgres_driver_sup:start_child(dream_postgres_driver_default, #{pool_size => 1,
                                                 database => "test",
                                                 user => "test",
                                                 password => "password"}),

    Config.

end_per_suite(_Config) ->
    application:stop(dream_postgres_driver),
    dream_postgres_driver_test_utils:clear_types(dream_postgres_driver_default),
    ok.

select(_Config) ->
    ?assertMatch(#{command := select,
                  rows := [{#{y := 2.0, x := +0.0}}]},
                 dream_postgres_driver:query("select '(0,2.0)'::point")).

insert(_Config) ->
    ?assertMatch(#{command := create},
                 dream_postgres_driver:query("create temporary table points (a_point point)")),

    ?assertMatch(#{command := insert},
                 dream_postgres_driver:query("insert into points (a_point) VALUES ($1)",
                           [#{x => 1.1, y => 74.9}])),

    ?assertMatch(#{command := insert},
                 dream_postgres_driver:query("insert into points (a_point) VALUES ($1)",
                           [#{x => 3.2, y => 4.5}])),

    ?assertMatch(#{command := insert},
                 dream_postgres_driver:query("insert into points (a_point) VALUES ($1)",
                           [#{x => 0, y => 5}])),

    ?assertMatch(#{command := select,
                  rows := [{#{x := 1.1, y := 74.9}},
                           {#{x := 3.2, y := 4.5}},
                           {#{x := +0.0, y := 5.0}}]},
                 dream_postgres_driver:query("select a_point from points")).
