-module(dream_postgres_driver_type_int_vector).

%% Mirrors the pg_types branch `add-int2vector-oidvector`, which is not
%% in a pg_types release yet. Remove this module when pg_types has it.

-behaviour(pg_types).

-export([init/1,
         encode/2,
         decode/2,
         type_spec/0]).

-include("dream_postgres_driver_types.hrl").
-include_lib("pg_types/include/pg_types.hrl").

-define(INT2OID, 21).
-define(OIDOID, 26).

%% int2vector and oidvector are sent like a one dimensional array of int2 or
%% oid, but the lower bound must be 0 and there can be no NULLs
init(_Opts) ->
    {[<<"int2vectorsend">>, <<"oidvectorsend">>], []}.

encode(Values, #type_info{elem_oid=ElemOid}) when is_list(Values) ->
    Encoded = [<<1:?int32, 0:?int32, ElemOid:?int32, (length(Values)):?int32, 0:?int32>>,
               [encode_element(ElemOid, Value) || Value <- Values]],
    [<<(iolist_size(Encoded)):?int32>>, Encoded].

decode(<<1:?int32, _Flags:?int32, ElemOid:?int32, _Length:?int32, _LBound:?int32, Elements/binary>>, _) ->
    [decode_element(ElemOid, Element) || <<Size:?int32, Element:Size/binary>> <= Elements].

type_spec() ->
    "[integer()]".

%%

encode_element(?INT2OID, Value) when is_integer(Value) ->
    <<2:?int32, Value:?int16>>;
encode_element(?OIDOID, Value) when is_integer(Value) ->
    <<4:?int32, Value:?uint32>>.

decode_element(?INT2OID, <<Value:?int16>>) ->
    Value;
decode_element(?OIDOID, <<Value:?uint32>>) ->
    Value.
