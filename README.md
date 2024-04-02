# dbmigrations

This package contains a library for the creation, management, and installation
of schema updates (called "migrations") for a relational database. In
particular, this package lets the migration author express explicit dependencies
between migrations. This library is accompanied by a number database-specific
executables that contain the management tools to automatically install or revert
migrations accordingly.

This package operates on two logical entities:

- **backend**: the relational database whose schema you want to manage.

- **migration store**: the collection of schema changes you want to apply to the
  database. These migrations are expressed using plain text files collected
  together in a single directory, although the library is general enough to
  permit easy implementation of other storage representations for migrations.

## Getting started

To get started, install with the right database-specific flag for your database.

```console
stack install dbmigrations --flag dbmigrations:<backend>
```

Then run the database-specific executable that was installed.

```console
dbm-<backend> help
```

For example,

```console
stack install dbmigrations --flag dbmigrations:postgresql
```

```console
dbm-postgresql help
```

Available backends are:

- `sqlite`
- ~~`mysql`~~ _temporarily disabled due to upstream issue_
- `postgresql`

Since all of `dbm-<backend>` command line tools offer the exact same interface,
they are described here in a single document. The executables mentioned above
are simply called `dbm` for the rest of this document. That is, given an example
that reads as `dbm command` you actually have to execute `dbm-postgresql
command` or `dbm-mysql command` and so on.

The DBM tools work by creating migration files in a specific location, called a
migration store, on your filesystem. This directory is where all possible
migrations for your project will be kept. DBM allows you to create migrations
that depend on each other. When you use DBM to upgrade your database schema, it
determines which migrations are missing, what their dependencies are, and
installs the required migrations in the correct order (based on dependencies).

DBM works by prompting you for new migration information. It then creates a
migration YAML file (whose format is described below), which you then edit by
hand.

When migrations are installed into your database, the set of installed
migrations is tracked by way of a migration table that is installed into your
database.

## Example

1. Create a directory in which to store migration files.

2. Set an environment variable `DBM_MIGRATION_STORE` to the path to the
   directory you created in step 1.

3. Set an environment variable `DBM_DATABASE` to a database connection string
   that is appropriate for the database type you chose. The contents of this
   depend on the database type, see the "Environment" documentation section for
   more information.

4. Run `dbm upgrade`. This command will not actually install any migrations,
   since you have not created any, but it will attempt to connect to your
   database and install a migration-tracking table.

   If this step succeeds, you should see this output:

   ```
   Database is up to date.
   ```

5. Create a migration with `dbm new`. Here is an example output:

   ```console
   % dbm new hello-world
   Selecting dependencies for new migration: hello-world

   Confirm: create migration 'hello-world'
     (No dependencies)
   Are you sure? (yn): y
   Migration created successfully: ".../hello-world.yml"
   ```

6. Edit the migration you created. In this case, DBM created a file
   `$DBM_MIGRATION_STORE/hello_world.yml` that looks like this:

   ```yaml
   Description: (Description here.)
   Created: 2015-02-18 00:50:12.041176 UTC
   Depends:
   Apply: |
     (Apply SQL here.)

   Revert: |
     (Revert SQL here.)
   ```

   This migration has no valid apply or revert SQL yet; that's for you to
   provide. You might edit the apply and revert fields as follows:

   ```yaml
   Apply: |
     CREATE TABLE foo (a int);

   Revert: |
     DROP TABLE foo;
   ```

7. Test the new migration with `dbm test`. This will install the migration in a
   transaction and roll it back. Here is example output:

   ```console
   % dbm test hello-world
   Applying: hello-world... done.
   Reverting: hello-world... done.
   Successfully tested migrations.
   ```

<!-- prettier-ignore-start -->
<!-- it gets confused on the line-break-within-code of dbm upgrade -->

8. Install the migration. This can be done in one of two ways: with `dbm
   upgrade` or with `dbm apply`. Here are examples:


   ```console
   % dbm apply hello-world
   Applying: hello-world... done.
   Successfully applied migrations.

   % dbm upgrade
   Applying: hello-world... done.
   Database successfully upgraded.
   ```

<!-- prettier-ignore-end -->

9. List installed migrations with `dbm list`.

   ```console
   % dbm list
   hello-world
   ```

10. Revert the migration.

    ```console
    % dbm revert hello-world
    Reverting: hello-world... done.
    Successfully reverted migrations.
    ```

11. List migrations that have not been installed.

    ```console
    % dbm upgrade-list
    Migrations to install:
      hello-world
    ```

## Configuration File Format

All DBM commands accept a `--config-file` option which you can use to specify
the path to a configuration file containing your settings. This approach is an
alternative to setting environment variables. The configuration file format uses
the same environment variable names for its fields. An example configuration is
as follows:

```
DBM_DATABASE = "/path/to/database.db"
DBM_MIGRATION_STORE = "/path/to/migration/store"
DBM_LINEAR_MIGRATIONS = on/off (or true/false; defaults to off)
DBM_TIMESTAMP_FILENAMES = on/off (or true/false; defaults to off)
```

Alternatively, you may save your settings to `dbm.cfg` file in the current
directory (probably a project root) and DBM will load it automatically, if
present. Specifying `--config-file` disables this behavior.

If you use a config file (either the default one or the one specified with
`--config-file` option) but the environment variables are set, they will
override settings from the file. You may use this to have project settings
specified in a file and use environment to specify user-local configuration
options.

## Migration Files Format

A migration used by this package is a structured document in YAML
format containing these fields:

```
 Description: (optional) a textual description of the migration

Dependencies: (required, but may be empty) a whitespace-separated
              list of migration names on which the migration
              depends; these names are the migration filenames
              without the filename extension

     Created: The UTC date and time at which this migration was
              created

       Apply: The SQL necessary to apply this migration to the
              database

      Revert: (optional) The SQL necessary to revert this migration
              from the database
```

The format of this file is somewhat flexible; please see the YAML 1.2 format
specification for a full description of syntax features. I recommend appending
"|" to the Apply and Revert fields if they contain multi-line SQL that you want
to keep that way, e.g.,

```yaml
Apply: |
  CREATE OR REPLACE FUNCTION ...
  ...
  ...

Revert: |
  DROP TABLE foo;
  DROP TABLE bar;
```

Note that this is only _necessary_ when concatenating the lines would have a
different meaning, e.g.,

<!-- prettier-ignore-start -->

```yaml
Apply:
  -- Comment here
  CREATE TABLE;
```

<!-- prettier-ignore-end -->

Without "|" on the "Apply:" line, the above text would be collapsed to "--
Comment here CREATE TABLE;" which is probably not what you want. For a full
treatment of this behavior, see the YAML spec.

## Environment

DBM depends on these environment variables / configuration file
settings:

```
DBM_DATABASE

  The database connection string for the database you'll be
  managing. The connection strings for each supported database type
  are as follows:

  PostgreSQL:

    The format of this value is a PostgreSQL database connection
    string, i.e., that described at:

    http://www.postgresql.org/docs/8.1/static/libpq.html#LIBPQ-CONNECT

  SQlite3:

    The format of this value is a filesystem path to the Sqlite3
    database to be used.

  MySQL:

    For MySQL, DBM_DATABASE should be a value of key value pairs,
    where each pair is formed by `key=value`, and each pair separated
    by a semicolon. Required keys are `host`, `user` and `database`,
    and you can optionally supply `port` and `password`.

    Example: DBM_DATABASE="host=localhost; user=root; database=cows"

DBM_MIGRATION_STORE

  The path to the filesystem directory where your migrations will be
  kept. DBM will create new migrations in this directory and use
  the migrations in this directory when updating the database
  schema. Initially, you'll probably set this to an extant (but
  empty) directory. DBM will not create it for you.

DBM_LINEAR_MIGRATIONS

  If set to true/on, the linear migrations feature will be enabled.
  Defaults to off. See 'Linear migrations' section for more details.

DBM_TIMESTAMP_FILENAMES

  If set to true/on, the migration filename for new migrations will
  have a timestamp embedded in it.
```

## Commands

```
  new <migration name>: create a new migration with the given name and
    save it in the migration store. This command will prompt you for
    dependencies on other migrations (if the 'linear migrations'
    feature is disabled) and ask for confirmation before creating the
    migration in the store. If you use the --no-ask flag, the migration
    will be created immediately with no dependencies.

  apply <migration name>: apply the specified migration (and its
    dependencies) to the database. This operation will be performed
    in a single transaction which will be rolled back if an error
    occurs. DBM will output updates as each migration is applied.

  revert <migration name>: revert the specified migration (and its
    reverse dependencies -- the migrations which depend on it) from
    the database. This operation will be performed in a single
    transaction which will be rolled back if an error occurs. DBM
    will output updates as each migration is reverted.

  test <migration name>: once you've created a migration, you might
    find it useful to test the migration to be sure that it is
    syntactically valid; the "test" command will apply the specified
    migration and revert it (if revert SQL is specified in the
    migration). It will perform both of these operations in a
    transaction and then issue a rollback.

  upgrade: this will apply all migrations in the migration store which
    have not yet been applied to the database. Each migration will be
    applied with its dependenciees in the correct order. All of the
    migrations will be applied together in a single transaction. By
    default, this transaction is committed; if you use the --test
    flag, the transaction will be rolled back, allowing you to test
    the entire upgrade process.

  upgrade-list: this will list the migrations that the "upgrade"
    command would apply if you were to run it. In other words, this
    will list all migrations which have not yet been applied to the
    database.

  reinstall: this will revert, then reapply a migration, all in a
    transaction. If --test is specified, the transaction will be
    rolled back; otherwise it will be committed. This is mostly
    useful in development when a migration applies but is incorrect
    and needs to be tweaked and reapplied.
```

## Linear Migrations

If you know that every migration needs to depend on all previous ones, consider
enabling this feature. When enabled, `dbm new` will automatically select
smallest subset of existing migrations that will make the new one indirectly
depend on every other already in the store. This in turn makes the store
linear-ish (in terms of order of execution) and helps managing the migrations by
always depending on previous work. Also, this may easily be used to see how the
database changed in time.

---

[LICENSE](./LICENSE) | [CHANGELOG](./CHANGELOG.md)
