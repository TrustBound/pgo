# dream_pgo

`dream_pgo` is a fork of [pgo](https://github.com/erleans/pgo), the PostgreSQL client by the pgo authors. It is published on Hex as `dream_pgo`. The fork starts from pgo v0.20.0.

What is different from pgo:

* Names. The OTP application, the Hex package and every module have the `dream_pgo` prefix (`pgo` is `dream_pgo`, `pgo_pool` is `dream_pgo_pool`, and so on). The application environment key, the error tag `dream_pgo_error`, the trace span names and the transaction key in the process dictionary also use the new prefix. Thus `dream_pgo` and `pgo` can load in the same VM.
* The `application_name` fix. A caller's `application_name` in `connection_parameters` replaces the default. The driver sends the node name only when the caller gives no name. The startup packet never holds a parameter name two times, and the caller's order stays as it is. The pool option `application_name` (atom or iodata) also sets the name. An entry in `connection_parameters` takes precedence over the pool option.
* The null byte check. PostgreSQL strings in the startup packet cannot hold a null byte. A pool whose password, user, database, application name or `connection_parameters` hold a null byte does not start: `dream_pgo:start_pool/2` returns `{error, {null_byte, password}}` or `{error, {null_byte, {parameter, Name}}}`. The error never holds the value.
* `gleam.toml`. With this file, a Gleam project can use a local copy of `dream_pgo` as a path dependency. rebar3 does not read it. The Gleam build tool compiles the `test/` directory of a path dependency, so the Common Test suites are in `ct/` (`{ct_opts, [{dir, "ct"}]}` in `rebar.config`). `rebar3 ct` runs them as before. The test certificates stay in `test/certs`.

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

Pools defined in the `dream_pgo` application's environment will be started on boot. You can also add pools dynamically with `dream_pgo:start_pool/3`.

To try `dream_pgo` simply modify `config/example.config` by replacing the `host`, `database`, `user` and `password` values for the database you wish to connect to:

```erlang
[
  {dream_pgo, [{pools, [{dream_pgo_default, #{pool_size => 10,
                                  host => "127.0.0.1",
                                  database => "test",
                                  user => "test"}}]}]}
].
```

`dream_pgo_default` is the name of the pool, `size` is the number of connections to create for the pool. Or you can start the pool through `dream_pgo:start_pool/2` which creates it as a child of `dream_pgo`'s simple one for one:

``` erlang
> application:ensure_all_started(dream_pgo).
{ok,[backoff,opentelemetry_api,pg_types,dream_pgo]}
> dream_pgo:start_pool(dream_pgo_default, #{pool_size => 5, host => "127.0.0.1", database => "test", user => "test"}). 
```

Or start a pool as a child of your application's supervisor:

``` erlang
ChildSpec = #{id => dream_pgo_pool,
              start => {dream_pgo_pool, start_link, [Name, PoolConfig]},
              shutdown => 1000},
```

Then start a shell with `rebar3 shell`, it will boot the applications which will start the pool automatically if it is configured through `sys.config`.

```erlang
> dream_pgo:query("select 1").
#{command => select, num_rows => 1, rows => [{1}]}
> dream_pgo:transaction(fun() ->
>     dream_pgo:query("INSERT INTO my_table(name) VALUES('Name 1')"),
>     dream_pgo:query("INSERT INTO my_table(name) VALUES('Name 2')")
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
  decode_opts => [decode_option()]}
```

The query time options can also be set through options passed to `dream_pgo:query/3`:

``` erlang
decode_fun() :: fun((row(), fields()) -> row()) | undefined.

decode_option() :: return_rows_as_maps | {return_rows_as_maps, boolean()} |
                   column_name_as_atom | {column_name_as_atom, boolean()} |
                   {decode_fun, decode_fun()}.
                         
#{pool => atom(),
  trace => boolean(),
  queue => boolean(),
  decode_opts => [decode_option()]}
```

### Query Options

* `pool` (default: `dream_pgo_default`): Name of the pool to use for checking out a connection to the database.
* `return_rows_as_maps` (default: `false`): When `true` each row is returned as a map of column name to value instead of a list of values.
* `column_name_as_atom` (default: `false`): If `true` converts each column name in the result to an atom.
* `decode_fun` (default: `undefined`): Optional function for performing transformations on each row in a result. It must be a 2-arity function returning a list or map for the row and takes the row (as a list or map) and a list of `#row_description_field{}` records.
* `queue` (default: `true`): Whether to wait for a connection from the pool if none are available.
* `trace` (default: `false`): `dream_pgo` is instrumented with [OpenTelemetry](https://opencensus.io/) and when this option is `true` a span will be created (if sampled).

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

### Erlang TCP Socket Settings

* `socket_options` (default `[]`): Addition options to pass to `gen_tcp:connect` such as `inet6` for IPv6 support.

## Telemetry and Tracing

[OpenTelemetry](https://opentelemetry.io/) spans can be enabled for queries and transactions by either setting the `trace` to `true` for the pool:

``` erlang
> dream_pgo:start_pool(dream_pgo_default, #{host => "127.0.0.1", 
                            database => "test", 
                            user => "test",
                            pool_size => 5,
                            trace => true}]). 
```

Or by passing `#{trace => true}` in the options for a query or transaction:

```erlang
> dream_pgo:query("select 1", [], #{trace => true}).
#{command => select, num_rows => 1, rows => [{1}]}
> dream_pgo:transaction(fun() ->
>     dream_pgo:query("INSERT INTO my_table(name) VALUES('Name 1')"),
>     dream_pgo:query("INSERT INTO my_table(name) VALUES('Name 2')")
> end, #{trace => true}).
#{command => insert,num_rows => 1,rows => []}
```

Note that since this is optional the `opentelemetry` application is not included
as a dependency of `dream_pgo` -- only `opentelemetry_api` is included by default. So
it must be included as a `rebar3` dependency and runtime dependency (listed in
your application's `.app.src` `applications` or the list of applications for
`relx` to include in a release).

### Listen/Notify

Use `dream_pgo_notifications:start_link` to create a process holding a connection to
the database that you can call `dream_pgo_notifications:listen/2` with to listen on a
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
