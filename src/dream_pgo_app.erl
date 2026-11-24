%%%-------------------------------------------------------------------
%% @doc dream_pgo application
%% @end
%%%-------------------------------------------------------------------
-module(dream_pgo_app).

-behaviour(application).

-export([start/2, stop/1]).

%%====================================================================
%% API
%%====================================================================

start(_StartType, _StartArgs) ->
    %% before any pool loads its types
    ok = dream_pgo_types:set_modules(),
    dream_pgo_query_cache:start_link(),
    Pools = application:get_env(dream_pgo, pools, []),
    {ok, Pid} = dream_pgo_sup:start_link(),
    [{ok, _} = dream_pgo_sup:start_child(Name, PoolConfig) || {Name, PoolConfig} <- Pools],
    {ok, Pid}.

%%--------------------------------------------------------------------
stop(_State) ->
    ok.

%%====================================================================
%% Internal functions
%%====================================================================
