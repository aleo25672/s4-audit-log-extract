# SAP S/4 Change Log by Business Process

ABAP utility for SAP S/4HANA Private Cloud. It maps an end-to-end process
(Sourcing to Payment, Order to Cash, or Record to Report) to SAP change
document object classes, reads the matching change documents for a selected
date/time range, and displays field-level changes in an exportable ALV.

## Scope

- SAP S/4HANA Private Cloud, classic ABAP
- Development package: `ZEVOLVER_AXF`
- Parent hierarchy: `ZEVOLVER` → `ZEVOLVER_MAIN` → `ZEVOLVER_AXF`
- Transaction: `ZCHGLOG`
- Database change documents only; archived change documents are not read
- No custom authorization check in this first version

## Repository contents

| Object | Purpose |
|---|---|
| `ZTPROC_CHDO` | Client-specific process-to-object-class customizing table |
| `ZCL_CHGLOG_READER` | Reusable change-document reader |
| `Z_CHGLOG_BY_PROCESS` | Selection screen and ALV report |
| `Z_CHGLOG_SEED_CATALOG` | One-time seed and system validation utility |
| `ZCHGLOG` | Report transaction and message class |

The files use classic abapGit serialization.

## Install

1. Ensure packages `ZEVOLVER` and `ZEVOLVER_MAIN` exist.
2. In abapGit, clone this repository into package `ZEVOLVER_AXF`, selecting
   `ZEVOLVER_MAIN` as its superpackage if abapGit asks.
3. Activate change recording before the first pull. `ZEVOLVER_AXF` is a
   transportable package, so abapGit must record every created object in a
   transport request. Without this, the pull stops with
   `Change recording must be activated for package ZEVOLVER_AXF`.
   - Create a **workbench** request in `SE09` (Create > Workbench request) if
     you do not already have one open.
   - In the abapGit repository view, open **Advanced > Activate Change
     Recording** and supply that request.
4. Pull and activate all objects.
5. Generate the table maintenance dialog for `ZTPROC_CHDO`: transaction `SE11`,
   enter the table, then **Utilities > Table Maintenance Generator**. Use
   authorization group `&NC&`, function group `ZCHGLOG_TMG`, maintenance type
   **one step**, and let the system propose the screen number.
   This dialog is generated locally rather than shipped, because the generated
   screens and function group are specific to the target S/4 release.
6. Run `Z_CHGLOG_SEED_CATALOG` once in each required client.
7. Review its ALV:
   - `IN_TCDOB = X` confirms that the technical object exists in this system.
   - `SEEN_CDHDR = X` confirms that the client already contains change
     documents for that class. A blank value is not an error if no such
     document has been changed yet.
   - A seed row not found in `TCDOB` is skipped.
8. Maintain or extend mappings with transaction `SM30`, table `ZTPROC_CHDO`.

## Default catalog

| Process | Object class | Meaning |
|---|---|---|
| P2P | `BANF` | Purchase requisition |
| P2P | `EINKBELEG` | Purchasing document |
| P2P | `INCOMINGINVOICE` | Incoming invoice |
| O2C | `VERKBELEG` | Sales document |
| O2C | `LIEFERUNG` | Delivery |
| O2C | `FAKTBELEG` | Billing document |
| R2R | `BELEG` | FI accounting document |

These are common SAP classes, not a universal SAP process catalog. Confirm the
scope with MM/SD/FI process owners and verify each class in `TCDOB` and against
known records in `CDHDR`. Add landscape-specific classes through SM30.

## Run

Start transaction `ZCHGLOG`.

1. Select a process.
2. Keep the date selection narrow where practical. Date is obligatory and
   supports standard SAP select-option intervals and exclusions.
3. Adjust time, username, or object ID filters if needed.
4. Set **Max rows**. The default is `10,000`; `0` means no row limit.
5. Execute. If the row limit is reached, the ALV is returned with a truncation
   warning. Refine the date selection or raise Max rows and rerun.
6. Use standard ALV functions to filter, sort, and export to spreadsheet/CSV.

The max-row value applies to field-level output rows, not change-document
headers.

## Output

One ALV row represents one changed field:

- Process, object class, description, object ID, change number
- Change date/time, user, transaction
- Change indicator, table, table key, field
- Formatted old and new values

Only fields configured by the underlying SAP application for change-document
logging can appear. Missing field history cannot be reconstructed by this
report.

## Verification checklist

1. Change a known purchase order in a test client.
2. Run `ZCHGLOG` for P2P and the same date.
3. Compare object ID, user, timestamp, field, and old/new values with
   `RSSCD100` or the purchase order change history.
4. Repeat with a sales order for O2C.
5. Set Max rows to `1`; confirm one ALV row and the truncation warning.
6. Use a date range with no changes; confirm the no-data message.
7. Deactivate one catalog class in SM30; confirm it is no longer read.

## Design notes

`CHANGEDOCUMENT_READ_HEADERS` narrows by object class and the safe outer date
envelope. The reader then applies the complete date/time/user/object-ID range
semantics in ABAP and calls `CHANGEDOCUMENT_READ_POSITIONS` for matching
headers. This avoids an unbounded direct read of `CDPOS`.

For a future web/OData option, expose `ZCL_CHGLOG_READER` through a thin RAP or
Gateway facade; the process catalog and field-level result model can remain
unchanged.
