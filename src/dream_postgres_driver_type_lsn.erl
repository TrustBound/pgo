-module(dream_postgres_driver_type_lsn).

%% Mirrors the pg_types branch `add-pg-lsn`, which is not in a pg_types
%% release yet. Remove this module when pg_types has it.

-behaviour(pg_types).

-export([init/1,
         encode/2,
         decode/2,
         type_spec/0]).

-include("dream_postgres_driver_types.hrl").

-define(LSN_MAX, 18446744073709551615).

init(_Opts) ->
    {[<<"pg_lsn_send">>], []}.

%% a log sequence number is an unsigned 64 bit integer, the text format
%% 16/B374D848 is the upper and lower 32 bits in hex
encode(Lsn, _) when is_integer(Lsn) andalso Lsn >= 0 andalso Lsn =< ?LSN_MAX ->
    <<8:?int32, Lsn:?uint64>>.

decode(<<Lsn:?uint64>>, _) ->
    Lsn.

type_spec() ->
    "Lsn::0..18446744073709551615".
