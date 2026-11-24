-module(dream_postgres_driver_type_range).

%% Replaces pg_range of pg_types 0.6.0. decode_range matched the length of
%% the lower bound against the typlen of the subtype, so a range over a type
%% of variable length (numrange) crashed (pg_types issue #21). Remove this
%% module when a pg_types release has the fix.

-behaviour(pg_types).

-export([init/1,
         encode/2,
         decode/2,
         type_spec/0]).

-include("dream_postgres_driver_types.hrl").
-include_lib("pg_types/include/pg_types.hrl").

-define(RANGE_EMPTY, 16#01).
-define(RANGE_LB_INC, 16#02).
-define(RANGE_UB_INC, 16#04).
-define(RANGE_LB_INF, 16#08).
-define(RANGE_UB_INF, 16#10).

init(_Opts) ->
    {[<<"range_send">>], []}.

encode(empty, _) ->
    [<<1:?int32, ?RANGE_EMPTY>>];
encode({{From, To}, {LowerInclusive, UpperInclusive}}, #type_info{pool=Pool, base_oid=BaseOid})
  when is_atom(LowerInclusive) ; is_atom(UpperInclusive) ->
    TypeInfo=#type_info{module=Mod} = pg_types:lookup_type_info(Pool, BaseOid),

    Flags = case {LowerInclusive, UpperInclusive} of
                {true, true} ->
                  ?RANGE_LB_INC bor ?RANGE_UB_INC;
                {false, true} ->
                  ?RANGE_UB_INC;
                {true, false} ->
                  ?RANGE_LB_INC;
                {false, false} ->
                  0
            end,

    {Data, Flags1} = case {From, To} of
                         {unbound, unbound} ->
                             {[], Flags bor ?RANGE_LB_INF bor ?RANGE_UB_INF};
                         {unbound, To} ->
                             {[Mod:encode(To, TypeInfo)], Flags bor ?RANGE_LB_INF};
                         {From, unbound} ->
                             {[Mod:encode(From, TypeInfo)], Flags bor ?RANGE_UB_INF};
                         {From, To} ->
                             {[Mod:encode(From, TypeInfo), Mod:encode(To, TypeInfo)], Flags}
                     end,
    [<<(iolist_size(Data) + 1):?int32, Flags1:?int8>>, Data];
encode({From, To}, TypeInfo) ->
    encode({{From, To}, {true, true}}, TypeInfo).

decode(<<?RANGE_EMPTY:?int8>>, _) ->
    empty;
decode(<<Flags:?int8, Rest/binary>>, #type_info{pool=Pool, base_oid=BaseOid}) ->
    case Flags band ?RANGE_EMPTY =/= 0 of
        true ->
            empty;
        false ->
            BaseTypeInfo = pg_types:lookup_type_info(Pool, BaseOid),
            decode_range(Flags, Rest, BaseTypeInfo)
    end.

type_spec() ->
    "empty | {{From::unbound | term(), To::unbound | term()}, {LowerInclusive::boolean(), UpperInclusive::boolean()}}".

%%

%% each bound has its own length, which is not the typlen of the subtype:
%% typlen is -1 for a type of variable length
decode_range(Flags, Bin, BaseTypeInfo=#type_info{module=Mod}) ->
    {LowerBound, Rest} = case 0 =/= Flags band ?RANGE_LB_INF of
                             true -> {unbound, Bin};
                             _ ->
                                 <<Len:?int32, From:Len/binary, More/binary>> = Bin,
                                 {Mod:decode(From, BaseTypeInfo), More}
                         end,
    UpperBound = case 0 =/= Flags band ?RANGE_UB_INF of
                     true ->
                         unbound;
                     _ ->
                         <<L:?int32, To:L/binary>> = Rest,
                         Mod:decode(To, BaseTypeInfo)
                 end,
    LowerInclusive = (Flags band ?RANGE_LB_INC) =/= 0,
    UpperInclusive = (Flags band ?RANGE_UB_INC) =/= 0,
    {{LowerBound, UpperBound}, {LowerInclusive, UpperInclusive}}.
