%%%-------------------------------------------------------------------
%% @doc Reads a `numeric' value as its exact decimal text.
%%
%% pg_types decodes a `numeric' to an integer or to a float, and a float
%% cannot hold every `numeric'. With the decode option `numeric_as_text',
%% dream_postgres_driver decodes each `numeric' with this module instead.
%% The text is the same text that PostgreSQL's `numeric_out' writes, thus
%% the same as `value::text': the sign, the full display scale with its
%% trailing zeros, and `NaN', `Infinity' and `-Infinity'.
%%
%% This module is not in the pg_types `modules' setting, because the
%% default decode of a `numeric' does not change.
%% @end
%%%-------------------------------------------------------------------
-module(dream_postgres_driver_numeric_text).

-export([decode/2,
         to_text/1,
         type_info/1]).

-include_lib("pg_types/include/pg_types.hrl").

-define(NBASE_DIGITS, 4).
-define(SIGN_POSITIVE, 16#0000).
-define(SIGN_NEGATIVE, 16#4000).
-define(SIGN_NAN, 16#C000).
-define(SIGN_POSITIVE_INFINITY, 16#D000).
-define(SIGN_NEGATIVE_INFINITY, 16#F000).

%% @doc The pg_types decode function. It ignores the type info.
-spec decode(binary(), term()) -> binary().
decode(Binary, _TypeInfo) ->
    to_text(Binary).

%% @doc Converts the binary form of a `numeric' (the body that
%% `numeric_send' writes) to the text that `numeric_out' writes.
-spec to_text(binary()) -> binary().
to_text(<<_NDigits:16/unsigned, _Weight:16/signed, ?SIGN_NAN:16/unsigned, _/binary>>) ->
    <<"NaN">>;
to_text(<<_NDigits:16/unsigned, _Weight:16/signed, ?SIGN_POSITIVE_INFINITY:16/unsigned, _/binary>>) ->
    <<"Infinity">>;
to_text(<<_NDigits:16/unsigned, _Weight:16/signed, ?SIGN_NEGATIVE_INFINITY:16/unsigned, _/binary>>) ->
    <<"-Infinity">>;
to_text(<<NDigits:16/unsigned, Weight:16/signed, Sign:16/unsigned, DScale:16/unsigned,
          Digits:NDigits/binary-unit:16>>) when Sign =:= ?SIGN_POSITIVE;
                                                Sign =:= ?SIGN_NEGATIVE ->
    Coefficient = digits_to_integer(Digits, 0),
    %% the value is Coefficient * 10 ^ Exponent
    Exponent = ?NBASE_DIGITS * (Weight - NDigits + 1),
    %% the value times 10 ^ DScale, truncated as numeric_out truncates
    Scaled = shift(Coefficient, Exponent + DScale),
    Unsigned = with_scale(integer_to_binary(Scaled), DScale),
    %% PostgreSQL keeps no negative zero: numeric_out writes "-" only when
    %% a digit is not zero
    case Sign =:= ?SIGN_NEGATIVE andalso Scaled =/= 0 of
        true -> <<"-", Unsigned/binary>>;
        false -> Unsigned
    end.

%% @doc Returns the type info that decodes with this module, for a
%% `numeric' (or a domain over it) or an array of `numeric'. Any other
%% type info comes back the same.
-spec type_info(#type_info{}) -> #type_info{}.
type_info(TypeInfo=#type_info{typsend = <<"numeric_send">>}) ->
    TypeInfo#type_info{module=?MODULE};
type_info(TypeInfo=#type_info{elem_type=ElemTypeInfo=#type_info{typsend = <<"numeric_send">>}}) ->
    TypeInfo#type_info{elem_type=ElemTypeInfo#type_info{module=?MODULE}};
type_info(TypeInfo) ->
    TypeInfo.

%%

digits_to_integer(<<>>, Acc) ->
    Acc;
digits_to_integer(<<Digit:16/unsigned, Rest/binary>>, Acc) ->
    digits_to_integer(Rest, Acc * 10000 + Digit).

shift(Integer, Places) when Places >= 0 ->
    Integer * pow10(Places);
shift(Integer, Places) ->
    Integer div pow10(-Places).

pow10(N) ->
    binary_to_integer(<<"1", (binary:copy(<<"0">>, N))/binary>>).

%% puts the decimal point before the last Scale digits, with at least one
%% digit before the point
with_scale(Digits, 0) ->
    Digits;
with_scale(Digits, Scale) ->
    Padded = pad(Digits, Scale + 1),
    IntegerSize = byte_size(Padded) - Scale,
    <<Integer:IntegerSize/binary, Fraction/binary>> = Padded,
    <<Integer/binary, ".", Fraction/binary>>.

pad(Digits, Size) when byte_size(Digits) >= Size ->
    Digits;
pad(Digits, Size) ->
    <<(binary:copy(<<"0">>, Size - byte_size(Digits)))/binary, Digits/binary>>.
