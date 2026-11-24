-module(dream_pgo_type_cstring).

%% Mirrors the pg_types branch `add-cstring`, which is not in a pg_types
%% release yet. Remove this module when pg_types has it.

-behaviour(pg_types).

-export([init/1,
         encode/2,
         decode/2,
         type_spec/0]).

-include("dream_pgo_types.hrl").

%% cstring is sent as its text, like the types of pg_raw
init(_Opts) ->
    {[<<"cstring_send">>], []}.

encode(Text, TypeInfo) ->
    pg_raw:encode(Text, TypeInfo).

decode(Bin, TypeInfo) ->
    pg_raw:decode(Bin, TypeInfo).

type_spec() ->
    pg_raw:type_spec().
