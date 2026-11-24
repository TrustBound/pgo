-module(dream_postgres_driver_test_utils).

-export([clear_types/1]).

%% round trips of a type through the server
-export([rows/1,
         rows/2,
         oid_of/1,
         literal/2,
         round_trip/3,
         round_trip/4,
         param_text/3]).

-include_lib("stdlib/include/assert.hrl").

clear_types(Pool) ->
    [persistent_term:erase(K) || {K={pg_types, P, _}, _} <- persistent_term:get(), P =:= Pool].

rows(Query) ->
    rows(Query, []).

rows(Query, Params) ->
    case dream_postgres_driver:query(Query, Params) of
        #{rows := Rows} ->
            Rows;
        Other ->
            ct:fail({query_failed, iolist_to_binary(Query), Other})
    end.

oid_of(Type) ->
    [{Oid}] = rows(["select '", Type, "'::regtype::oid"]),
    Oid.

%% select a literal, compare the decoded value with the exact Erlang term
literal(Query, Expected) ->
    ?assertEqual([{Expected}], rows(Query)).

round_trip(Type, Value, Text) ->
    round_trip(Type, Value, Text, Value).

%% insert the Erlang term as a parameter, select it back as text and as
%% the decoded term. Each call uses a new table name: dream_postgres_driver caches the
%% parameter types of a query by its text, so the same insert into a table
%% of another type would reuse the old parameter type.
round_trip(Type, Value, Text, Decoded) ->
    Table = ["types_round_trip_", integer_to_list(erlang:unique_integer([positive]))],
    #{command := create} = dream_postgres_driver:query(["create temporary table ", Table, " (v ", Type, ")"]),
    #{command := insert} = dream_postgres_driver:query(["insert into ", Table, " (v) values ($1)"], [Value]),
    ?assertEqual([{Text}], rows(["select v::text from ", Table])),
    ?assertEqual([{Decoded}], rows(["select v from ", Table])),
    #{command := drop} = dream_postgres_driver:query(["drop table ", Table]).

%% for pseudo types, which cannot be the type of a column
param_text(Type, Value, Text) ->
    ?assertEqual([{Text}], rows(["select ($1::", Type, ")::text"], [Value])).
