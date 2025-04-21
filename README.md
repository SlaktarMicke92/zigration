# Zigration

> Migration Tool

Only has support for postgres at the moment, mysql and mariadb support on the way.

Pipeline with testing only in bitbucket at the moment.

## Purpose

A tool for handling migrations in Zig services.

## Usage

1. Install with zig fetch git+https://github.com/SlaktarMicke92/zigration#master

2. Add module in build.zig:
    ```zig
    const zigration = b.dependency("zigration", .{
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("zigration", zigration.module("zigration"));
    ```

3. Add environment variable for database string, for example:

    ```bash
    export DATABASE_URI=postgresql://postgres:password@localhost/database
    ```

4. Add migration files in a new folder called migrations.
    - migrations/
    - Files should be named in following format: 01_create_some_table.sql,
    02_alter_some_table.sql, 03_insert_some_table.sql etc.

5. Run the following command to apply migrations:

    ```bash
    zig build zigration run
    ```

## Tests

```bash
zig build test
```
