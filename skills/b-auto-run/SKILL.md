---
name: b-auto-run
description: Runs the E and B cases of a story in real Revit/AutoCAD with HicasTest (MCP server 'hicas-test') and attaches machine evidence to qa-handover.md. E cases (logic, flow, warnings) run through the add-in's test entries; B cases through the ribbon command. Use from addin-story Phase 4/5.4/6 or addin-batch when the tool is installed. Never marks a case Pass. Requires HicasTest (https://github.com/longpl-1902/hicas-bimcad-test-tool).
---

# b-auto-run

Turns the E and B cases of one story into HicasTest YAML cases, runs them, records **machine evidence**.
Status stays `Chờ xác nhận — có bằng chứng máy`; a human confirms ([accuracy study](https://github.com/longpl-1902/hicas-bimcad-test-tool/blob/main/docs/accuracy-study.md)).

## Inputs

- `F` = `.harness/features/<id>/`: `test-contract.md`, `qa-handover.md`.
- `.harness/addin-story.json`: `deployVersions`, `testBuilds` (year → manifest/dll), `testEntries` (year → `<Addin>.Testing.dll`), `testFixtures`.
- MCP `hicas-test`: `list_hosts`, `validate_test_case`, `run_test_case`; to explore: `list_entries`, `call_entry`, `query_elements`.

## Steps

1. `list_hosts` → target years = `deployVersions` ∩ `ready`. None → stop and say which year to install or build.
   E cases run on the lowest and the newest target year only (logic does not change with the year); all years only when the design §6
   "Version lock" lists `#if` / version-specific API for the feature. B cases: every target year.
2. Write `F/b-cases/<case>.yaml` per case ([format](https://github.com/longpl-1902/hicas-bimcad-test-tool/blob/main/docs/test-case-format.md)).
   Common: `source: qa-handover.md#<case>`; `host.version` = lowest target year; `model` = a test resource
   (addin-story Step 0; none → `Chưa chạy được (thiếu fixture)` and ask; record its path + SHA-256 in `qa-handover.md`);
   every expected value copied from the contract with unit, tolerance **and source**, nothing invented.
   - **E case** (`testEntries` has the year): `run: { mode: entries, assembly: <testEntries[year]> }` and `calls:` from the
     feature's contract file (names, request, prompt ids). Per case: `.validate` / `.plan` calls to check warnings and plan
     without writing, then the main entry with `answers` for each branch (continue and cancel are separate cases);
     `expectResult` / `expectPrompts` / `expect` on each call. No ribbon, no dialog, no screenshot.
   - **B case**: `run` from the script's button/command (Revit `CustomCtrl_%CustomCtrl_%<Tab>%<Panel>%<Button>`; AutoCAD
     command line + prompt answers) and `dialogs`; use the script's "Tự động hoá" block as is. Skip `[Critical]`-only visual checks.
   - An entry that opens a window ends the run as ERROR (unexpected dialog): that is a defect of the add-in; report it.
3. `validate_test_case F/b-cases` → fix until ok.
4. Per target year: `run_test_case path=F/b-cases outputDir=F/evidence/host/<year> ledger=F/b-auto-ledger.csv repeat=<n> hostVersion=<year>` (`repeat=1` in the dev loop of Phase 4, `repeat=2` in the final run to detect flaky cases)
   (one case = one host start, ~20–35 s; a call takes milliseconds. So put all E calls of a feature in **one** case as
   sequential calls — each call states its own precondition, later calls see earlier changes — not one case per AC. B cases stay separate.)
5. `qa-handover.md`, per case: report path(s) in the evidence column; status `Chờ xác nhận — có bằng chứng máy` (MATCH) or
   `Chờ xác nhận` + `máy: MISMATCH/ERROR/NOT-RUN — <reason>`. Never `Pass`.
6. Read only what you need: the tool prints one verdict line per case; open a report just for MISMATCH/ERROR rows
   (`grep MISMATCH <report>`), not every report. Report (≤ 8 lines, Vietnamese): MATCH / MISMATCH / NOT-RUN / ERROR per year and level, flaky cases (`runs_consistent = no`).
   B cases: remind **chạy kịch bản tay trước, rồi mới mở báo cáo máy** (blind-first). E cases: the person only confirms the report.

## Accuracy study (while it is active)

With a deliberately broken build from the user: same command with `build=mutant`. Every case touching the broken behaviour
should be `MISMATCH`; a `MATCH` there is a false pass — report it first.
