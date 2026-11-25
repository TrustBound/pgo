# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-11-25

Tests: 158 Common Test cases. The new `dream_postgres_driver_numeric_SUITE` compares 2,000 random `numeric` values in each direction with the text of the server, on PostgreSQL 16.16, 17.12, 18.7 and 19.0, with no difference.

### Added
- The decode option `numeric_as_text`. With it, each `numeric` value (also the elements of a `numeric` array, and a domain over `numeric`) decodes to a binary with its exact decimal text, the same text that PostgreSQL's `numeric_out` writes: the sign, all digits of the display scale with the trailing zeros (`<<"1.50">>`, `<<"0.00">>`), very large and very small values, and `<<"NaN">>`, `<<"Infinity">>` and `<<"-Infinity">>`. Give it per query in `decode_opts`, or for a pool in the pool config. Without the option, a `numeric` decodes as before. The new module `dream_postgres_driver_numeric_text` does the conversion.

### Changed
- A binary for a `numeric` parameter goes to the server in text format, and PostgreSQL reads it with its own `numeric_in`. The value keeps all digits and its scale, every text that PostgreSQL accepts works (`NaN`, `Infinity`, `1_000.5`, spaces around the number), and a text that is not a number gets PostgreSQL's own error (`22P02`, `invalid input syntax for type numeric: "abc"`). Before, pg_types parsed the binary itself: `<<"NaN">>`, `<<"Infinity">>` and a text that is not a number crashed the encoding. An integer, a float and the atoms `'NaN'`, `infinity` and `'-infinity'` encode as before, in binary format. The elements of a `numeric` array still use the pg_types encoding.

## [1.0.0] - 2026-11-24

First release of the `dream_postgres_driver` fork, based on pgo 0.20.0 and the pgo `main` branch up to commit `1c8bf6f`.

Tests: 132 Common Test cases pass in about 14 seconds against PostgreSQL 17 in Docker (OTP 28.5, Apple M1 Max, 64 GB, macOS 26.5.1). CI runs them on OTP 26, 27 and 28 with dialyzer.

### Added
- `gleam.toml`, so that a Gleam project can use a local copy of `dream_postgres_driver` as a path dependency. rebar3 does not read it.
- Read and write the PostgreSQL types that pg_types 0.6.0 does not read: `oid` (pg_types registered it under the wrong send function), the `reg*` types (`regnamespace`, `regrole`, `regconfig`, `regdictionary` and `regcollation` are new, and all `reg*` types, `xid` and `cid` now decode to an integer), `timetz`, `money`, `macaddr8`, `box`, `xml`, `cstring`, `jsonpath`, `pg_lsn`, `xid8`, `pg_snapshot`, `txid_snapshot`, `void`, `int2vector`, `oidvector`, the multirange types and `tsquery`. dream_postgres_driver carries one `dream_postgres_driver_type_*` module for each, until a pg_types release has the reader.
- Read `anyarray` values, such as the `most_common_vals` and `histogram_bounds` columns of `pg_stats`. `dream_postgres_driver_type_anyarray` reads the element oid from the array and decodes the elements with the type of that oid. PostgreSQL does not accept a parameter of type `anyarray`, so there is no write.
- The pool setting `extra` holds any value. dream_postgres_driver does not use it. Each connection of the pool keeps it, as it keeps `trace` and `decode_opts`, and `dream_postgres_driver:conn_extra/1` returns it for a checked-out connection (`undefined` when the pool config has no `extra`). Thus a library on top of dream_postgres_driver can keep a value with the pool, and the value stops with the pool.
- At start, the application puts its type modules first in the pg_types `modules` setting. Modules that the user set stay after them, so a user module still replaces a dream_postgres_driver module for the same type.

### Changed
- The Common Test suites moved from `test/` to `ct/`, because the Gleam build tool compiles the `test/` directory of a path dependency. `rebar3 ct` finds them through `ct_opts`.
- Rename the OTP application, the Hex package and all modules from `pgo` to `dream_postgres_driver`.
- Rename the error tag `pgo_error` to `dream_postgres_driver_error`, the trace span names to `dream_postgres_driver:query/3` and `dream_postgres_driver:transaction/2`, and the process dictionary key to `dream_postgres_driver_transaction_connection`.

### Fixed
- A caller's `application_name` in `connection_parameters` replaces the default node name. Before, the driver sent both, and PostgreSQL used the last one.
- The startup packet never holds a parameter name two times. The caller's `connection_parameters` need no sort order.
- The documented pool option `application_name` now sets the application name.
- A null byte in the password or in a startup parameter (user, database, `application_name`, any entry of `connection_parameters`) no longer goes to the server. Before, a null byte in the password crashed the pool, and a null byte in a parameter ended the string in the startup packet and could add a parameter. Now `dream_postgres_driver:start_pool/2` returns `{error, {null_byte, password}}` or `{error, {null_byte, {parameter, Name}}}` and starts no pool. A password given as a function is checked at connect time: each connection attempt calls the function, and a null byte in the value it returns stops that attempt with `{error, {null_byte, password}}` before anything goes to the server.
- The password no longer shows in the status or in the reports of the supervisors and of the type server. The `format_status/1` from pgo pull request #116 hides it only in the connection processes and in `dream_postgres_driver_notifications`, but the application supervisor, the pool supervisor and the connection supervisor keep the pool configuration in their child specs and print it in a report when a child stops. `dream_postgres_driver:start_pool/2` and `dream_postgres_driver_pool:start_link/2` now check the password for a null byte and then put it into a function, which prints without its value.
- The names of settings in `connection_parameters` have no case, as in PostgreSQL. An `Application_Name` entry replaces the default node name, and `TimeZone` and `timezone` are one name, sent once with the last value. Before, the driver sent both names, and with `Application_Name` the server used the node name.
- A pool that starts does not use the types that an earlier pool of the same name loaded. pg_types keeps the type map of each pool in one table for the life of its application, and the type server of a new pool loads the types after its connections start. Until that load was done, a query decoded with the old entries: a module that was replaced in the `modules` setting, or an oid of another database. The pool now removes its old entries before it starts, so a query waits for the load of the new pool.
- A connection attempt that fails after the TCP connect closes its socket. Before, only a failed SSL handshake closed it (pgo pull request #125). When the server refused SSL or the startup (an unknown role, a wrong password), the socket stayed open, and each new attempt of the connection process opened one more socket.
- A bad answer to the SSL request gives an error. Before, a byte other than `S` or `N`, or a receive error (the server closed the connection), crashed the connection process with a `case_clause`. Now `dream_postgres_driver_handler:open/2` returns `{error, {unexpected_ssl_response, Byte}}` (`Byte` is the binary that the server sent) or the receive error, such as `{error, closed}`, closes the socket, and the connection process tries again.
- A `cacertfile` in `ssl_options` replaces the default CA certificates from the system. Before, the driver also set `cacerts` to the system list, the ssl application ignored the `cacertfile`, and a server certificate from a private CA failed with `unknown_ca`. The driver now reads the system list only when the caller gives neither `cacertfile` nor `cacerts`.
- A range over a type of variable length (`numrange`) and a multirange of such ranges no longer crash (pg_types issue #21). dream_postgres_driver replaces `pg_range` with `dream_postgres_driver_type_range`.
- `'24:00:00'::time` and a `timetz` at 24:00 decode to `{24, 0, 0}`. Before, they crashed. dream_postgres_driver replaces `pg_time` with `dream_postgres_driver_type_time`.
- A negative interval, or an interval of 24 hours or more, no longer crashes. The form stays `{interval, {{Hours, Minutes, Seconds}, Days, Months}}`, but the hours can be 24 or more and the parts have the sign of the interval: `'-1 day -02:03:04.5'` is `{interval, {{-2, -3, -4.5}, -1, 0}}`, as in pg_types pull request #25. dream_postgres_driver replaces `pg_interval` with `dream_postgres_driver_type_interval`.
- `'infinity'::interval` and `'-infinity'::interval` (PostgreSQL 17 and later) decode to the atoms `infinity` and `'-infinity'`, and these atoms encode back. Before, they decoded to intervals of a very large size. `dream_postgres_driver_type_interval` sets all three fields to the largest or the smallest integer, as PostgreSQL does.
- `'infinity'::date` and `'-infinity'::date` decode to the atoms `infinity` and `'-infinity'`, and these atoms encode back, as for timestamps. Before, they decoded to wrong dates. dream_postgres_driver replaces `pg_date` with `dream_postgres_driver_type_date`.
- The type bootstrap query gives a multirange type the subtype of its ranges as `base_oid`, through `pg_range.rngmultitypid`. Before, the `base_oid` of a multirange was 0, and a multirange could not be read or written. The query has this join only for a server of PostgreSQL 14 or later, because older servers have no multiranges and no `rngmultitypid` column.
- The test certificates in `test/certs` are a test CA (`ca.crt`) and a server certificate for `localhost` and `127.0.0.1` that the CA signed. The old self-signed server certificate ended on 29 November 2026.

## [0.20.0] - 2025-12-12

### Fixed
- Set socket to active false when handling a ping by @tsloughter in [#115](https://github.com/erleans/pgo/pull/115)

## [0.18.0] - 2025-12-11

### Changed
- Use setops helper for ssl connections by @CrowdHailer in [#112](https://github.com/erleans/pgo/pull/112)

## [0.16.0] - 2025-12-07

### Changed
- Listen/Notify support by @tsloughter in [#110](https://github.com/erleans/pgo/pull/110)
- Handle and log query errors in type server by @tsloughter in [#106](https://github.com/erleans/pgo/pull/106)

## [0.15.0] - 2025-07-01

### Changed
- Add support for pg_timestampz with UTC offsets by @chiroptical in [#98](https://github.com/erleans/pgo/pull/98)
- Export query/4 to support manually passing connection by @tsloughter in [#95](https://github.com/erleans/pgo/pull/95)
- Add test of domain_socket support by @tsloughter in [#94](https://github.com/erleans/pgo/pull/94)
- Forgot to update ssl postgres docker image by @tsloughter in [#93](https://github.com/erleans/pgo/pull/93)
- Update otel api library by @tsloughter in [#91](https://github.com/erleans/pgo/pull/91)
- Handle domain socket host names by @cmkarlsson in [#90](https://github.com/erleans/pgo/pull/90)
- Fix typespecs by @asabil in [#67](https://github.com/erleans/pgo/pull/67)
- Time zone should be explicitly set for timestamp related tests by @chiroptical in [#89](https://github.com/erleans/pgo/pull/89)
- Update CI by @chiroptical in [#85](https://github.com/erleans/pgo/pull/85)
- Add ensure_all_started to make it obvious you need the application by @chiroptical in [#73](https://github.com/erleans/pgo/pull/73)
- Update github actions runner to ubuntu 22.04 by @chiroptical in [#74](https://github.com/erleans/pgo/pull/74)
- Fix pgo_handler:decode_tag return value by @asabil in [#64](https://github.com/erleans/pgo/pull/64)
- Remove telemetry from lock file and update license string by @tsloughter

## New Contributors
* @chiroptical made their first contribution in [#98](https://github.com/erleans/pgo/pull/98)
* @cmkarlsson made their first contribution in [#90](https://github.com/erleans/pgo/pull/90)
## [0.13.0] - 2022-10-13

### Changed
- Add testing of transaction/2 by @tsloughter
- Fix infinite loop in pgo:transaction/2 by @asabil in [#63](https://github.com/erleans/pgo/pull/63)
- OpenTelemetry replaces OpenCensus for tracing by @tsloughter in [#62](https://github.com/erleans/pgo/pull/62)

## New Contributors
* @asabil made their first contribution in [#63](https://github.com/erleans/pgo/pull/63)
## [0.12.0] - 2022-06-07

### Changed
- Add logging when connecting fails by @tsloughter in [#59](https://github.com/erleans/pgo/pull/59)
- Update github actions to point to main branch by @tsloughter
- Support for SCRAM-SHA-256 authentication by @tsloughter in [#58](https://github.com/erleans/pgo/pull/58)
- Permit passing of socket options by @lpil in [#55](https://github.com/erleans/pgo/pull/55)
- Upgrade pg_types to hex package 0.4.0 by @tsloughter in [#45](https://github.com/erleans/pgo/pull/45)
- Upgrade pg_types to support micro second timestamps by @tsloughter
- Switch pg_types to master branch for system timestamp by @tsloughter
- Add table as possible return type for num_rows by @CrowdHailer in [#43](https://github.com/erleans/pgo/pull/43)
- Handle transaction rollback by @benbro in [#40](https://github.com/erleans/pgo/pull/40)
- Upgrade pg_types to 0.3.0 by @tsloughter
- Add test for pgo_pool:disconnect/4 by @tsloughter
- Upgrade pg_types and add format_error/1 to format encoding failures by @tsloughter
- Upgrade pg_types to support decoding intervals by @tsloughter
- Upgrade pg_types and add test for infinity in time ranges by @tsloughter
- Permit start_link to take proplists + binaries by @lpil in [#33](https://github.com/erleans/pgo/pull/33)
- Correct erlang version requirement by @tsloughter

### Fixed
- Fix match on ets:lookup in delete_holder to be on 5-tuple by @tsloughter

## New Contributors
* @CrowdHailer made their first contribution in [#43](https://github.com/erleans/pgo/pull/43)
* @benbro made their first contribution in [#40](https://github.com/erleans/pgo/pull/40)
## [0.11.0] - 2019-12-15

### Changed
- Bump pg_types to 0.2.0 by @tsloughter
- Fail on purpose by @tsloughter
- Include trace configuration in README example by @lpil in [#28](https://github.com/erleans/pgo/pull/28)
- Add surefire hook by @tsloughter

## New Contributors
* @lpil made their first contribution in [#28](https://github.com/erleans/pgo/pull/28)
## [0.10.0] - 2019-08-27

### Changed
- Update pg_types for tsvector support by @tsloughter
- Upgrade pg_types by @tsloughter
- Null support in records by @tsloughter
- Configurable uuid decode by @tsloughter
- Update geometric tests by @tsloughter
- Use new orb with overridable executor by @tsloughter
- Add array null element test by @tsloughter
- Update pg_types by @tsloughter
- Update pgtypes by @tsloughter
- Update pgtypes for json encode/decode by @tsloughter
- Add tests for tid and bit_string by @tsloughter
- Add tests for types circle, line, line_segment, path and polygon by @tsloughter
- Upgrade pg_types to support records/composite types by @tsloughter
- Reraise type find error if params are equal length by @tsloughter
- Update pg_types: hstore support by @tsloughter
- Add empty range tests by @tsloughter
- Upgrade pg_types and add more range tests by @tsloughter
- Pg types by @tsloughter in [#22](https://github.com/erleans/pgo/pull/22)

### Fixed
- Fix starting of postgres-ssl by @tsloughter

## [0.8.0] - 2019-05-27

### Changed
- Upgrade telemetry by @tsloughter in [#20](https://github.com/erleans/pgo/pull/20)
- Remove dead function clause for parsing exponents by @starbelly in [#13](https://github.com/erleans/pgo/pull/13)

### Fixed
- Fix ssl support by @tsloughter in [#17](https://github.com/erleans/pgo/pull/17)

## [0.7.0] - 2019-05-02

### Changed
- Re-work numeric encoding and decoding by @starbelly in [#11](https://github.com/erleans/pgo/pull/11)
- Implement ping of connection through sync command by @tsloughter

## New Contributors
* @starbelly made their first contribution in [#11](https://github.com/erleans/pgo/pull/11)
## [0.6.2] - 2019-02-08

### Changed
- Add to docs how to start pool in supervisor by @tsloughter

## [0.6.1] - 2019-02-08

### Changed
- Add overview doc by @tsloughter

## [0.6.0] - 2019-01-28

### Changed
- Add support for startup connection parameters by @tsloughter
- Some name cleanup by @tsloughter
- Updates to how configuration is handled by @tsloughter
- Support query options set per-pool by @tsloughter
- Add test for return_rows_as_maps by @tsloughter
- Some cleanup by @tsloughter
- Just some formatting by @tsloughter
- Add note about opencensus being optional by @tsloughter
- Update readme for telemetry and tracing by @tsloughter
- Optional opencensus tracing by @tsloughter
- Execute telemetry event and fixup transactions by @tsloughter
- Add initial telemetry event execute by @tsloughter
- Updated requirements in readme by @tsloughter
- Cleanup api some and remove opencensus for now by @tsloughter
- Example code for doing transaction. in [#10](https://github.com/erleans/pgo/pull/10)
- Update rebar3 orb by @tsloughter
- Type load loop by @tsloughter in [#9](https://github.com/erleans/pgo/pull/9)

### Fixed
- Fix hex badge by @tsloughter
- Fix xref run by @tsloughter
- Fix doc generation by @tsloughter
- Fix git repo address by @getong in [#7](https://github.com/erleans/pgo/pull/7)

## New Contributors
* @ made their first contribution in [#10](https://github.com/erleans/pgo/pull/10)
* @getong made their first contribution in [#7](https://github.com/erleans/pgo/pull/7)
## [0.5.0] - 2018-11-05

### Changed
- Move more eunit tests to common test by @tsloughter
- Remove simple query and text decoding by @tsloughter

## [0.4.0] - 2018-11-02

### Changed
- Upgrade opencensus to 0.6.0 by @tsloughter
- Support otp-21 by @tsloughter
- Run eunit in separate command in circleci (opencensus merl issue) by @tsloughter
- Update pool by @tsloughter
- Add requirements section to readme by @tsloughter

### Fixed
- Fix up support for datetime and interval while moving tests to ct by @tsloughter
- Fix running eunit after ct in same rebar3 command by @tsloughter
- Fix connection lookup by @tsloughter

## [0.3.0] - 2018-05-31

### Changed
- Upgrade opencensus dep by @tsloughter
- Return uuid as 16 byte binary by @tsloughter
- Replace pg_result record with map by @tsloughter in [#2](https://github.com/erleans/pgo/pull/2)
- Temporary commenting out of spans by @tsloughter
- Handle notice messages by @tsloughter

### Fixed
- Fix flush on bind error by @tsloughter

## [0.2.0] - 2018-03-12

### Changed
- Loosen hex dep constraints by @tsloughter
- Use git tags for versions by @tsloughter
- Upgrade opencensus to 0.3.0 by @tsloughter
- Trace transactions by @tsloughter
- Add opencensus tracing by @tsloughter
- Add covertool to output for codecov by @tsloughter
- Add codecov badge by @tsloughter
- Try codecov instead of coveralls that never works by @tsloughter
- Update app metadata by @tsloughter
- Add coveralls plugin by @tsloughter
- Type clean up by @tsloughter
- Improve error responses and add circle config by @tsloughter
- Add transaction function by @tsloughter
- Remove locked jsx by @tsloughter
- Update readme example by @tsloughter
- Simplify config by @tsloughter
- Export #pg_result{} type by @tsloughter
- Quick and dirty query cache by @tsloughter
- Few badmatch bugs in pool by @tsloughter
- Match on bigint tag to encode big integers by @tsloughter
- Update replacing sbroker with builtin pool impl from db_connection by @tsloughter
- Cleanup by @tsloughter
- Add some types by @tsloughter
- Add some types by @tsloughter
- Reload types when not found from row description by @tsloughter
- Enable more tests by @tsloughter
- Rework with forked pgsql protocol by @tsloughter
- Update metadata by @tsloughter
- Initial commit by @tsloughter

### Fixed
- Fix up automatic encoding of uuid and json by @tsloughter
- Fixup connection by @tsloughter

## New Contributors
* @tsloughter made their first contribution
[0.20.0]: https://github.com/erleans/pgo/compare/v0.19.0..v0.20.0
[0.18.0]: https://github.com/erleans/pgo/compare/v0.17.0..v0.18.0
[0.16.0]: https://github.com/erleans/pgo/compare/v0.15.0..v0.16.0
[0.15.0]: https://github.com/erleans/pgo/compare/v0.13.0..v0.15.0
[0.13.0]: https://github.com/erleans/pgo/compare/v0.12.0..v0.13.0
[0.12.0]: https://github.com/erleans/pgo/compare/v0.11.0..v0.12.0
[0.11.0]: https://github.com/erleans/pgo/compare/v0.10.0..v0.11.0
[0.10.0]: https://github.com/erleans/pgo/compare/v0.8.0..v0.10.0
[0.8.0]: https://github.com/erleans/pgo/compare/v0.7.0..v0.8.0
[0.7.0]: https://github.com/erleans/pgo/compare/v0.6.2..v0.7.0
[0.6.2]: https://github.com/erleans/pgo/compare/v0.6.1..v0.6.2
[0.6.1]: https://github.com/erleans/pgo/compare/v0.6.0..v0.6.1
[0.6.0]: https://github.com/erleans/pgo/compare/v0.5.0..v0.6.0
[0.5.0]: https://github.com/erleans/pgo/compare/v0.4.0..v0.5.0
[0.4.0]: https://github.com/erleans/pgo/compare/v0.3.0..v0.4.0
[0.3.0]: https://github.com/erleans/pgo/compare/v0.2.0..v0.3.0

<!-- generated by git-cliff -->
