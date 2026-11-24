%%%-------------------------------------------------------------------
%% @doc The type modules that dream_postgres_driver adds to pg_types.
%%
%% pg_types builds the type map of a pool from its own modules and then
%% from the modules in its `modules' application setting. When two modules
%% register the same send function, the later module is used. dream_postgres_driver
%% puts its own modules first in that setting and keeps the modules that
%% the user set after them, so a user module still replaces a dream_postgres_driver
%% module.
%%
%% Each module mirrors a change to pg_types that is not in a pg_types
%% release. Remove a module when the pg_types release that dream_postgres_driver uses
%% has the change.
%% @end
%%%-------------------------------------------------------------------
-module(dream_postgres_driver_types).

-export([modules/0,
         set_modules/0]).

%% @doc The type modules that dream_postgres_driver adds, in the order they are used.
-spec modules() -> [module()].
modules() ->
    [dream_postgres_driver_type_oid,
     dream_postgres_driver_type_timetz,
     dream_postgres_driver_type_money,
     dream_postgres_driver_type_macaddr8,
     dream_postgres_driver_type_box,
     dream_postgres_driver_type_xml,
     dream_postgres_driver_type_cstring,
     dream_postgres_driver_type_jsonpath,
     dream_postgres_driver_type_lsn,
     dream_postgres_driver_type_xid8,
     dream_postgres_driver_type_snapshot,
     dream_postgres_driver_type_void,
     dream_postgres_driver_type_int_vector,
     dream_postgres_driver_type_multirange,
     dream_postgres_driver_type_tsquery,
     dream_postgres_driver_type_range,
     dream_postgres_driver_type_time,
     dream_postgres_driver_type_interval,
     dream_postgres_driver_type_date,
     dream_postgres_driver_type_anyarray].

%% @doc Sets the pg_types `modules' setting to the dream_postgres_driver modules,
%% followed by the modules that were already set and are not dream_postgres_driver
%% modules. Call it before a pool loads its types. dream_postgres_driver_app calls it
%% at the start of the application.
-spec set_modules() -> ok.
set_modules() ->
    Carried = modules(),
    UserModules = [Module || Module <- application:get_env(pg_types, modules, []),
                             not lists:member(Module, Carried)],
    application:set_env(pg_types, modules, Carried ++ UserModules).
