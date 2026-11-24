-module(dream_pgo_sup).

-behaviour(supervisor).

-export([start_link/0,
         start_child/2]).

-export([init/1]).

-define(SERVER, ?MODULE).

%%====================================================================
%% API functions
%%====================================================================

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%% The supervisor keeps the start arguments of each pool, so the password
%% goes in as a function (see dream_pgo_pool:prepare_pool_config/1).
start_child(Name, PoolConfig) ->
    case dream_pgo_pool:prepare_pool_config(PoolConfig) of
        {ok, PoolConfig1} ->
            supervisor:start_child(?SERVER, [Name, PoolConfig1]);
        {error, _} = Error ->
            Error
    end.

%%====================================================================
%% Supervisor callbacks
%%====================================================================

%% Child :: {Id,StartFunc,Restart,Shutdown,Type,Modules}
init([]) ->
    SupFlags = #{strategy => simple_one_for_one,
                 intensity => 5,
                 period => 10},
    ChildSpec = #{id => dream_pgo_pool,
                  start => {dream_pgo_pool, start_link, []},
                  shutdown => 1000},
    {ok, {SupFlags, [ChildSpec]}}.

%%====================================================================
%% Internal functions
%%====================================================================
