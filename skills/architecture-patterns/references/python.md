# Python (FastAPI / Django)

## Folder layout

```
app/orders/
  router.py            # FastAPI router (Django: views.py): edge, thin
  use_cases.py         # one function or class per use case, one public entry point
  models.py            # ORM models: fields and relations
  schemas.py           # pydantic schemas (Django: serializers.py)
app/integrations/payments/
  gateway.py           # port (Protocol/ABC) - real integration only
  stripe_gateway.py    # adapter
```

Keep several small use cases in `use_cases.py` while the file stays under ~250 lines; then split into `use_cases/create_order.py`, one per file.

## File budget per issue type

| Issue type | Files |
| --- | --- |
| New endpoint | Router/view function, use case, schema, model change (4) + migration + test |
| Bugfix | Use case or model + test (2) |
| New CRUD | Router, use cases, model, schemas (~6) + migration + tests |
| Refactor step | One use case extracted per PR |

## Naming

- Use cases `create_order(...)`, `cancel_order(...)` (or class `CreateOrder` with `execute()`).
- Schemas `OrderCreate`, `OrderRead`.

## Do not

- No logic, queries or HTTP calls in routers/views.
- No Repository class over the ORM; query in the use case.
- No fat models with business methods that orchestrate other models or I/O.
- No abstract base class or Protocol without a real external integration.
- No `utils.py` or `helpers.py` dumping ground; name the module by purpose.
- No `services.py` with many unrelated functions (god module).

## Worked example: "POST /orders"

Creates: route in `router.py`, `create_order` in `use_cases.py`, `OrderCreate`/`OrderRead` in `schemas.py`, field change in `models.py` = 4 files, plus 1 migration and 1 test. Payment uses the existing gateway port.
