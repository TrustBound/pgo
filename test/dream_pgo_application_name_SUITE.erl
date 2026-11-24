-module(dream_pgo_application_name_SUITE).

-compile(export_all).

-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

all() -> [caller_name, no_name_gives_node_name, pool_option,
          pool_option_atom, connection_parameter_wins_over_pool_option,
          name_between_other_parameters, unsorted_parameters,
          no_duplicate_parameter_names, mixed_case_caller_name,
          mixed_case_no_duplicate_parameter_names].

init_per_suite(Config) ->
    application:ensure_all_started(dream_pgo),
    Config.

end_per_suite(_Config) ->
    application:stop(dream_pgo),
    ok.

caller_name(_Config) ->
    ?assertEqual(<<"billing">>,
                 application_name(caller_name,
                                  #{connection_parameters => [{<<"application_name">>, <<"billing">>}]})).

no_name_gives_node_name(_Config) ->
    ?assertEqual(atom_to_binary(node(), utf8),
                 application_name(no_name_gives_node_name, #{})).

pool_option(_Config) ->
    ?assertEqual(<<"billing">>,
                 application_name(pool_option, #{application_name => "billing"})).

pool_option_atom(_Config) ->
    ?assertEqual(<<"billing">>,
                 application_name(pool_option_atom, #{application_name => billing})).

connection_parameter_wins_over_pool_option(_Config) ->
    ?assertEqual(<<"billing">>,
                 application_name(connection_parameter_wins_over_pool_option,
                                  #{application_name => <<"other">>,
                                    connection_parameters => [{<<"application_name">>, <<"billing">>}]})).

name_between_other_parameters(_Config) ->
    Pool = name_between_other_parameters,
    ?assertEqual(<<"billing">>,
                 application_name(Pool,
                                  #{connection_parameters => [{<<"client_encoding">>, <<"UTF8">>},
                                                              {<<"application_name">>, <<"billing">>},
                                                              {<<"timezone">>, <<"Europe/Paris">>}]})),
    ?assertEqual(<<"UTF8">>, setting(Pool, <<"client_encoding">>)),
    ?assertEqual(<<"Europe/Paris">>, setting(Pool, <<"timezone">>)).

unsorted_parameters(_Config) ->
    Pool = unsorted_parameters,
    ?assertEqual(<<"billing">>,
                 application_name(Pool,
                                  #{connection_parameters => [{<<"timezone">>, <<"Europe/Paris">>},
                                                              {<<"application_name">>, <<"billing">>},
                                                              {<<"client_encoding">>, <<"UTF8">>}]})),
    ?assertEqual(<<"Europe/Paris">>, setting(Pool, <<"timezone">>)).

no_duplicate_parameter_names(_Config) ->
    Params = dream_pgo_handler:startup_parameters(
               #{user => "test",
                 database => "test",
                 application_name => <<"other">>,
                 connection_parameters => [{<<"timezone">>, <<"UTC">>},
                                           {<<"application_name">>, <<"billing">>},
                                           {<<"client_encoding">>, <<"UTF8">>}]}),
    Names = [iolist_to_binary(Name) || {Name, _} <- Params],
    ?assertEqual(lists:usort(Names), lists:sort(Names)),
    ?assertEqual([<<"user">>, <<"database">>, <<"timezone">>,
                  <<"application_name">>, <<"client_encoding">>], Names),
    ?assertEqual([<<"billing">>],
                 [iolist_to_binary(Value) || {<<"application_name">>, Value} <- Params]).

mixed_case_caller_name(_Config) ->
    ?assertEqual(<<"billing">>,
                 application_name(mixed_case_caller_name,
                                  #{connection_parameters => [{<<"Application_Name">>, <<"billing">>}]})).

mixed_case_no_duplicate_parameter_names(_Config) ->
    Params = dream_pgo_handler:startup_parameters(
               #{user => "test",
                 database => "test",
                 application_name => <<"other">>,
                 connection_parameters => [{<<"TimeZone">>, <<"UTC">>},
                                           {<<"APPLICATION_NAME">>, <<"billing">>},
                                           {<<"timezone">>, <<"Europe/Paris">>},
                                           {<<"User">>, <<"other">>}]}),
    ?assertEqual([{<<"user">>, "test"},
                  {<<"database">>, "test"},
                  {<<"APPLICATION_NAME">>, <<"billing">>},
                  {<<"timezone">>, <<"Europe/Paris">>},
                  {<<"User">>, <<"other">>}], Params).

application_name(Pool, PoolConfig) ->
    {ok, _} = dream_pgo_sup:start_child(Pool, maps:merge(#{pool_size => 1,
                                                           port => 5432,
                                                           database => "test",
                                                           user => "test",
                                                           password => "password"},
                                                         PoolConfig)),
    setting(Pool, <<"application_name">>).

setting(Pool, Name) ->
    #{rows := [{Value}]} = dream_pgo:query(<<"select current_setting($1)">>, [Name], #{pool => Pool}),
    Value.
