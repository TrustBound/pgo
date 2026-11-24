-module(dream_postgres_driver_test_money_type).

%% A user type module for dream_postgres_driver_types_SUITE. It reads money as
%% {test_money, Cents}, so the suite can see that a module the user sets in
%% the pg_types `modules` setting replaces the module that dream_postgres_driver carries.

-behaviour(pg_types).

-export([init/1,
         encode/2,
         decode/2,
         type_spec/0]).

init(_Opts) ->
    {[<<"cash_send">>], []}.

encode({test_money, N}, _) when is_integer(N) ->
    <<8:32/big-signed, N:64/big-signed>>.

decode(<<N:64/big-signed>>, _) ->
    {test_money, N}.

type_spec() ->
    "{test_money, Cents::integer()}".
