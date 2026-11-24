-module(dream_postgres_driver_null_byte_SUITE).

-compile(export_all).

-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

%% A string in the PostgreSQL startup packet ends at a null byte, so a
%% null byte in the password or in a startup parameter cannot go to the
%% server. The pool refuses such a configuration when it starts. A
%% password given as a function is known only at connect time, so each
%% connection attempt checks the value that the function returns.

all() -> [password, password_binary, user, database, parameter_name,
          parameter_value, application_name, startup_parameters_check,
          linked_caller_survives, valid_configuration_starts,
          password_function, password_function_binary,
          password_function_connects].

init_per_suite(Config) ->
    application:ensure_all_started(dream_postgres_driver),
    Config.

end_per_suite(_Config) ->
    application:stop(dream_postgres_driver),
    ok.

password(_Config) ->
    refused(password, #{password => "pass\0word"}, {null_byte, password}).

password_binary(_Config) ->
    refused(password_binary, #{password => <<"pass", 0, "word">>}, {null_byte, password}).

user(_Config) ->
    refused(user, #{user => "te\0st"}, {null_byte, {parameter, <<"user">>}}).

database(_Config) ->
    refused(database, #{database => <<"te", 0, "st">>}, {null_byte, {parameter, <<"database">>}}).

parameter_name(_Config) ->
    refused(parameter_name,
            #{connection_parameters => [{<<"time", 0, "zone">>, <<"UTC">>}]},
            {null_byte, {parameter, <<"time", 0, "zone">>}}).

parameter_value(_Config) ->
    refused(parameter_value,
            #{connection_parameters => [{<<"timezone">>, [<<"UTC">>, 0, "user"]}]},
            {null_byte, {parameter, <<"timezone">>}}).

application_name(_Config) ->
    refused(application_name, #{application_name => <<"billing", 0>>},
            {null_byte, {parameter, <<"application_name">>}}).

startup_parameters_check(_Config) ->
    ?assertEqual(ok, dream_postgres_driver_handler:check_startup_options(
                       #{user => "test", password => "password",
                         connection_parameters => [{<<"timezone">>, <<"UTC">>}]})),
    ?assertEqual({error, {null_byte, password}},
                 dream_postgres_driver_handler:check_startup_options(#{password => [<<"a">>, [0]]})).

%% dream_postgres_driver_pool:start_link/2 links the pool to the caller. A refused
%% configuration gives the caller an error, not an exit signal.
linked_caller_survives(_Config) ->
    Self = self(),
    {Pid, MonRef} =
        spawn_monitor(fun() ->
                              Result = dream_postgres_driver_pool:start_link(null_byte_linked,
                                                                 pool_config(#{password => "a\0b"})),
                              Self ! {self(), Result},
                              timer:sleep(100)
                      end),
    receive
        {Pid, Result} ->
            ?assertEqual({error, {null_byte, password}}, Result)
    after 5000 ->
            ct:fail(no_result)
    end,
    receive
        {'DOWN', MonRef, process, Pid, Reason} ->
            ?assertEqual(normal, Reason)
    after 5000 ->
            ct:fail(no_down)
    end.

valid_configuration_starts(_Config) ->
    {ok, _} = dream_postgres_driver_sup:start_child(valid_configuration_starts, pool_config(#{})),
    ?assertMatch(#{rows := [{1}]},
                 dream_postgres_driver:query(<<"select 1">>, [], #{pool => valid_configuration_starts})).

password_function(_Config) ->
    refused_at_connect(fun() -> "pass\0word" end).

password_function_binary(_Config) ->
    refused_at_connect(fun() -> <<"pass", 0, "word">> end).

password_function_connects(_Config) ->
    {ok, Conn} = dream_postgres_driver_handler:open(null_byte_password_function,
                                        pool_config(#{password => fun() -> "password" end})),
    ?assertEqual(ok, dream_postgres_driver_handler:ping(Conn)),
    dream_postgres_driver_handler:close(Conn).

%% The connection attempt fails before it sends anything, and it closes
%% its socket.
refused_at_connect(PasswordFun) ->
    TcpPortsBefore = tcp_ports(),
    ?assertEqual({error, {null_byte, password}},
                 dream_postgres_driver_handler:open(null_byte_password_function,
                                        pool_config(#{password => PasswordFun}))),
    ?assertEqual(TcpPortsBefore, tcp_ports()).

tcp_ports() ->
    [P || P <- erlang:ports(), erlang:port_info(P, name) =:= {name, "tcp_inet"}].

%% The pool name gets a prefix: a name such as `user` is already taken
%% by a process of the VM.
refused(Case, PoolConfig, Reason) ->
    Pool = list_to_atom("null_byte_" ++ atom_to_list(Case)),
    ?assertEqual({error, Reason}, dream_postgres_driver_sup:start_child(Pool, pool_config(PoolConfig))),
    ?assertEqual(undefined, whereis(Pool)).

pool_config(PoolConfig) ->
    maps:merge(#{pool_size => 1,
                 port => 5432,
                 database => "test",
                 user => "test",
                 password => "password"},
               PoolConfig).
