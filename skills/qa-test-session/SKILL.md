---
name: qa-test-session
description: QA asks in plain words to test a feature of a Revit/AutoCAD add-in ("test tạo keyplan trên Revit 2024, chụp ảnh từng bước"); Claude drives the host step by step with the HicasTest MCP tools (qa_session_*), screenshots each step, can call the add-in's test entries, and returns a step report. Evidence only — QA decides Pass/Fail. Requires HicasTest (MCP server hicas-test).
---

# qa-test-session

## Before starting — ask only what is missing (one message)

1. Host and year (`list_hosts` shows what is ready on this machine).
2. Test model: a test resource (addin-story Step 0): under a `testFixtures` entry, or a file QA names now (confirm once it is a test model). **Never a customer model**; never search for one. Always opened as a copy.
3. Build under test: Revit `.addin` manifest, or AutoCAD `.dll` (from the lane/worktree build output).
4. The scenario: steps in QA's words and what QA wants to see at each step.

## Driving the session

1. `qa_session_start(title, app, version, model, addinManifest|addinAssembly)` → session id + first screenshot.
2. For each scenario step pick the most direct action:
   - Run a command: `qa_session_run_command`. If QA wants to see or fill its dialog: `wait=false`, then
     `qa_session_ui` (filter by window title) → `qa_session_type` / `qa_session_click` → `qa_session_finish_command`.
   - Click like a user (ribbon tab, button, dialog control): `qa_session_ui` with a `text` filter first, then
     `qa_session_click` with the exact name. Do not guess names.
   - Check values: `qa_session_query(category, parameters, unit)`.
   - Feature logic through test entries (add-in test assembly given as `testAssembly` at start): `qa_session_list_entries`, then
     `qa_session_call_entry(name, argument, answers)` — no UI, no screenshot; `.validate`/`.plan` entries show warnings without writing.
   - Extra evidence: `qa_session_screenshot(label)`; QA's remarks: `qa_session_note`.
3. After every step, look at the returned screenshot path/summary and tell QA in one line what happened.
   If something is unexpected (error dialog, nothing changed), stop and ask before continuing.
4. Finish with `qa_session_end` → `report.md` with all steps and screenshots. Give QA the path.

## Limits (say so instead of working around)

- Picking elements or points inside the model view is not supported yet; ask QA for a model/state where the
  command does not need a pick, or use an `invoke` entry point if the add-in has one.
- AutoCAD view image export is not implemented; screenshots of the window work.
- One session = one host process. Do not touch other windows on the machine.

## Output

The report path and a ≤ 6-line summary: steps run, errors, values checked. No Pass/Fail verdict — QA decides.
If QA confirms a result that should be repeatable, offer to save the scenario as a YAML case for `b-auto-run`.
