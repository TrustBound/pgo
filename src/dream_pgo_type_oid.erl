-module(dream_pgo_type_oid).

%% Mirrors the pg_types branches `fix-oid`, `fix-oid-decode` and
%% `add-reg-types`, which are not in a pg_types release yet. Remove this
%% module when pg_types has them.

-behaviour(pg_types).

-export([init/1,
         encode/2,
         decode/2,
         type_spec/0]).

-include("dream_pgo_types.hrl").

-define(OID_MAX, 4294967295).

%% Replaces pg_oid, which registers idsend instead of oidsend and decodes
%% to the binary instead of an integer.
init(_Opts) ->
    {[<<"oidsend">>, <<"regprocsend">>, <<"regproceduresend">>,
      <<"regopersend">>, <<"regoperatorsend">>, <<"regclasssend">>,
      <<"regtypesend">>, <<"xidsend">>, <<"cidsend">>,
      <<"regnamespacesend">>, <<"regrolesend">>, <<"regconfigsend">>,
      <<"regdictionarysend">>, <<"regcollationsend">>], []}.

encode(Oid, _) when is_integer(Oid) andalso Oid >= 0 andalso Oid =< ?OID_MAX ->
    <<4:?int32, Oid:?uint32>>.

decode(<<Oid:?uint32>>, _) ->
    Oid.

type_spec() ->
    "Oid::0..4294967295".
