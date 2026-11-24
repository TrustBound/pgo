-module(dream_postgres_driver_type_box).

%% Mirrors the pg_types branch `add-box`, which is not in a pg_types
%% release yet. Remove this module when pg_types has it.

-behaviour(pg_types).

-export([init/1,
         encode/2,
         decode/2,
         type_spec/0]).

-include("dream_postgres_driver_types.hrl").

init(_Opts) ->
    {[<<"box_send">>], []}.

%% two opposite corners, like a line segment. Postgres sends the upper right
%% corner as point1 and the lower left corner as point2.
encode(#{point1 := #{x := X1, y := Y1}, point2 := #{x := X2, y := Y2}}, _) ->
    <<32:?int32, X1:?float64, Y1:?float64, X2:?float64, Y2:?float64>>.

decode(<<X1:?float64, Y1:?float64, X2:?float64, Y2:?float64>>, _) ->
    #{point1 => #{x => X1, y => Y1},
      point2 => #{x => X2, y => Y2}}.

type_spec() ->
    "#{point1 := #{x := X1::float(), y := Y1::float()}, point2 := #{x := X2::float(), y := Y2::float()}}".
