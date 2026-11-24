-module(dream_pgo_extra_SUITE).

-compile(export_all).

-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

all() ->
    [extra_reaches_every_connection,
     binary_extra_is_not_changed,
     extra_defaults_to_undefined,
     second_start_keeps_extra].

init_per_suite(Config) ->
    application:ensure_all_started(dream_pgo),
    Config.

end_per_suite(_Config) ->
    application:stop(dream_pgo),
    ok.

init_per_testcase(Case, Config) ->
    [{pool, Case} | Config].

end_per_testcase(_Case, Config) ->
    Pool = ?config(pool, Config),
    case whereis(Pool) of
        undefined ->
            ok;
        Pid ->
            ok = supervisor:terminate_child(dream_pgo_sup, Pid)
    end,
    dream_pgo_test_utils:clear_types(Pool),
    ok.

pool_config(Size) ->
    #{database => "test",
      user => "test",
      password => "password",
      pool_size => Size}.

%% check out all connections at once, so that each one is a different connection
checkout_all(Pool, Size) ->
    [begin
         {ok, Ref, Conn} = dream_pgo:checkout(Pool),
         {Ref, Conn}
     end || _ <- lists:seq(1, Size)].

checkin_all(Checkouts) ->
    [dream_pgo:checkin(Ref, Conn) || {Ref, Conn} <- Checkouts],
    ok.

extra_reaches_every_connection(Config) ->
    Pool = ?config(pool, Config),
    Extra = {some_value, make_ref(), fun(X) -> X end},
    {ok, _} = dream_pgo:start_pool(Pool, (pool_config(3))#{extra => Extra}),

    Checkouts = checkout_all(Pool, 3),
    try
        ?assertEqual(3, length(lists:usort([Ref || {Ref, _} <- Checkouts]))),
        [?assert(Extra =:= dream_pgo:conn_extra(Conn)) || {_, Conn} <- Checkouts]
    after
        checkin_all(Checkouts)
    end.

%% the pool turns a binary setting into a string, but not `extra'
binary_extra_is_not_changed(Config) ->
    Pool = ?config(pool, Config),
    {ok, _} = dream_pgo:start_pool(Pool, (pool_config(1))#{extra => <<"a binary">>}),

    [{Ref, Conn}] = checkout_all(Pool, 1),
    try
        ?assert(<<"a binary">> =:= dream_pgo:conn_extra(Conn))
    after
        dream_pgo:checkin(Ref, Conn)
    end.

extra_defaults_to_undefined(Config) ->
    Pool = ?config(pool, Config),
    {ok, _} = dream_pgo:start_pool(Pool, pool_config(2)),

    Checkouts = checkout_all(Pool, 2),
    try
        [?assertEqual(undefined, dream_pgo:conn_extra(Conn)) || {_, Conn} <- Checkouts]
    after
        checkin_all(Checkouts)
    end.

second_start_keeps_extra(Config) ->
    Pool = ?config(pool, Config),
    First = {first, make_ref()},
    {ok, Pid} = dream_pgo:start_pool(Pool, (pool_config(2))#{extra => First}),

    ?assertMatch({error, _},
                 dream_pgo:start_pool(Pool, (pool_config(2))#{extra => {second, make_ref()}})),
    ?assertEqual(Pid, whereis(Pool)),

    Checkouts = checkout_all(Pool, 2),
    try
        [?assert(First =:= dream_pgo:conn_extra(Conn)) || {_, Conn} <- Checkouts]
    after
        checkin_all(Checkouts)
    end.
