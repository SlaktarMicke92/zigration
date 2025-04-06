# Migration Tool

## Purpose

A tool for handling migrations in Zig services.

## Usage

Install with zig-fetch--------

"""bash
export DATABASE_URL=
"""

"""bash
zig build migrate prepare
zig build migrate run
"""

## Tests

To run all tests you need to set an environment variable:

"""bash
export TEST_ENV_VAR=lel
"""