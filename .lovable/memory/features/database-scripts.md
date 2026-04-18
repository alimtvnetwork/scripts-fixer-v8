---
name: Database installation scripts
description: Script 18 in scripts/databases/ -- interactive installer for MySQL, MariaDB, PostgreSQL, SQLite, MongoDB, CouchDB, Redis, Cassandra, Neo4j, Elasticsearch, DuckDB, LiteDB
type: feature
---
## scripts/databases/ structure

| File | Purpose |
|------|---------|
| `config.json` | Database configs, devDir settings, groups, sequence |
| `log-messages.json` | All log/menu messages |
| `run.ps1` | Orchestrator with interactive menu, -All, -Only, -Skip, -DryRun |
| `helpers/install-db.ps1` | Generic `Install-Database` function (choco or dotnet tool) |
| `helpers/menu.ps1` | `Show-DbMenu` interactive picker + `Get-InstallPath` (devDir/custom/system) |

## Install path options
1. Dev directory (default): `E:\dev-tool\databases\<db>`
2. Custom path: user-chosen
3. System default: standard choco install location

## Keywords (install-keywords.json)
databases, db, mysql, mariadb, postgresql, postgres, psql, sqlite, mongodb, mongo, couchdb, redis, cassandra, neo4j, elasticsearch, duckdb, litedb → all map to script ID 18
