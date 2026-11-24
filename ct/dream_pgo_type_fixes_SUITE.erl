-module(dream_pgo_type_fixes_SUITE).

%% Round trips through the server for the readers of pg_types 0.6.0 that
%% crashed or gave a wrong value, and that dream_pgo replaces. Each test
%% holds the value that failed with pg_types 0.6.0.

-compile(export_all).

-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").
-include_lib("pg_types/include/pg_types.hrl").

-import(dream_pgo_test_utils, [literal/2, round_trip/3, oid_of/1]).

all() ->
    [registered_modules, numrange, time_24, timetz_24, interval_negative,
     interval_over_24_hours, interval_infinity, date_infinity].

init_per_suite(Config) ->
    {ok, _} = application:ensure_all_started(dream_pgo),
    {ok, _} = dream_pgo_sup:start_child(dream_pgo_default, #{pool_size => 1,
                                                             database => "test",
                                                             user => "test",
                                                             password => "password"}),
    Config.

end_per_suite(_Config) ->
    application:stop(dream_pgo),
    ok.

registered_modules(_Config) ->
    [?assertMatch(#type_info{module=Module},
                  pg_types:lookup_type_info(dream_pgo_default, oid_of(Type)))
     || {Type, Module} <- [{"numrange", dream_pgo_type_range},
                           {"time", dream_pgo_type_time},
                           {"interval", dream_pgo_type_interval},
                           {"date", dream_pgo_type_date}]].

%% pg_types issue #21: a range over a type of variable length crashed
numrange(_Config) ->
    literal("select '[1.5,2.5)'::numrange", {{1.5, 2.5}, {true, false}}),
    literal("select '[1.5,)'::numrange", {{1.5, unbound}, {true, false}}),
    round_trip("numrange", {{1.5, 2.5}, {true, false}}, <<"[1.5,2.5)">>).

time_24(_Config) ->
    literal("select '24:00:00'::time", {24, 0, 0}),
    round_trip("time", {24, 0, 0}, <<"24:00:00">>).

timetz_24(_Config) ->
    literal("select '24:00:00+00'::timetz", {{24, 0, 0}, 0}),
    round_trip("timetz", {{24, 0, 0}, 0}, <<"24:00:00+00">>).

interval_negative(_Config) ->
    literal("select '-1 hours'::interval", {interval, {{-1, 0, 0}, 0, 0}}),
    literal("select '-1 day -02:03:04.5'::interval", {interval, {{-2, -3, -4.5}, -1, 0}}),
    round_trip("interval", {interval, {{-1, 0, 0}, 0, 0}}, <<"-01:00:00">>),
    round_trip("interval", {interval, {{-2, -3, -4.5}, -1, 0}}, <<"-1 days -02:03:04.5">>).

interval_over_24_hours(_Config) ->
    literal("select '100 hours'::interval", {interval, {{100, 0, 0}, 0, 0}}),
    literal("select '24:00:00'::interval", {interval, {{24, 0, 0}, 0, 0}}),
    round_trip("interval", {interval, {{100, 0, 0}, 0, 0}}, <<"100:00:00">>).

%% PostgreSQL 17 and later: an infinite interval has all three fields at the
%% largest or the smallest integer
interval_infinity(_Config) ->
    literal("select 'infinity'::interval", infinity),
    literal("select '-infinity'::interval", '-infinity'),
    round_trip("interval", infinity, <<"infinity">>),
    round_trip("interval", '-infinity', <<"-infinity">>),
    ?assertEqual([{true, true}],
                 dream_pgo_test_utils:rows("select $1::interval = 'infinity'::interval, "
                                           "$2::interval = '-infinity'::interval",
                                           [infinity, '-infinity'])),
    %% one field at the limit is a finite interval
    literal("select make_interval(days => 2147483647)",
            {interval, {{0, 0, 0}, 2147483647, 0}}).

date_infinity(_Config) ->
    literal("select 'infinity'::date", infinity),
    literal("select '-infinity'::date", '-infinity'),
    literal("select '2024-02-29'::date", {2024, 2, 29}),
    round_trip("date", infinity, <<"infinity">>),
    round_trip("date", '-infinity', <<"-infinity">>).

