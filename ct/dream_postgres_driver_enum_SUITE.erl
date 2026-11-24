-module(dream_postgres_driver_enum_SUITE).

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

    ?assertMatch(#{command := create},
                 dream_postgres_driver:query("CREATE TYPE mood AS ENUM ('sad', 'ok', 'happy')")),

    Config.

end_per_suite(_Config) ->
    #{command := drop} = dream_postgres_driver:query("DROP TYPE mood CASCADE;"),

    application:stop(dream_postgres_driver),

    dream_postgres_driver_test_utils:clear_types(dream_postgres_driver_default),

    ok.

select(_Config) ->

    ?assertMatch(#{command := select, rows := [{<<"sad">>}]},
                 dream_postgres_driver:query("select 'sad'::mood", [])),

    ?assertMatch(#{command := select, rows := [{<<"sad">>}]},
                 dream_postgres_driver:query("select 'sad'::mood;", [])),
    ?assertMatch(#{command := select, rows := [{<<"sad">>}]},
                 dream_postgres_driver:query("select $1::mood;", [<<"sad">>])),
    ?assertMatch(#{command := select, rows := [{[<<"sad">>]}]},
                 dream_postgres_driver:query("select '{sad}'::mood[];")),
    ?assertMatch(#{command := select, rows := [{[<<"sad">>]}]},
                 dream_postgres_driver:query("select $1::mood[];", [[<<"sad">>]])).

insert(_Config) ->
    ?assertMatch(#{command := create},
                 dream_postgres_driver:query("create temporary table moods (a_mood mood)")),

    ?assertMatch(#{command := insert},
                 dream_postgres_driver:query("insert into moods (a_mood) VALUES ($1)",
                           [<<"sad">>])),

    ?assertMatch(#{command := select,
                   rows := [{<<"sad">>}]},
                 dream_postgres_driver:query("select a_mood from moods")).
