-module(dream_pgo_type_jsonpath).

%% Mirrors the pg_types branch `add-jsonpath`, which is not in a pg_types
%% release yet. Remove this module when pg_types has it.

-behaviour(pg_types).

-export([init/1,
         encode/2,
         decode/2,
         type_spec/0]).

-include("dream_pgo_types.hrl").

-define(JSONPATH_VERSION_1, 1).

init(_Opts) ->
    {[<<"jsonpath_send">>], []}.

encode(Path, _) ->
    [<<(iolist_size(Path) + 1):?int32, ?JSONPATH_VERSION_1:?int8>> | Path].

decode(<<?JSONPATH_VERSION_1:?int8, Path/binary>>, _) ->
    Path.

type_spec() ->
    "iolist()".
