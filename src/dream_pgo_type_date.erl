-module(dream_pgo_type_date).

%% Replaces pg_date of pg_types 0.6.0, which decoded 'infinity'::date and
%% '-infinity'::date to wrong dates and could not encode them. They are the
%% atoms infinity and '-infinity', as pg_timestamp does for timestamps.
%% Remove this module when a pg_types release has the fix.

-behaviour(pg_types).

-export([init/1,
         encode/2,
         decode/2,
         type_spec/0]).

-include("dream_pgo_types.hrl").

-define(POSTGRESQL_GD_EPOCH, 730485). % ?_value(calendar:date_to_gregorian_days({2000,1,1}))).

%% DATEVAL_NOEND and DATEVAL_NOBEGIN of PostgreSQL
-define(DATE_INFINITY, 16#7FFFFFFF).
-define(DATE_MINUS_INFINITY, -16#80000000).

init(_Opts) ->
    {[<<"date_send">>], []}.

encode(Date, _TypeInfo) ->
    <<4:?int32, (encode_date(Date)):?int32>>.

decode(<<?DATE_INFINITY:?int32>>, _TypeInfo) ->
    infinity;
decode(<<?DATE_MINUS_INFINITY:?int32>>, _TypeInfo) ->
    '-infinity';
decode(<<Date:?int32>>, _TypeInfo) ->
    calendar:gregorian_days_to_date(Date + ?POSTGRESQL_GD_EPOCH).

encode_date(infinity) ->
    ?DATE_INFINITY;
encode_date('-infinity') ->
    ?DATE_MINUS_INFINITY;
encode_date(Date) ->
    calendar:date_to_gregorian_days(Date) - ?POSTGRESQL_GD_EPOCH.

type_spec() ->
    "infinity | '-infinity' | {Year::integer() >= 0, Month::1..12, Day::1..31}".
