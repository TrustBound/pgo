-module(dream_pgo_enum_SUITE).

-compile(export_all).

-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

all() -> [select, insert].

init_per_suite(Config) ->
    application:ensure_all_started(dream_pgo),

    {ok, _} = dream_pgo_sup:start_child(default, #{pool_size => 1,
                                             database => "test",
                                             user => "test",
                                             password => "password"}),

    ?assertMatch(#{command := create},
                 dream_pgo:query("CREATE TYPE mood AS ENUM ('sad', 'ok', 'happy')")),

    Config.

end_per_suite(_Config) ->
    #{command := drop} = dream_pgo:query("DROP TYPE mood CASCADE;"),

    application:stop(dream_pgo),

    dream_pgo_test_utils:clear_types(default),

    ok.

select(_Config) ->

    ?assertMatch(#{command := select, rows := [{<<"sad">>}]},
                 dream_pgo:query("select 'sad'::mood", [])),

    ?assertMatch(#{command := select, rows := [{<<"sad">>}]},
                 dream_pgo:query("select 'sad'::mood;", [])),
    ?assertMatch(#{command := select, rows := [{<<"sad">>}]},
                 dream_pgo:query("select $1::mood;", [<<"sad">>])),
    ?assertMatch(#{command := select, rows := [{[<<"sad">>]}]},
                 dream_pgo:query("select '{sad}'::mood[];")),
    ?assertMatch(#{command := select, rows := [{[<<"sad">>]}]},
                 dream_pgo:query("select $1::mood[];", [[<<"sad">>]])).

insert(_Config) ->
    ?assertMatch(#{command := create},
                 dream_pgo:query("create temporary table moods (a_mood mood)")),

    ?assertMatch(#{command := insert},
                 dream_pgo:query("insert into moods (a_mood) VALUES ($1)",
                           [<<"sad">>])),

    ?assertMatch(#{command := select,
                   rows := [{<<"sad">>}]},
                 dream_pgo:query("select a_mood from moods")).
