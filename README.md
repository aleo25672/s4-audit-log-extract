# SAP S/4 Change Log by Business Process

ABAP utility for SAP S/4HANA Private Cloud. You select a **configurable**
business process and a date/time range. The report expands that process into
SAP change-document object classes (`OBJECTCLAS`), reads the matching change
documents, and returns field-level old/new values.

Output can be:

- an interactive ALV
- a local CSV file (SAP GUI save dialog)
- a CSV file on the SAP application server, resolved through transaction `FILE`

P2P, O2C, and R2R are **seed examples only**. Any process you maintain in the
catalog appears in the selection dropdown without a code change.

---

## What you get from GitHub

This repository is an **abapGit** source tree. It is not installed by
running a script on your laptop. You clone it, then pull it into S/4 with
abapGit.

| Object | Type | Purpose |
|---|---|---|
| `ZEVO_CHGLOG_PROC` | Table | Process catalog (key, description, active, sequence) |
| `ZEVO_CHGLOG_CHDO` | Table | Object classes assigned to each process |
| `ZCL_EVO_CHGLOG_READER` | Class | Reads CDHDR/CDPOS via standard change-document FMs |
| `ZCL_EVO_CHGLOG_EXPORTER` | Class | Builds CSV; writes local or application-server files |
| `ZEVO_CHGLOG_BY_PROC` | Report | Selection screen + ALV / file output |
| `ZEVO_CHGLOG_SEED` | Report | Inserts the three example processes and mappings |
| `ZEVO_CHGLOG` | Transaction | Starts the extract report |
| `ZEVO_CHGLOG` | Message class | Report messages |

Customer objects use prefix **`ZEVO_`** (tables, reports, transaction, messages)
or **`ZCL_EVO_`** (classes), aligned with package `ZEVOLVER_AXF`. SAP
transparent table names are limited to **16 characters**, so the process
tables are `ZEVO_CHGLOG_PROC` and `ZEVO_CHGLOG_CHDO` rather than
`ZEVO_CHGLOG_PROCESS` / `ZEVO_CHGLOG_PROC_CHDO`.

---

## 1. Get the repository from GitHub

On your Mac or Linux machine:

```bash
git clone https://github.com/<your-org-or-user>/s4-audit-log-extract.git
cd s4-audit-log-extract
```

If you already cloned from Cursor Origin and added GitHub as a second remote:

```bash
cd s4-audit-log-extract
git pull origin main          # Cursor, if that is still the source of new commits
git push github main          # publish to GitHub so SAP / abapGit can see them
```

abapGit in SAP must point at the **GitHub HTTPS URL**, for example:

```text
https://github.com/<your-org-or-user>/s4-audit-log-extract.git
```

Use the `main` branch. Confirm GitHub contains these files before pulling in
SAP:

- `src/zevo_chglog_proc.tabl.xml`
- `src/zevo_chglog_chdo.tabl.xml`
- `src/zcl_evo_chglog_reader.clas.abap`
- `src/zcl_evo_chglog_exporter.clas.abap`
- `src/zevo_chglog_by_proc.prog.abap`
- `src/zevo_chglog_seed.prog.abap`

If a new class is missing on GitHub, SAP cannot activate the report. Push
from your laptop first, then pull in abapGit.

### If you already installed the old `Z*` names

Objects were renamed to the `ZEVO_` / `ZCL_EVO_` prefix. abapGit will create
**new** objects; it will not rename the old ones in SAP.

After pulling the renamed tree:

1. Activate the new objects (section 2.4).
2. Run `ZEVO_CHGLOG_SEED` (or copy rows from earlier table names into
   `ZEVO_CHGLOG_PROC` / `ZEVO_CHGLOG_CHDO` if you already seeded).
3. Use transaction `ZEVO_CHGLOG`.
4. Delete obsolete objects when you no longer need them, including any of:
   `ZTPROCESS`, `ZTPROC_CHDO`, `ZEVO_PROCESS`, `ZEVO_PROC_CHDO`,
   `ZCL_CHGLOG_READER`, `ZCL_CHGLOG_EXPORTER`, `Z_CHGLOG_BY_PROCESS`,
   `Z_CHGLOG_SEED_CATALOG`, `ZCHGLOG`.

---

## 2. Prepare the S/4 system

### 2.1 Create packages (`SE21`)

abapGit does **not** create the target package. Create them top-down:

| Package | Super package | Settings |
|---|---|---|
| `ZEVOLVER` | — | Software component `HOME`, type **Development**, standard `Z` transport layer |
| `ZEVOLVER_MAIN` | `ZEVOLVER` | Same |
| `ZEVOLVER_AXF` | `ZEVOLVER_MAIN` | Same |

If SAP rejects a super-package assignment, create `ZEVOLVER_AXF` as a
standalone development package. Nesting is organizational only.

### 2.2 Create a workbench request (`SE09`)

Create a **Workbench** request (not a customizing request). You need it because
`ZEVOLVER_AXF` is transportable.

### 2.3 Register the GitHub repo in abapGit

1. Start abapGit (`ZABAPGIT` or `ZABAPGIT_STANDALONE`).
2. New online repository → GitHub HTTPS URL of this repo.
3. Package: `ZEVOLVER_AXF`.
4. Branch: `main`.
5. **Advanced → Activate Change Recording** and enter the workbench request.

Without change recording, the first object fails with:

```text
Change recording must be activated for package ZEVOLVER_AXF
```

### 2.4 Pull and activate

Pull the repository. Then activate in this order (dependency order):

1. `ZEVO_CHGLOG_PROC`
2. `ZEVO_CHGLOG_CHDO`
3. `ZCL_EVO_CHGLOG_READER`
4. `ZCL_EVO_CHGLOG_EXPORTER`
5. `ZEVO_CHGLOG_SEED`
6. `ZEVO_CHGLOG_BY_PROC`
7. Transaction / message class `ZEVO_CHGLOG`

If SAP reports `Type "ZEVO_CHGLOG_PROC" is unknown` or
`Type "ZCL_EVO_CHGLOG_EXPORTER" is unknown`, the later object was activated
before its dependency. Activate the missing table or class first, then retry
the report.

---

## 3. Initialize the three example processes

Do this **once per client** after the tables are active.

Run report `ZEVO_CHGLOG_SEED` (`SE38` or `SA38`).

The seed is **insert-only**. Existing rows are left unchanged.

### Processes it creates (`ZEVO_CHGLOG_PROC`)

| Process key | Sequence | Description |
|---|---|---|
| `P2P` | 010 | Sourcing to Payment |
| `O2C` | 020 | Order to Cash |
| `R2R` | 030 | Record to Report |

### Object classes it assigns (`ZEVO_CHGLOG_CHDO`)

| Process | Object class | Meaning |
|---|---|---|
| P2P | `BANF` | Purchase requisition |
| P2P | `EINKBELEG` | Purchasing document (PO) |
| P2P | `INCOMINGINVOICE` | Incoming invoice |
| O2C | `VERKBELEG` | Sales document |
| O2C | `LIEFERUNG` | Delivery |
| O2C | `FAKTBELEG` | Billing document |
| R2R | `BELEG` | FI accounting document |

### How to read the seed ALV

| Column | Meaning |
|---|---|
| `ENTITY` | `PROCESS` = row in `ZEVO_CHGLOG_PROC`; `OBJECT` = row in `ZEVO_CHGLOG_CHDO` |
| `ACTION` | `Inserted`, `Already exists`, `Skipped: not in TCDOB`, or `Insert failed` |
| `IN_TCDOB` | `X` = this SAP system defines that change-document object |
| `SEEN_CDHDR` | `X` = this client already has change documents for that class |

`Skipped: not in TCDOB` is not a program error. That object class is not
defined in this system, so the seed does not insert it. Add the correct class
for your landscape later (section 4).

`SEEN_CDHDR` blank is also not an error. It only means nobody has changed that
object in this client yet.

After a successful seed, transaction `ZEVO_CHGLOG` shows P2P, O2C, and R2R in
the process dropdown.

---

## 4. Create a new process (catalog is fully configurable)

You do **not** change ABAP to add processes. Maintain two tables.

### 4.1 Optional: generate SM30 dialogs

Only needed if you want a maintenance UI. The seed report and `SE16N` can
populate the tables without this.

For **each** table (`ZEVO_CHGLOG_PROC`, then `ZEVO_CHGLOG_CHDO`):

1. `SE11` → table name → **Utilities → Table Maintenance Generator**.
2. Authorization group: `&NC&`.
3. Function group: `ZEVO_CHGLOG_TMG` (create it if asked).
4. Maintenance type: **one step**.
5. Accept the proposed screen number. Use a **different** screen number for
   the second table.

Do not commit the generated function group to Git. Those screens are
release-specific.

### 4.2 Add the process header

Transaction `SM30` → table `ZEVO_CHGLOG_PROC` → Maintain.

| Field | What to enter |
|---|---|
| `PROCESS` | Unique key, up to 10 characters (example: `H2R`, `PLAN2PROD`) |
| `ACTIVE` | `X` = shown in `ZEVO_CHGLOG`; blank = hidden, mappings kept |
| `SEQ` | Display order in the dropdown (`010`, `020`, …) |
| `DESCR` | Label shown next to the key |

Save. The process now exists but extracts nothing until you assign object
classes.

### 4.3 Assign SAP object classes

Transaction `SM30` → table `ZEVO_CHGLOG_CHDO` → Maintain.

| Field | What to enter |
|---|---|
| `PROCESS` | Same key as in `ZEVO_CHGLOG_PROC` |
| `OBJECTCLAS` | SAP change-document object class (see below) |
| `ACTIVE` | `X` to include it in extracts |
| `SEQ` | Read order within the process |
| `DESCR` | Business label (Purchase Order, Sales Order, …) |

Restart `ZEVO_CHGLOG`. The new process appears automatically.

To hide a process without deleting mappings, clear `ACTIVE` on `ZEVO_CHGLOG_PROC`.
To stop reading one object class, clear `ACTIVE` on that `ZEVO_CHGLOG_CHDO` row.

### 4.4 How to find the right `OBJECTCLAS`

There is no standard SAP API that maps “Order to Cash” to object classes.
You discover them in the system:

1. Transaction `SCDO`, or table `TCDOB` (`SE16N`): search by table name
   (`EKKO` → `EINKBELEG`, `VBAK` → `VERKBELEG`, and so on).
2. Confirm real usage in `CDHDR`: filter `OBJECTCLAS` and a known document
   number in `OBJECTID`.
3. Enter that `OBJECTCLAS` on `ZEVO_CHGLOG_CHDO`.

Only fields whose data elements are flagged for change documents are logged.
Missing field history is SAP configuration, not a report defect.

---

## 5. Run an extract (`ZEVO_CHGLOG`)

Start transaction `ZEVO_CHGLOG` (report `ZEVO_CHGLOG_BY_PROC`).

1. **Process** — list of active `ZEVO_CHGLOG_PROC` entries.
2. **Date** (obligatory) — use a narrow interval. The screen defaults to
   **today**. Historical demo data (for example 2020) will not appear unless
   you change the date.
3. **Time** — optional; empty means the full days covered by the date range.
4. **Max rows** — default `10000`. `0` = no cap. If the cap is hit, results
   are truncated and a warning is shown.
5. **Username / Object ID** — optional extra filters.
6. **Output**:
   - **Display ALV** — interactive list.
   - **Download local CSV** — SAP GUI file dialog, UTF-8 with BOM.
   - **Write application-server CSV** — logical filename from transaction
     `FILE` (see section 6).

Execute. One output row is one changed **field** (item grain), not one
change-document header.

### If the ALV is empty but `CDHDR` has rows

Check, in this order:

1. Date range covers `CDHDR-UDATE` (the default is today).
2. `ZEVO_CHGLOG_CHDO` has that `OBJECTCLAS` for the selected process, and `ACTIVE`
   is set.
3. You are on a version that passes `USERNAME = space` into
   `CHANGEDOCUMENT_READ_HEADERS`. Older versions silently filtered to
   `SY-UNAME` and hid other users’ changes.

---

## 6. Application-server files (transaction `FILE`)

The report never accepts a free physical server path. Basis configures the
allowed location.

1. Transaction `FILE`.
2. Create a logical path, for example `ZEVO_CHGLOG_PATH`, with a physical
   directory per operating-system syntax group.
3. Create a logical filename, for example `ZEVO_CHGLOG_CSV`.
4. Assign the logical path.
5. Physical filename: `<PARAM_1>.csv`.
6. Grant `S_DATASET` for that path to report users.

On the selection screen:

- choose **Write application-server CSV**
- **Logical filename** = `ZEVO_CHGLOG_CSV`
- **Filename parameter** = value substituted for `<PARAM_1>`
  (the report proposes `s4_changelog_<date>_<time>`)

The program calls `FILE_GET_NAME` and refuses the emergency `DIR_GLOBAL`
fallback. Browse the result in `AL11`.

---

## 7. Verification checklist

1. Run `ZEVO_CHGLOG_SEED` and confirm P2P / O2C / R2R were inserted.
2. Start `ZEVO_CHGLOG` and confirm those three processes appear.
3. Pick P2P and a date that exists in `CDHDR` for `EINKBELEG`.
4. Compare a row with `RSSCD100` or the PO change history.
5. Add a dummy process in `SM30` and confirm it appears after restarting
   `ZEVO_CHGLOG`.
6. Local CSV: choose **Download local CSV** and open the file.
7. Server CSV: after `FILE` is configured, write a file and find it in `AL11`.

---

## Design notes

- Headers: `CHANGEDOCUMENT_READ_HEADERS` (object class + date envelope;
  `USERNAME` explicitly blank so all users are included).
- Items: `CHANGEDOCUMENT_READ_POSITIONS`.
- Date / time / user / object-ID select-options are applied in ABAP after
  the header read.
- Archived change documents are not read.
- No custom authorization object in this version; any dialog user who can
  run `ZEVO_CHGLOG` can extract.

A later web/OData option can wrap `ZCL_EVO_CHGLOG_READER` without changing the
catalog model.
