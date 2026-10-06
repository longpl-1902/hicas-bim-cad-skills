# Test entries — how a feature is built so an agent can test its logic and flow

Convention for every new feature of a Revit/AutoCAD add-in (any project). Goal: the logic, the warnings and the
sequence of a feature can be run and checked by an agent in a host nobody operates, through the HicasTest MCP
tools `list_entries` / `call_entry` (design: `docs/test-entries.md` in the HicasTest repo).
UI is out of scope: the add-in's own unit tests cover view models; people cover what must be seen.

Status: the tool side exists (HicasTest: `run.mode: entries`, `list_entries`, `call_entry`, `qa_session_*_entry`) and ran live on
Revit 2024; no add-in feature has used it yet. A complete working example (feature, entries, test prompt, case YAML) is
`samples/SampleEntries` and `examples/revit-entries-level.yaml` in the HicasTest package. The add-in test assembly references only
`HicasTest.Contracts.dll` (package folder `contracts/`, dependency-free).

## 1. Split a feature into small methods

A use case is a short pipeline of small, separately callable steps, in this order:

| Step | Reads / writes | Returns |
|---|---|---|
| `Validate(request)` | pure, no host | `ValidationResult`: errors + **prompts** the flow would raise (duplicate name, overwrite…) |
| `Plan(snapshot, request)` | read-only on the model | a `Plan`: what would be created / changed / deleted, with values |
| `Apply(doc, plan, prompt)` | writes, inside the feature's own named transaction | `Result`: ids, counts, values, `prompts` that were raised |
| `Execute(doc, request, prompt)` | the use case = `Validate → Plan → (prompts) → Apply` | `Result` |

- Business in higher layers (Domain/Application), host API in L1 only (see Phase 2 layers). `Validate` and most of
  `Plan` are pure C# and therefore level-A testable; only `Apply` and the snapshot read touch the host.
- A step does one thing and takes/returns plain DTOs (no `Element`, `ObjectId`, window or view model in a signature).
- Steps are small enough to be named in a case: "plan has 3 views", "validate raises `keyplan.duplicate-name`".

## 2. Warnings and confirmations are data, never windows

The flow may need to warn or ask ("name exists, overwrite?", "3 elements skipped"). The use case does it through
one interface and never opens a window or a `TaskDialog` itself:

```csharp
public interface IUserPrompt
{
    PromptAnswer Ask(PromptRequest request);   // Id "keyplan.duplicate-name", Severity, Message, Options, Default
}
```

- Every prompt has a **stable id** (`<feature>.<situation>`), a severity (`info | warning | confirm`), the options
  the user has, and a default. Ids are part of the contract file and appear in the test contract's cases.
- Production: the command passes an implementation that shows the dialog. Tests: an implementation that records
  every prompt and answers from a script (§3), so both branches ("continue", "cancel") are tested.
- Prompts are what the feature raises. Revit failure messages (`FailuresProcessing`) are separate: the bridge
  records them as `warnings` of every call.

## 3. Test entries: main gate and step gates

In the add-in's **test assembly** (`<Addin>.Testing.dll`, not shipped, no UI), public static methods marked with
`[HicasTestEntry]` (attribute from the dependency-free `HicasTest.Contracts` assembly):

| Gate | Name | Calls | Use |
|---|---|---|---|
| **Main** | `feature.action` | `Execute` — the same use case the ribbon command calls | the real flow, with warnings and writes |
| **Step** (secondary) | `feature.action.validate`, `.plan`, `.apply` | one step | read-only dry runs (`validate`, `plan`) to see warnings/plans without writing; `apply` on a given plan |

```csharp
[HicasTestEntry("keyplan.create", Description = "Create a keyplan view", Contract = "docs/specs/test-entries/keyplan.create.yaml")]
public static string Create(UIApplication app, string requestJson)
{
    var request = Json.Parse<CreateKeyplanRequest>(requestJson);
    var result = new CreateKeyplanService().Execute(app.ActiveUIDocument.Document, request, new TestPrompt());
    return Json.Write(result);
}

// The add-in's test implementation of its IUserPrompt: prompts become data.
internal sealed class TestPrompt : IUserPrompt
{
    public string Ask(PromptRequest p) => TestContext.Ask(p.Id, p.Severity, p.Message, p.Options.ToArray(), p.Default); // HicasTest.Contracts
}

[HicasTestEntry("keyplan.create.plan", ReadOnly = true)]
public static string Plan(UIApplication app, string requestJson) => /* Plan(...) as JSON */;
```

- `TestContext.Ask` (via `TestPrompt`) records prompts and answers from the answers the agent passed to `call_entry`
  (`answers: [{id: "keyplan.duplicate-name", option: "cancel"}]`); an unanswered prompt takes its default and is
  flagged `unanswered` in the result, so the agent sees which prompts a flow needs.
- `ReadOnly = true` entries must not write; the agent may call them freely.
- The entry does the **same** work as the command — only the prompt implementation differs. Do not put business
  logic in the entry.

## 4. Contract file per feature (`Contract` of the attribute)

`docs/specs/test-entries/<feature.action>.yaml`: request fields with units and ranges, result fields, the prompt ids
(severity, options, default, when raised), the host failure messages expected, and example values. The test
contract's oracles refer to these names. addin-story writes it with the task; the evaluator checks it matches the code.

## 5. The ribbon command is a thin adapter

Show the dialog → build the request → call the same use case with the production `IUserPrompt` → show the result.
No business logic, no host API beyond what it needs to start the use case. Reviewer and evaluator check the command
and the entry together in the same diff, because this is the gap a test entry cannot close.

## 6. What an agent can then do

1. `list_entries` → names, kind (main / step), read-only flag, prompt ids.
2. `call_entry("keyplan.create.validate", request)` → which prompts the flow would raise, no write.
3. `call_entry("keyplan.create", request, answers)` → result, recorded model changes, prompts raised and how they
   were answered, host warnings; repeat with other answers or requests for the sequence and the other branches.
4. Compare with the contract's expected values (each with its source) → MATCH / MISMATCH, never Pass.
