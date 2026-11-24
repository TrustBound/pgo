%%%-------------------------------------------------------------------
%% @doc dream_postgres_driver application
%% @end
%%%-------------------------------------------------------------------
-module(dream_postgres_driver_app).

-behaviour(application).

-export([start/2, stop/1]).

%%====================================================================
%% API
%%====================================================================

start(_StartType, _StartArgs) ->
    %% before any pool loads its types
    ok = dream_postgres_driver_types:set_modules(),
    dream_postgres_driver_query_cache:start_link(),
    Pools = application:get_env(dream_postgres_driver, pools, []),
    {ok, Pid} = dream_postgres_driver_sup:start_link(),
    [{ok, _} = dream_postgres_driver_sup:start_child(Name, PoolConfig) || {Name, PoolConfig} <- Pools],
    {ok, Pid}.

%%--------------------------------------------------------------------
stop(_State) ->
    ok.

%%====================================================================
%% Internal functions
%%====================================================================
