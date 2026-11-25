# dream_postgres_driver

`dream_postgres_driver` is a fork of [pgo](https://github.com/erleans/pgo), the PostgreSQL client by the pgo authors. It is published on Hex as `dream_postgres_driver`. The fork starts from pgo v0.20.0.

What is different from pgo:

* Names. The OTP application, the Hex package and every module have the `dream_postgres_driver` prefix (`pgo` is `dream_postgres_driver`, `pgo_pool` is `dream_postgres_driver_pool`, and so on). The application environment key, the error tag `dream_postgres_driver_error`, the trace span names and the transaction key in the process dictionary also use the new prefix. Thus `dream_postgres_driver` and `pgo` can load in the same VM.
* The `application_name` fix. A caller's `application_name` in `connection_parameters` replaces the default. The driver sends the node name only when the caller gives no name. The startup packet never holds a parameter name two times, and the caller's order stays as it is. The pool option `application_name` (atom or iodata) also sets the name. An entry in `connection_parameters` takes precedence over the pool option.
* The null byte check. PostgreSQL strings in the startup packet cannot hold a null byte. A pool whose password, user, database, application name or `connection_parameters` hold a null byte does not start: `dream_postgres_driver:start_pool/2` returns `{error, {null_byte, password}}` or `{error, {null_byte, {parameter, Name}}}`. A password given as a function is known only at connect time: each connection attempt calls the function and checks the value it returns before it sends anything. A null byte in that value stops the connection attempt with `{error, {null_byte, password}}`. The error never holds the value.
* Exact `numeric`. pg_types decodes a `numeric` to an integer or a float, and a float can lose digits. With the decode option `numeric_as_text`, a `numeric` decodes to a binary with its exact text, the same text as `value::text`: `<<"1.50">>`, `<<"-0.000000000000000000001">>`, `<<"NaN">>`, `<<"Infinity">>`. A binary for a `numeric` parameter, such as `<<"12345678901234567.89">>`, goes to the server in text format, so PostgreSQL reads it with its own `numeric_in`: the value keeps all digits and its scale. A text that is not a number gets the error of PostgreSQL, such as `{error, {pgsql_error, #{code := <<"22P02">>, message := <<"invalid input syntax for type numeric: \"abc\"">>}}}`. An integer, a float and the atoms `'NaN'`, `infinity` and `'-infinity'` encode as before.
* `gleam.toml`. With this file, a Gleam project can use a local copy of `dream_postgres_driver` as a path dependency. rebar3 does not read it. The Gleam build tool compiles the `test/` directory of a path dependency, so the Common Test suites are in `ct/` (`{ct_opts, [{dir, "ct"}]}` in `rebar.config`). `rebar3 ct` runs them as before. The test certificates stay in `test/certs`.

* Type modules. pg_types 0.6.0 cannot read some built-in PostgreSQL types. dream_postgres_driver carries a reader for each in a `dream_postgres_driver_type_*` module, until a pg_types release has it. Each module names the pg_types change that it mirrors. At start, `dream_postgres_driver_app` puts these modules first in the pg_types `modules` setting. Modules that you set stay after them, so your module replaces a dream_postgres_driver module for the same type. The carried types:
  * `oid`, the `reg*` types, `xid` and `cid` decode to an integer.
  * `timetz` is `{{Hours, Minutes, Seconds}, OffsetSecondsEastOfUTC}`.
  * `money` is an integer in the smallest unit of the currency.
  * `macaddr8` is a tuple of 8 bytes.
  * `box` is `#{point1 => #{x, y}, point2 => #{x, y}}`.
  * `xml`, `cstring` and `jsonpath` are binaries.
  * `pg_lsn` and `xid8` are integers.
  * `pg_snapshot` and `txid_snapshot` are `#{xmin, xmax, xip}`.
  * `void` is the atom `void`.
  * `int2vector` and `oidvector` are lists of integers.
  * A multirange is a list of ranges, in the form of pg_types ranges.
  * `tsquery` is the query tree: `{Lexeme, Weights, Prefix}`, `{'not', Q}`, `{'and', Q, Q}`, `{'or', Q, Q}`, `{phrase, Distance, Q, Q}` or `empty`.
  * `anyarray` (such as `pg_stats.most_common_vals`) is a list. The element type comes from the element oid in the array. It is read only, because PostgreSQL does not accept a parameter of type `anyarray`.

  dream_postgres_driver also replaces four pg_types readers that crash or give wrong values:
  * `dream_postgres_driver_type_range` reads a range over a type of variable length, such as `numrange` (pg_types issue #21).
  * `dream_postgres_driver_type_time` reads `24:00:00` as `{24, 0, 0}`, for `time` and `timetz`.
  * `dream_postgres_driver_type_interval` reads negative intervals and intervals of 24 hours or more. The hours can be 24 or more, and the parts have the sign of the interval (pg_types pull request #25).
  * `dream_postgres_driver_type_date` reads and writes `infinity` and `'-infinity'`.

The rest of this README is the pgo README, with the module names changed.

## pgo

[![Tests](https://github.com/erleans/pgo/actions/workflows/ct.yml/badge.svg)](https://github.com/erleans/pgo/actions/workflows/ct.yml)
[![codecov](https://codecov.io/gh/erleans/pgo/branch/main/graph/badge.svg)](https://codecov.io/gh/erleans/pgo)
[![Hex.pm](https://img.shields.io/hexpm/v/pgo.svg?style=flat)](https://hex.pm/packages/pgo)

PG...Oh god not nother Postgres client in Erlang...

## Why

* No message passing. Clients checkout the socket and use it directly.
* Binary protocol with input oids cached.
* Simple and direct. Tries to limit runtime options as much as possible.
* Instrumented with [OpenTelemetry](https://opentelemetry.io/)
* Mix apps currently too hard to use in a Rebar3 project. 

## Requirements

Erlang/OTP 26 and above.

## Use

Pools defined in the `dream_postgres_driver` application's environment will be started on boot. You can also add pools dynamically with `dream_postgres_driver:start_pool/3`.

To try `dream_postgres_driver` simply modify `config/example.config` by replacing the `host`, `database`, `user` and `password` values for the database you wish to connect to:

```erlang
[
  {dream_postgres_driver, [{pools, [{dream_postgres_driver_default, #{pool_size => 10,
                                  host => "127.0.0.1",
                                  database => "test",
                                  user => "test"}}]}]}
].
```

`dream_postgres_driver_default` is the name of the pool, `size` is the number of connections to create for the pool. Or you can start the pool through `dream_postgres_driver:start_pool/2` which creates it as a child of `dream_postgres_driver`'s simple one for one:

``` erlang
> application:ensure_all_started(dream_postgres_driver).
{ok,[backoff,opentelemetry_api,pg_types,dream_postgres_driver]}
> dream_postgres_driver:start_pool(dream_postgres_driver_default, #{pool_size => 5, host => "127.0.0.1", database => "test", user => "test"}). 
```

Or start a pool as a child of your application's supervisor:

``` erlang
ChildSpec = #{id => dream_postgres_driver_pool,
              start => {dream_postgres_driver_pool, start_link, [Name, PoolConfig]},
              shutdown => 1000},
```

Then start a shell with `rebar3 shell`, it will boot the applications which will start the pool automatically if it is configured through `sys.config`.

```erlang
> dream_postgres_driver:query("select 1").
#{command => select, num_rows => 1, rows => [{1}]}
> dream_postgres_driver:transaction(fun() ->
>     dream_postgres_driver:query("INSERT INTO my_table(name) VALUES('Name 1')"),
>     dream_postgres_driver:query("INSERT INTO my_table(name) VALUES('Name 2')")
> end).
#{command => insert,num_rows => 1,rows => []}
```

## Options

Pool configuration includes the Postgres connection information, pool configuration like size and defaults for options used at query time. 

``` erlang
#{host => string(),
  port => integer(),
  user => string(),
  password => string(),
  database => string(),

  %% pool specific settings
  pool_size => integer(),
  queue_target => integer(),
  queue_interval => integer(),
  idle_interval => integer(),

  %% gen_tcp socket options
  socket_options => [gen_tcp:socket_option()],

  %% defaults for options used at query time
  queue => boolean(),
  trace => boolean(),
  decode_opts => [decode_option()],

  %% any value, kept with each connection
  extra => term()}
```

The query time options can also be set through options passed to `dream_postgres_driver:query/3`:

``` erlang
decode_fun() :: fun((row(), fields()) -> row()) | undefined.

decode_option() :: return_rows_as_maps | {return_rows_as_maps, boolean()} |
                   column_name_as_atom | {column_name_as_atom, boolean()} |
                   numeric_as_text | {numeric_as_text, boolean()} |
                   {decode_fun, decode_fun()}.
                         
#{pool => atom(),
  trace => boolean(),
  queue => boolean(),
  decode_opts => [decode_option()]}
```

### Query Options

* `pool` (default: `dream_postgres_driver_default`): Name of the pool to use for checking out a connection to the database.
* `return_rows_as_maps` (default: `false`): When `true` each row is returned as a map of column name to value instead of a list of values.
* `column_name_as_atom` (default: `false`): If `true` converts each column name in the result to an atom.
* `numeric_as_text` (default: `false`): When `true`, each `numeric` value (also in an array or a domain) decodes to a binary with its exact decimal text, the same text as `value::text` in PostgreSQL: `<<"1.50">>`, `<<"NaN">>`, `<<"Infinity">>`, `<<"-Infinity">>`. When `false`, a `numeric` decodes to an integer or a float, and a float can lose digits.
* `decode_fun` (default: `undefined`): Optional function for performing transformations on each row in a result. It must be a 2-arity function returning a list or map for the row and takes the row (as a list or map) and a list of `#row_description_field{}` records.
* `queue` (default: `true`): Whether to wait for a connection from the pool if none are available.
* `trace` (default: `false`): `dream_postgres_driver` is instrumented with [OpenTelemetry](https://opencensus.io/) and when this option is `true` a span will be created (if sampled).

### Database Settings

* `host` (default: `127.0.0.1`): Database server hostname.
* `port` (default: 5432): Port the server is listening on.
* `user`: Username to connect to database as.
* `password`: Password for the user.
* `database`: Name of database to use.
* `ssl` (default: `false`): Whether to use SSL or not.
* `ssl_options`: List of SSL options to use if `ssl` is `true`. See the [Erlang SSL connect](http://erlang.org/doc/man/ssl.html#connect-2) options.
* `connection_parameters` (default: `[]`): List of 2-tuples, where key and value must be binary strings. You can include any Postgres connection parameter here, such as `{<<"application_name">>, <<"myappname">>}` and `{<<"timezone">>, <<"GMT">>}`.
* `application_name` (default: `node()`): The `application_name` the server shows for the connection, as an atom or iodata. An `application_name` entry in `connection_parameters` takes precedence over this option.

### Pool Settings

* `pool_size` (default: 1): Number of connections to keep open with the database
* `queue_target` (default: 50) and `queue_interval` (default: 1000): Checking out connections is handled through a queue. If it takes longer than `queue_target` to get out of the queue for longer than `queue_interval` then the `queue_target` will be doubled and checkouts will start to be dropped if that target is surpassed.
* `idle_interval` (default: 1000): The database is pinged every `idle_interval` when the connection is idle.
* `extra` (default: `undefined`): Any value. `dream_postgres_driver` does not use it. Each connection of the pool keeps it, and `dream_postgres_driver:conn_extra/1` returns it for a checked-out connection. A second `start_pool` with the same name fails and does not change it.

### Erlang TCP Socket Settings

* `socket_options` (default `[]`): Addition options to pass to `gen_tcp:connect` such as `inet6` for IPv6 support.

## Telemetry and Tracing

[OpenTelemetry](https://opentelemetry.io/) spans can be enabled for queries and transactions by either setting the `trace` to `true` for the pool:

``` erlang
> dream_postgres_driver:start_pool(dream_postgres_driver_default, #{host => "127.0.0.1", 
                            database => "test", 
                            user => "test",
                            pool_size => 5,
                            trace => true}]). 
```

Or by passing `#{trace => true}` in the options for a query or transaction:

```erlang
> dream_postgres_driver:query("select 1", [], #{trace => true}).
#{command => select, num_rows => 1, rows => [{1}]}
> dream_postgres_driver:transaction(fun() ->
>     dream_postgres_driver:query("INSERT INTO my_table(name) VALUES('Name 1')"),
>     dream_postgres_driver:query("INSERT INTO my_table(name) VALUES('Name 2')")
> end, #{trace => true}).
#{command => insert,num_rows => 1,rows => []}
```

Note that since this is optional the `opentelemetry` application is not included
as a dependency of `dream_postgres_driver` -- only `opentelemetry_api` is included by default. So
it must be included as a `rebar3` dependency and runtime dependency (listed in
your application's `.app.src` `applications` or the list of applications for
`relx` to include in a release).

### Listen/Notify

Use `dream_postgres_driver_notifications:start_link` to create a process holding a connection to
the database that you can call `dream_postgres_driver_notifications:listen/2` with to listen on a
channel for notifications. Those notifications will arrive at the calling
process in the form:

```
{notification, Pid, Ref, Channel, Payload}
```

## Running Tests

Pool functionality is tested with common test suites:

```
$ rebar3 ct
```

Postgres query functionality is tested with eunit, create user `test` and database `test`:

```
$ rebar3 eunit
```

## Acknowledgements

Much is owed to https://github.com/semiocast/pgsql (especially for protocol step logic) and https://github.com/epgsql/epgsql/ (especially for some decoding logic).

The pool implementation is owed to James Fish's found in `db_connection` [PR 108](https://github.com/elixir-ecto/db_connection/pull/108). While [db_connection](https://github.com/elixir-ecto/db_connection) and [postgrex](https://github.com/elixir-ecto/postgrex) as a whole were both used as inspiration as well.
