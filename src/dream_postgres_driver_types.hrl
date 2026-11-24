%% The binary forms that the dream_postgres_driver_type_* modules use. A copy of
%% pg_types' src/pg_protocol.hrl, which pg_types does not install, with uint64.
-define(int8, 1/big-signed-unit:8).
-define(int16, 1/big-signed-unit:16).
-define(int32, 1/big-signed-unit:32).
-define(int64, 1/big-signed-unit:64).

-define(float64, 1/big-float-unit:64).

-define(uint16, 1/big-unsigned-unit:16).
-define(uint32, 1/big-unsigned-unit:32).
-define(uint64, 1/big-unsigned-unit:64).
