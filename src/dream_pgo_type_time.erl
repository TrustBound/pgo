-module(dream_pgo_type_time).

%% Replaces pg_time of pg_types 0.6.0, which crashed on '24:00:00'::time:
%% calendar:seconds_to_time/1 takes no more than 86399 seconds. Remove this
%% module when a pg_types release has the fix.

-behaviour(pg_types).

-export([init/1,
         encode/2,
         decode/2,
         type_spec/0,
         encode_time/1,
         decode_time/1]).

-include("dream_pgo_types.hrl").

-define(MINS_PER_HOUR, 60).
-define(SECS_PER_MINUTE, 60).
-define(USECS_PER_SEC, 1000000).
-define(USECS_PER_DAY, 86400000000).

init(_Opts) ->
    {[<<"time_send">>], []}.

encode(Time={Hours, Minutes, Seconds}, _TypeInfo) when is_integer(Hours) ,
                                                       is_integer(Minutes) ,
                                                       (is_integer(Seconds) orelse is_float(Seconds)) ->
    <<8:?int32, (encode_time(Time)):?int64>>.

decode(Bin, _TypeInfo) ->
    decode_time(Bin).

type_spec() ->
    "{Hours::integer(), Minutes::integer(), Seconds::integer() | float()} | 0".

%%

%% PostgreSQL allows 24:00:00 as the end of a day, for time and timetz
decode_time(<<?USECS_PER_DAY:?int64>>) ->
    {24, 0, 0};
decode_time(<<Time:?int64>>) ->
    Seconds = Time div ?USECS_PER_SEC,
    USecs = Time rem ?USECS_PER_SEC,
    {Hour, Min, Secs} = calendar:seconds_to_time(Seconds),
    case USecs of
        0 -> {Hour, Min, Secs};
        _ -> {Hour, Min, Secs + USecs / ?USECS_PER_SEC}
    end.

encode_time(Time) ->
    pg_time:encode_time(Time).
