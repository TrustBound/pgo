-module(dream_postgres_driver_numeric_SUITE).

%% The exact text of a numeric: the decode option `numeric_as_text' and a
%% binary parameter of type numeric.
%%
%% The group `versions' compares the driver with the text that PostgreSQL
%% itself writes, for a fixed-seed set of random values, on each server in
%% the environment variable DREAM_POSTGRES_DRIVER_NUMERIC_PORTS (a comma
%% list of ports, such as "5416,5417,5418,5419"). The user, the password and
%% the database come from DREAM_POSTGRES_DRIVER_NUMERIC_USER,
%% DREAM_POSTGRES_DRIVER_NUMERIC_PASSWORD and
%% DREAM_POSTGRES_DRIVER_NUMERIC_DATABASE. Without the ports, the group runs
%% on the default test server.

-compile(export_all).

-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-define(TEXT, #{decode_opts => [numeric_as_text]}).
-define(RANDOM_VALUES, 2000).

all() ->
    [{group, fixed}, {group, versions}].

groups() ->
    [{fixed, [], [default_decode_unchanged, decode_scale, decode_zero_with_scale,
                  decode_integer, decode_negative, decode_large, decode_small,
                  decode_special, decode_null, decode_array, decode_map_rows,
                  decode_other_types_unchanged, decode_domain, option_false,
                  pool_default_option, decode_to_text_negative_zero,
                  param_text, param_text_scale, param_text_special,
                  param_text_underscore, param_text_malformed,
                  param_float_unchanged, param_integer_unchanged,
                  param_text_to_text_column]},
     {versions, [], [random_decode, random_encode]}].

init_per_suite(Config) ->
    {ok, _} = application:ensure_all_started(dream_postgres_driver),
    {ok, _} = dream_postgres_driver_sup:start_child(dream_postgres_driver_default,
                                                    #{pool_size => 1,
                                                      database => "test",
                                                      user => "test",
                                                      password => "password"}),
    Config.

end_per_suite(_Config) ->
    application:stop(dream_postgres_driver),
    ok.

init_per_group(versions, Config) ->
    Pools = case os:getenv("DREAM_POSTGRES_DRIVER_NUMERIC_PORTS") of
                false ->
                    [dream_postgres_driver_default];
                Ports ->
                    [start_version_pool(list_to_integer(Port))
                     || Port <- string:lexemes(Ports, ",")]
            end,
    [{pools, Pools} | Config];
init_per_group(_Group, Config) ->
    Config.

end_per_group(_Group, _Config) ->
    ok.

start_version_pool(Port) ->
    Pool = list_to_atom("numeric_" ++ integer_to_list(Port)),
    {ok, _} = dream_postgres_driver_sup:start_child(
                Pool, #{pool_size => 1,
                        port => Port,
                        database => os:getenv("DREAM_POSTGRES_DRIVER_NUMERIC_DATABASE", "dream_test"),
                        user => os:getenv("DREAM_POSTGRES_DRIVER_NUMERIC_USER", "dream"),
                        password => os:getenv("DREAM_POSTGRES_DRIVER_NUMERIC_PASSWORD", "dream")}),
    Pool.

%% fixed values

default_decode_unchanged(_Config) ->
    ?assertEqual([{1.5, 42, 'NaN'}],
                 rows("select 1.50::numeric(20,2), 42::numeric, 'NaN'::numeric", #{})).

decode_scale(_Config) ->
    ?assertEqual([{<<"1.50">>}], text_rows("select 1.50::numeric(20,2)")).

decode_zero_with_scale(_Config) ->
    ?assertEqual([{<<"0.00">>, <<"0">>, <<"0.000">>}],
                 text_rows("select 0::numeric(20,2), 0::numeric, '-0.000'::numeric")).

decode_integer(_Config) ->
    ?assertEqual([{<<"42">>, <<"10000">>, <<"123456789012345678901234567890">>}],
                 text_rows("select 42::numeric, 10000::numeric, "
                           "123456789012345678901234567890::numeric")).

decode_negative(_Config) ->
    ?assertEqual([{<<"-12345678901234567.89">>, <<"-0.5">>}],
                 text_rows("select -12345678901234567.89::numeric, -0.5::numeric")).

decode_large(_Config) ->
    ?assertEqual([{<<"1", (binary:copy(<<"0">>, 100))/binary>>}],
                 text_rows("select 1e100::numeric")).

decode_small(_Config) ->
    ?assertEqual([{<<"0.000000000000000000001">>, <<"0.00010">>}],
                 text_rows("select 0.000000000000000000001::numeric, 0.00010::numeric")).

decode_special(_Config) ->
    ?assertEqual([{<<"NaN">>, <<"Infinity">>, <<"-Infinity">>}],
                 text_rows("select 'NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric")).

decode_null(_Config) ->
    ?assertEqual([{null}], text_rows("select null::numeric")).

decode_array(_Config) ->
    ?assertEqual([{[<<"1.50">>, null, <<"NaN">>]}],
                 text_rows("select array[1.50, null, 'NaN']::numeric[]")).

decode_map_rows(_Config) ->
    ?assertEqual([#{<<"n">> => <<"2.00">>}],
                 rows("select 2.00::numeric as n",
                      #{decode_opts => [numeric_as_text, return_rows_as_maps]})).

decode_other_types_unchanged(_Config) ->
    ?assertEqual([{1, 1.5, <<"x">>, {{1.5, 2.5}, {true, false}}}],
                 text_rows("select 1::int4, 1.5::float8, 'x'::text, '[1.5,2.5)'::numrange")).

decode_domain(_Config) ->
    #{command := create} = dream_postgres_driver:query(
                             "create domain numeric_text_price as numeric(10,3)"),
    try
        ?assertEqual([{<<"1.500">>}], text_rows("select 1.5::numeric_text_price"))
    after
        dream_postgres_driver:query("drop domain numeric_text_price")
    end.

option_false(_Config) ->
    ?assertEqual([{1.5}], rows("select 1.50::numeric",
                               #{decode_opts => [{numeric_as_text, false}]})).

pool_default_option(_Config) ->
    Pool = numeric_text_default,
    {ok, _} = dream_postgres_driver_sup:start_child(Pool, #{pool_size => 1,
                                                            database => "test",
                                                            user => "test",
                                                            password => "password",
                                                            decode_opts => [numeric_as_text]}),
    ?assertEqual([{<<"1.50">>}], rows("select 1.50::numeric", #{pool => Pool})).

decode_to_text_negative_zero(_Config) ->
    %% the server never sends a negative zero, but if a value has the
    %% negative sign and no digit, the text has no sign, as in numeric_out
    ?assertEqual(<<"0.00">>,
                 dream_postgres_driver_numeric_text:to_text(<<0:16, 0:16, 16#4000:16, 2:16>>)).

param_text(_Config) ->
    ?assertEqual([{<<"12345678901234567.89">>}],
                 rows("select ($1::numeric)::text", [<<"12345678901234567.89">>], #{})).

param_text_scale(_Config) ->
    ?assertEqual([{<<"1.500">>}],
                 rows("select $1::numeric", [<<"1.500">>], ?TEXT)).

param_text_special(_Config) ->
    ?assertEqual([{<<"NaN">>, <<"Infinity">>, <<"-Infinity">>}],
                 rows("select $1::numeric, $2::numeric, $3::numeric",
                      [<<"NaN">>, <<"Infinity">>, <<"-Infinity">>], ?TEXT)).

param_text_underscore(_Config) ->
    ?assertEqual([{<<"1000000.5">>}],
                 rows("select $1::numeric", [<<" 1_000_000.5 ">>], ?TEXT)).

%% a text that is not a number gets PostgreSQL's own error, and the
%% connection stays usable
param_text_malformed(_Config) ->
    {error, {pgsql_error, Fields}} = dream_postgres_driver:query("select $1::numeric", [<<"abc">>]),
    ?assertEqual({<<"22P02">>, <<"invalid input syntax for type numeric: \"abc\"">>},
                 {maps:get(code, Fields), maps:get(message, Fields)}),
    ?assertEqual([{<<"1">>}], rows("select $1::numeric", [<<"1">>], ?TEXT)).

param_float_unchanged(_Config) ->
    ?assertEqual([{<<"1.5">>}], rows("select ($1::numeric)::text", [1.5], #{})).

param_integer_unchanged(_Config) ->
    ?assertEqual([{<<"42">>}], rows("select ($1::numeric)::text", [42], #{})).

%% a binary for a parameter of another type keeps its encoding
param_text_to_text_column(_Config) ->
    ?assertEqual([{<<"1.50">>}], rows("select $1::text", [<<"1.50">>], #{})).

%% random values

random_decode(Config) ->
    rand:seed(exsss, {16, 17, 18}),
    Expressions = [random_expression() || _ <- lists:seq(1, ?RANDOM_VALUES)],
    [check_decode(Pool, Expressions) || Pool <- ?config(pools, Config)],
    ok.

random_encode(Config) ->
    rand:seed(exsss, {19, 20, 21}),
    Texts = [list_to_binary(random_text()) || _ <- lists:seq(1, ?RANDOM_VALUES)],
    [check_encode(Pool, Texts) || Pool <- ?config(pools, Config)],
    ok.

%% decoding gives exactly value::text from the same server
check_decode(Pool, Expressions) ->
    Batches = batches(Expressions, 100),
    Mismatches = lists:append(
                   [begin
                        Values = lists:join(", ", [["(", E, ")"] || E <- Batch]),
                        Rows = rows(["select v, v::text from (values ", Values, ") t(v)"],
                                    [], #{pool => Pool, decode_opts => [numeric_as_text]}),
                        [{E, D, T} || {E, {D, T}} <- lists:zip(Batch, Rows), D =/= T]
                    end || Batch <- Batches]),
    ct:pal("~p: ~p values decoded, ~p mismatches", [Pool, length(Expressions), length(Mismatches)]),
    ?assertEqual([], Mismatches).

%% a text parameter read back as $1::numeric::text is the server's own
%% reading of the same text as a literal
check_encode(Pool, Texts) ->
    Mismatches = [{Text, Param, Literal}
                  || Text <- Texts,
                     {Param, Literal} <- [encode_pair(Pool, Text)],
                     Param =/= Literal],
    ct:pal("~p: ~p values encoded, ~p mismatches", [Pool, length(Texts), length(Mismatches)]),
    ?assertEqual([], Mismatches).

encode_pair(Pool, Text) ->
    [{Param}] = rows("select $1::numeric::text", [Text], #{pool => Pool}),
    [{Literal}] = rows(["select '", Text, "'::numeric::text"], [], #{pool => Pool}),
    {Param, Literal}.

batches([], _Size) ->
    [];
batches(List, Size) when length(List) =< Size ->
    [List];
batches(List, Size) ->
    {Batch, Rest} = lists:split(Size, List),
    [Batch | batches(Rest, Size)].

%% an SQL expression of type numeric: a literal, a rounded literal (scale
%% and trailing zeros), a cast to numeric(P,S), or a product or quotient
%% (the server picks the scale)
random_expression() ->
    case rand:uniform(6) of
        1 ->
            literal(random_text());
        2 ->
            ["round(", literal(random_text()), ", ", integer_to_list(rand:uniform(41) - 11), ")"];
        3 ->
            Text = random_finite_text(),
            Scale = rand:uniform(20) - 1,
            Precision = 1000,
            [literal(Text), "::numeric(", integer_to_list(Precision), ",", integer_to_list(Scale), ")"];
        4 ->
            [literal(random_text()), " * ", literal(random_text())];
        5 ->
            [literal(random_text()), " / ", literal(random_nonzero_text())];
        6 ->
            literal(random_zero())
    end.

literal(Text) ->
    ["'", Text, "'::numeric"].

%% a numeric text: mostly plain decimals, with exponents, zeros and the
%% special values
random_text() ->
    case rand:uniform(20) of
        1 -> lists:nth(rand:uniform(8), ["NaN", "nan", "Infinity", "-Infinity", "inf",
                                         "+infinity", "-inf", "NAN"]);
        2 -> random_zero();
        _ -> random_finite_text()
    end.

random_nonzero_text() ->
    Text = random_finite_text(),
    case lists:all(fun(C) -> lists:member(C, "+-.0e123456789") end, Text)
        andalso lists:any(fun(C) -> lists:member(C, "123456789") end, mantissa(Text)) of
        true -> Text;
        false -> random_nonzero_text()
    end.

mantissa(Text) ->
    hd(string:split(string:lowercase(Text), "e")).

random_zero() ->
    sign() ++ "0" ++ case rand:uniform(2) of
                         1 -> "";
                         2 -> "." ++ lists:duplicate(rand:uniform(30), $0)
                     end.

random_finite_text() ->
    Sign = sign(),
    {IntegerSize, FractionSize} = sizes(),
    Integer = digits(IntegerSize),
    Fraction = digits(FractionSize),
    Mantissa = case {Integer, Fraction} of
                   {"", ""} -> "0";
                   {_, ""} -> Integer;
                   _ -> Integer ++ "." ++ Fraction
               end,
    Sign ++ Mantissa ++ exponent().

sign() ->
    case rand:uniform(3) of
        1 -> "-";
        2 -> "";
        3 -> lists:nth(rand:uniform(2), ["", "+"])
    end.

%% mostly short numbers, some long, a few very long
sizes() ->
    Max = case rand:uniform(10) of
              10 -> 400;
              9 -> 60;
              _ -> 20
          end,
    {rand:uniform(Max + 1) - 1, rand:uniform(Max + 1) - 1}.

digits(0) ->
    "";
digits(N) ->
    [$0 + rand:uniform(10) - 1 || _ <- lists:seq(1, N)].

exponent() ->
    case rand:uniform(6) of
        1 -> "e" ++ integer_to_list(rand:uniform(401) - 201);
        _ -> ""
    end.

%% helpers

text_rows(Query) ->
    rows(Query, [], ?TEXT).

rows(Query, Options) ->
    rows(Query, [], Options).

rows(Query, Params, Options) ->
    case dream_postgres_driver:query(Query, Params, Options) of
        #{rows := Rows} ->
            Rows;
        Other ->
            ct:fail({query_failed, binary:part(iolist_to_binary(Query), 0, min(200, iolist_size(Query))),
                     Params, Other})
    end.
