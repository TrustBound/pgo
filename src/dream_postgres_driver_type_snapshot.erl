-module(dream_postgres_driver_type_snapshot).

%% Mirrors the pg_types branch `add-snapshot`, which is not in a pg_types
%% release yet. Remove this module when pg_types has it.

-behaviour(pg_types).

-export([init/1,
         encode/2,
         decode/2,
         type_spec/0]).

-include("dream_postgres_driver_types.hrl").

%% txid_snapshot is the older name of pg_snapshot, both are sent the same way
init(_Opts) ->
    {[<<"pg_snapshot_send">>, <<"txid_snapshot_send">>], []}.

encode(#{xmin := Xmin, xmax := Xmax, xip := Xip}, _) when is_list(Xip) ->
    Encoded = [<<(length(Xip)):?int32, Xmin:?uint64, Xmax:?uint64>>,
               [<<X:?uint64>> || X <- Xip]],
    [<<(iolist_size(Encoded)):?int32>>, Encoded].

decode(<<_NXip:?int32, Xmin:?uint64, Xmax:?uint64, Xip/binary>>, _) ->
    #{xmin => Xmin,
      xmax => Xmax,
      xip => [X || <<X:?uint64>> <= Xip]}.

type_spec() ->
    "#{xmin := Xmin::integer(), xmax := Xmax::integer(), xip := [Xid::integer()]}".
