-module(dream_pgo_type_xid8).

%% Mirrors the pg_types branch `add-xid8`, which is not in a pg_types
%% release yet. Remove this module when pg_types has it.

-behaviour(pg_types).

-export([init/1,
         encode/2,
         decode/2,
         type_spec/0]).

-include("dream_pgo_types.hrl").

-define(XID8_MAX, 18446744073709551615).

init(_Opts) ->
    {[<<"xid8send">>], []}.

encode(Xid, _) when is_integer(Xid) andalso Xid >= 0 andalso Xid =< ?XID8_MAX ->
    <<8:?int32, Xid:?uint64>>.

decode(<<Xid:?uint64>>, _) ->
    Xid.

type_spec() ->
    "Xid::0..18446744073709551615".
