-module(dream_pgo_types_SUITE).

%% Round trips through the server for the types that dream_pgo reads with its
%% own modules (see dream_pgo_types). Each test selects a literal and compares
%% the decoded value with the exact Erlang term, then sends the Erlang term as
%% a parameter and compares the text that the server makes of it.

-compile(export_all).

-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").
-include_lib("pg_types/include/pg_types.hrl").

-import(dream_pgo_test_utils, [rows/1, literal/2, round_trip/3, round_trip/4,
                               param_text/3, oid_of/1]).

all() ->
    [{group, types}, {group, user_modules}].

groups() ->
    [{types, [], [registered_modules,
                  oid, reg_types, xid_cid,
                  timetz, timetz_array, money, macaddr8, box, xml, cstring,
                  jsonpath, pg_lsn, xid8, pg_snapshot, txid_snapshot, void,
                  int2vector, oidvector, tsquery]},
     {user_modules, [], [user_module_kept, restart_keeps_one_copy]}].

init_per_suite(Config) ->
    Config.

end_per_suite(_Config) ->
    ok.

init_per_group(types, Config) ->
    start(),
    Config;
init_per_group(user_modules, Config) ->
    application:load(pg_types),
    Saved = application:get_env(pg_types, modules),
    application:set_env(pg_types, modules, [dream_pgo_test_money_type]),
    start(),
    [{saved_modules, Saved} | Config].

end_per_group(types, _Config) ->
    stop();
end_per_group(user_modules, Config) ->
    stop(),
    case ?config(saved_modules, Config) of
        {ok, Modules} ->
            application:set_env(pg_types, modules, Modules);
        undefined ->
            application:unset_env(pg_types, modules)
    end,
    ok.

start() ->
    {ok, _} = application:ensure_all_started(dream_pgo),
    {ok, _} = dream_pgo_sup:start_child(dream_pgo_default, #{pool_size => 1,
                                                             database => "test",
                                                             user => "test",
                                                             password => "password"}),
    ok.

stop() ->
    application:stop(dream_pgo),
    ok.

%% registration

registered_modules(_Config) ->
    Carried = dream_pgo_types:modules(),
    ?assertEqual({ok, Carried}, application:get_env(pg_types, modules)),
    %% the type map of the pool uses the carried modules, also where they
    %% replace a module of pg_types
    [?assertMatch(#type_info{module=Module},
                  pg_types:lookup_type_info(dream_pgo_default, oid_of(Type)))
     || {Type, Module} <- [{"timetz", dream_pgo_type_timetz},
                           {"money", dream_pgo_type_money},
                           {"oid", dream_pgo_type_oid}]].

user_module_kept(_Config) ->
    %% a module the user set before the start stays, after the carried
    %% modules, so it replaces a carried module for the same type
    ?assertEqual({ok, dream_pgo_types:modules() ++ [dream_pgo_test_money_type]},
                 application:get_env(pg_types, modules)),
    ?assertEqual([{{test_money, 1234}}], rows("select '12.34'::money")),
    round_trip("money", {test_money, 1234}, <<"$12.34">>),
    %% the carried modules still work
    ?assertEqual([{{{1, 2, 3}, 3600}}], rows("select '01:02:03+01'::timetz")).

restart_keeps_one_copy(_Config) ->
    stop(),
    start(),
    ?assertEqual({ok, dream_pgo_types:modules() ++ [dream_pgo_test_money_type]},
                 application:get_env(pg_types, modules)).

%% new types

oid(_Config) ->
    literal("select 1234::oid", 1234),
    round_trip("oid", 4294967295, <<"4294967295">>).

reg_types(_Config) ->
    literal("select 'now'::regproc", 1299),
    literal("select 'now()'::regprocedure", 1299),
    literal("select 551::regoper", 551),
    literal("select '+(integer,integer)'::regoperator", 551),
    literal("select 'pg_class'::regclass", 1259),
    literal("select 'int4'::regtype", 23),
    literal("select 'pg_catalog'::regnamespace", 11),
    literal("select 'pg_monitor'::regrole", 3373),
    literal("select 'simple'::regconfig", 3748),
    literal("select 'simple'::regdictionary", 3765),
    literal("select '\"C\"'::regcollation", 950),
    round_trip("regproc", 1299, <<"now">>),
    round_trip("regprocedure", 1299, <<"now()">>),
    round_trip("regoper", 551, <<"pg_catalog.+">>),
    round_trip("regoperator", 551, <<"+(integer,integer)">>),
    round_trip("regclass", 1259, <<"pg_class">>),
    round_trip("regtype", 23, <<"integer">>),
    round_trip("regnamespace", 11, <<"pg_catalog">>),
    round_trip("regrole", 3373, <<"pg_monitor">>),
    round_trip("regconfig", 3748, <<"simple">>),
    round_trip("regdictionary", 3765, <<"simple">>),
    round_trip("regcollation", 950, <<"\"C\"">>).

xid_cid(_Config) ->
    literal("select '42'::xid", 42),
    literal("select '7'::cid", 7),
    round_trip("xid", 42, <<"42">>),
    round_trip("cid", 7, <<"7">>).

timetz(_Config) ->
    literal("select '13:45:30.5+05:30'::timetz", {{13, 45, 30.5}, 19800}),
    literal("select '00:00:00-08'::timetz", {{0, 0, 0}, -28800}),
    round_trip("timetz", {{1, 2, 3}, -3600}, <<"01:02:03-01">>),
    round_trip("timetz", {{12, 0, 0.25}, 19815}, <<"12:00:00.25+05:30:15">>).

timetz_array(_Config) ->
    literal("select ARRAY['01:00:00+00'::timetz, '02:00:00+01'::timetz]",
            [{{1, 0, 0}, 0}, {{2, 0, 0}, 3600}]),
    round_trip("timetz[]", [{{1, 0, 0}, 0}], <<"{01:00:00+00}">>).

money(_Config) ->
    literal("select '12.34'::money", 1234),
    literal("select '-0.01'::money", -1),
    round_trip("money", 1234, <<"$12.34">>).

macaddr8(_Config) ->
    literal("select '08:00:2b:01:02:03:04:05'::macaddr8", {8, 0, 43, 1, 2, 3, 4, 5}),
    round_trip("macaddr8", {8, 0, 43, 1, 2, 3, 4, 5}, <<"08:00:2b:01:02:03:04:05">>).

box(_Config) ->
    literal("select '((1,2),(3,4))'::box",
            #{point1 => #{x => 3.0, y => 4.0}, point2 => #{x => 1.0, y => 2.0}}),
    round_trip("box", #{point1 => #{x => 3.0, y => 4.0}, point2 => #{x => 1.0, y => 2.0}},
               <<"(3,4),(1,2)">>).

xml(_Config) ->
    literal("select '<a>b</a>'::xml", <<"<a>b</a>">>),
    round_trip("xml", <<"<a>b</a>">>, <<"<a>b</a>">>).

cstring(_Config) ->
    literal("select 'abc'::cstring", <<"abc">>),
    param_text("cstring", <<"abc">>, <<"abc">>).

jsonpath(_Config) ->
    literal("select '$.a[*]'::jsonpath", <<"$.\"a\"[*]">>),
    round_trip("jsonpath", <<"$.a[*]">>, <<"$.\"a\"[*]">>, <<"$.\"a\"[*]">>).

pg_lsn(_Config) ->
    literal("select '16/B374D848'::pg_lsn", 16#16B374D848),
    round_trip("pg_lsn", 16#16B374D848, <<"16/B374D848">>).

xid8(_Config) ->
    literal("select '18446744073709551615'::xid8", 18446744073709551615),
    round_trip("xid8", 42, <<"42">>).

pg_snapshot(_Config) ->
    literal("select '10:20:10,14,15'::pg_snapshot",
            #{xmin => 10, xmax => 20, xip => [10, 14, 15]}),
    round_trip("pg_snapshot", #{xmin => 10, xmax => 20, xip => [10, 14, 15]},
               <<"10:20:10,14,15">>),
    round_trip("pg_snapshot", #{xmin => 10, xmax => 10, xip => []}, <<"10:10:">>).

txid_snapshot(_Config) ->
    literal("select '10:20:10,14,15'::txid_snapshot",
            #{xmin => 10, xmax => 20, xip => [10, 14, 15]}),
    round_trip("txid_snapshot", #{xmin => 10, xmax => 20, xip => [10, 14, 15]},
               <<"10:20:10,14,15">>).

void(_Config) ->
    literal("select pg_sleep(0)", void),
    param_text("void", void, <<"">>).

int2vector(_Config) ->
    literal("select '1 2 3'::int2vector", [1, 2, 3]),
    round_trip("int2vector", [1, 2, 3], <<"1 2 3">>).

oidvector(_Config) ->
    literal("select '23 25'::oidvector", [23, 25]),
    round_trip("oidvector", [23, 25], <<"23 25">>).

tsquery(_Config) ->
    Lexeme = fun(L) -> {L, [], false} end,
    literal("select 'fat & (rat | !cat)'::tsquery",
            {'and', Lexeme(<<"fat">>),
                    {'or', Lexeme(<<"rat">>), {'not', Lexeme(<<"cat">>)}}}),
    literal("select 'a <2> b:A*'::tsquery",
            {phrase, 2, Lexeme(<<"a">>), {<<"b">>, ['A'], true}}),
    literal("select ''::tsquery", empty),
    round_trip("tsquery",
               {'and', Lexeme(<<"fat">>),
                       {'or', Lexeme(<<"rat">>), {'not', Lexeme(<<"cat">>)}}},
               <<"'fat' & ( 'rat' | !'cat' )">>),
    round_trip("tsquery", {phrase, 2, Lexeme(<<"a">>), {<<"b">>, ['A', 'C'], true}},
               <<"'a' <2> 'b':*AC">>).
