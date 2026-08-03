# EF Core Migration Contract

This document is mandatory before changing an entity, DbContext mapping, table,
relationship, index, constraint, stored procedure, trigger, or migration.

## Source of truth

- Data/AfifeContext.cs, Data/AfifeRelationalModelConfiguration.cs, and the EF
  snapshot describe tables, columns, relationships, keys, indexes, defaults, and
  check constraints.
- Migrations/Scripts/InitialSchema.sql is the reviewed initial SQL Server schema
  is the reviewed canonical SQL Server baseline embedded in the application.
- Migrations/Scripts/Programmability.sql versions stored procedures and business
  triggers.
- Migrations/Scripts/AuditTriggers.sql versions generic audit triggers.
- Timestamped files in Data/Migrations are the deployment sequence.
- IX_PlayAwardCategories_PlayId is SQL-resource managed because EF Core 8 cannot represent both it and the filtered unique index on the identical PlayId property set. The startup catalog validator still requires both indexes.
- dotnet-tools.json pins dotnet-ef to the project's EF Core version.

The original SQL files remain design/history inputs. Production deploys must not
run them manually after EF migration ownership has started.

## Baseline behavior

`InitialManagedBaseline` supports both deployment starting points:

1. An empty database receives the complete reviewed schema and programmable objects.
2. A legacy database receives missing tables first, then additive columns and the
   canonical constraints/indexes. The old int-key `Form` is renamed to
   `FormLegacy_PreEf`, retained permanently, and copied to the GUID `Form` with
   `LegacyId` lineage. Legacy image strings are retained and normalized to Images.
3. Duplicate/orphan/provenance conflicts stop the transaction before rollout; the
   migration never deletes or silently merges business data.

Procedures, business triggers and audit triggers are re-applied idempotently, and
startup validates the complete database catalog.

## Absolute no-data-loss rules

- Never use DropTable, DropColumn, DeleteData, TRUNCATE, physical DELETE, or SQL
  that rebuilds a table by discarding rows.
- Never narrow a string/decimal column, change a populated column type in place, or
  make a nullable column required without a reviewed backfill.
- A Down method must not drop data-bearing objects. Rollback restores prior
  behavior/procedure/trigger definitions while retaining additive schema and rows.
- Use expand/migrate/contract: add a nullable column, deploy compatible code,
  backfill idempotently, switch reads, and retain the old column. Physical
  contraction is forbidden by the retention policy.
- All reference-code, RecordType, IsPublished, soft-delete, audit, candidate,
  season, Form lifecycle, and ranking contracts remain mandatory.
- Raw SQL is allowed only when reviewed and annotated with
  Afife:ReviewedDataSafeSql.

NoDataLossSqlServerMigrationsSqlGenerator enforces these rules in application and
design-time commands.

## Creating a migration

Run:

    dotnet tool restore
    dotnet tool run dotnet-ef migrations add MeaningfulMigrationName --output-dir Data/Migrations

Review Up and Down. Replace any generated destructive Down operation with a
compatibility rollback. Put complete CREATE OR ALTER procedure/trigger definitions
in a versioned embedded SQL resource and execute them with MigrationSqlResources.

Every new business table requires IsPublished DEFAULT (1), a global query filter,
soft-delete behavior, ON DELETE NO ACTION, and AdminLogs trigger coverage.

## Validation

Before every merge and deploy run:

    powershell -ExecutionPolicy Bypass -File scripts/validate-migrations.ps1

This restores the pinned tool, rejects destructive migration code/SQL, builds
Release, checks model/snapshot drift, and writes the reviewed idempotent artifact
to artifacts/migrations/YKBAfife-idempotent.sql.

Test every migration on disposable SQL Server databases:

1. Empty database to latest.
2. Latest to previous to latest with a retained probe row.
3. A production-like backup to latest, comparing row counts/checksums before and
   after.

Never use production as the first migration test.

## Deployment

DatabaseMigrationHostedService runs before HTTP traffic. It opens one SQL session,
acquires the exclusive YKBAfife:EFCoreMigrations application lock, applies pending
migrations, validates tables/columns/indexes/constraints/procedures/triggers, and
then releases the lock.

Configuration:

    "DatabaseMigration": {
      "ApplyOnStartup": true,
      "LockTimeoutMilliseconds": 120000
    }

Keep ApplyOnStartup enabled in deployed environments. Multiple instances can start
together; one migrates and the others wait. Migration or schema-drift failure stops
startup instead of serving against an incompatible database.

A deployment pipeline may run the reviewed idempotent artifact before application
rollout. Startup then confirms no migration is pending.

## Recovery

Recover by deploying compatible application code plus a forward compatibility
migration that restores previous procedure/trigger behavior. Never physically
remove newer columns/tables. Operational database backups remain mandatory, but do
not replace additive migration design.
