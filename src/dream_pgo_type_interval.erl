-module(dream_pgo_type_interval).

%% Replaces pg_interval of pg_types 0.6.0, which crashed on a negative
%% interval and on an interval of 24 hours or more: it decoded the time part
%% as a time of day. Mirrors the decode of pg_types pull request #25. Remove
%% this module when a pg_types release has the fix.
%%
%% PostgreSQL 17 and later also have the infinite intervals 'infinity' and
%% '-infinity'. They decode to the atoms infinity and '-infinity', as for
%% timestamps, and these atoms encode back.

-behaviour(pg_types).

-export([init/1,
         encode/2,
         decode/2,
         type_spec/0]).

-include("dream_pgo_types.hrl").

-define(USECS_PER_SEC, 1000000).
-define(SECS_PER_MINUTE, 60).
-define(SECS_PER_HOUR, 3600).

%% PostgreSQL sets all three fields of an infinite interval to the largest
%% or to the smallest integer (INTERVAL_NOEND and INTERVAL_NOBEGIN)
-define(INT64_MAX, 16#7FFFFFFFFFFFFFFF).
-define(INT64_MIN, -16#8000000000000000).
-define(INT32_MAX, 16#7FFFFFFF).
-define(INT32_MIN, -16#80000000).

init(_Opts) ->
    {[<<"interval_send">>], []}.

encode(infinity, _) ->
    <<16:?int32, ?INT64_MAX:?int64, ?INT32_MAX:?int32, ?INT32_MAX:?int32>>;
encode('-infinity', _) ->
    <<16:?int32, ?INT64_MIN:?int64, ?INT32_MIN:?int32, ?INT32_MIN:?int32>>;
encode({interval, {T, D, M}}, _) ->
    <<16:?int32, (pg_time:encode_time(T)):?int64, D:?int32, M:?int32>>;
encode({T, D, M}, _) ->
    <<16:?int32, (pg_time:encode_time(T)):?int64, D:?int32, M:?int32>>.

decode(<<?INT64_MAX:?int64, ?INT32_MAX:?int32, ?INT32_MAX:?int32>>, _) ->
    infinity;
decode(<<?INT64_MIN:?int64, ?INT32_MIN:?int32, ?INT32_MIN:?int32>>, _) ->
    '-infinity';
decode(<<Microseconds:?int64, Days:?int32, Months:?int32>>, _) ->
    {interval, {decode_interval_time(Microseconds), Days, Months}}.

%% the type spec of pg_interval, with the infinite intervals added
type_spec() ->
    "infinity | '-infinity' | {interval {{Hours::integer(), Minutes::integer(), "
    "Seconds::integer()}, Days::integer(), months::integer()}}".

%%

%% the hours can be 24 or more, and all three parts have the sign of the
%% interval: div and rem truncate toward zero
decode_interval_time(Microseconds) ->
    TotalSeconds = Microseconds div ?USECS_PER_SEC,
    USecs = Microseconds rem ?USECS_PER_SEC,
    Hours = TotalSeconds div ?SECS_PER_HOUR,
    Rest = TotalSeconds rem ?SECS_PER_HOUR,
    Minutes = Rest div ?SECS_PER_MINUTE,
    Seconds = Rest rem ?SECS_PER_MINUTE,
    case USecs of
        0 -> {Hours, Minutes, Seconds};
        _ -> {Hours, Minutes, Seconds + USecs / ?USECS_PER_SEC}
    end.
