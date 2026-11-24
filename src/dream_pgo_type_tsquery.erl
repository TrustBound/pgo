-module(dream_pgo_type_tsquery).

%% Mirrors the pg_types branch `add-tsquery`, which is not in a pg_types
%% release yet. Remove this module when pg_types has it.

-behaviour(pg_types).

-export([init/1,
         encode/2,
         decode/2,
         type_spec/0]).

-include("dream_pgo_types.hrl").

-define(QI_VAL, 1).
-define(QI_OPR, 2).

-define(OP_NOT, 1).
-define(OP_AND, 2).
-define(OP_OR, 3).
-define(OP_PHRASE, 4).

init(_Opts) ->
    {[<<"tsquerysend">>], []}.

encode(empty, _) ->
    <<4:?int32, 0:?int32>>;
encode(Query, _) ->
    Items = encode_item(Query),
    Encoded = [<<(length(Items)):?int32>>, Items],
    [<<(iolist_size(Encoded)):?int32>>, Encoded].

decode(<<0:?int32>>, _) ->
    empty;
decode(<<_Count:?int32, Items/binary>>, _) ->
    {Query, <<>>} = decode_item(Items),
    Query.

type_spec() ->
    "empty | Query when Query :: {Lexeme::binary(), Weights::['A' | 'B' | 'C' | 'D'], Prefix::boolean()} "
        "| {'not', Query} | {'and', Query, Query} | {'or', Query, Query} | {phrase, Distance::integer(), Query, Query}".

%%

%% the items are sent in prefix order, each operator is followed by its
%% right operand and then by its left operand
encode_item({Lexeme, Weights, Prefix}) when is_binary(Lexeme) ,
                                            is_list(Weights) ,
                                            is_boolean(Prefix) ->
    [[<<?QI_VAL:?int8, (encode_weights(Weights)):?int8, (encode_prefix(Prefix)):?int8>>, Lexeme, 0]];
encode_item({'not', Query}) ->
    [<<?QI_OPR:?int8, ?OP_NOT:?int8>> | encode_item(Query)];
encode_item({'and', Left, Right}) ->
    [<<?QI_OPR:?int8, ?OP_AND:?int8>> | encode_item(Right) ++ encode_item(Left)];
encode_item({'or', Left, Right}) ->
    [<<?QI_OPR:?int8, ?OP_OR:?int8>> | encode_item(Right) ++ encode_item(Left)];
encode_item({phrase, Distance, Left, Right}) ->
    [<<?QI_OPR:?int8, ?OP_PHRASE:?int8, Distance:?uint16>> | encode_item(Right) ++ encode_item(Left)].

decode_item(<<?QI_VAL:?int8, Weights:?int8, Prefix:?int8, Rest/binary>>) ->
    [Lexeme, Rest1] = binary:split(Rest, <<0>>),
    {{Lexeme, decode_weights(Weights), Prefix =:= 1}, Rest1};
decode_item(<<?QI_OPR:?int8, ?OP_NOT:?int8, Rest/binary>>) ->
    {Query, Rest1} = decode_item(Rest),
    {{'not', Query}, Rest1};
decode_item(<<?QI_OPR:?int8, ?OP_AND:?int8, Rest/binary>>) ->
    {Right, Rest1} = decode_item(Rest),
    {Left, Rest2} = decode_item(Rest1),
    {{'and', Left, Right}, Rest2};
decode_item(<<?QI_OPR:?int8, ?OP_OR:?int8, Rest/binary>>) ->
    {Right, Rest1} = decode_item(Rest),
    {Left, Rest2} = decode_item(Rest1),
    {{'or', Left, Right}, Rest2};
decode_item(<<?QI_OPR:?int8, ?OP_PHRASE:?int8, Distance:?uint16, Rest/binary>>) ->
    {Right, Rest1} = decode_item(Rest),
    {Left, Rest2} = decode_item(Rest1),
    {{phrase, Distance, Left, Right}, Rest2}.

encode_prefix(true) ->
    1;
encode_prefix(false) ->
    0.

%% the weights of a lexeme are a bit mask, A is the highest bit
encode_weights(Weights) ->
    lists:foldl(fun(Weight, Acc) -> Acc bor weight_bit(Weight) end, 0, Weights).

decode_weights(Bits) ->
    [Weight || Weight <- ['A', 'B', 'C', 'D'], Bits band weight_bit(Weight) =/= 0].

weight_bit('A') ->
    8;
weight_bit('B') ->
    4;
weight_bit('C') ->
    2;
weight_bit('D') ->
    1.
