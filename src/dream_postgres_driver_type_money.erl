-module(dream_postgres_driver_type_money).

%% Mirrors the pg_types branch `add-money`, which is not in a pg_types
%% release yet. Remove this module when pg_types has it.

-behaviour(pg_types).

-export([init/1,
         encode/2,
         decode/2,
         type_spec/0]).

-include("dream_postgres_driver_types.hrl").

init(_Opts) ->
    {[<<"cash_send">>], []}.

%% money is sent as an integer of the smallest unit of the currency, the
%% number of fractional digits depends on the server's lc_monetary setting
encode(N, _) when is_integer(N) ->
    <<8:?int32, N:?int64>>.

decode(<<N:?int64>>, _) ->
    N.

type_spec() ->
    "Amount::integer() in the smallest unit of the currency, e.g. cents".
