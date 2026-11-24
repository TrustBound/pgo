-module(dream_pgo_type_anyarray).

%% Reads anyarray values, such as the columns most_common_vals and
%% histogram_bounds of pg_stats. The type of the elements is not known from
%% the column, so this module reads the element oid from the array binary,
%% looks it up in the types of the pool and decodes with pg_array. pg_types
%% has no reader for anyarray. Remove this module when a pg_types release has
%% one.
%%
%% PostgreSQL does not accept a parameter of type anyarray, so encode only
%% gives the encoding error of pg_types.

-behaviour(pg_types).

-export([init/1,
         encode/2,
         decode/2,
         type_spec/0]).

-include("dream_pgo_types.hrl").
-include_lib("pg_types/include/pg_types.hrl").

init(_Opts) ->
    {[<<"anyarray_send">>, <<"anycompatiblearray_send">>], []}.

encode(Value, TypeInfo) ->
    erlang:error(#{error => badarg_encoding,
                   module => pg_types,
                   value => Value,
                   type_info => TypeInfo}).

decode(Bin = <<_Dimensions:?int32, _Flags:?int32, ElemOid:?int32, _/binary>>,
       TypeInfo=#type_info{pool=Pool}) ->
    ElemTypeInfo = pg_types:lookup_type_info(Pool, ElemOid),
    pg_array:decode(Bin, TypeInfo#type_info{elem_type=ElemTypeInfo}).

type_spec() ->
    "no value, PostgreSQL does not accept a parameter of type anyarray".
