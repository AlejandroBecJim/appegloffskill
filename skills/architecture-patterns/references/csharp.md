# C#

## Folder layout

```
src/Orders/
  OrdersController.cs            # edge: Controller or Minimal API endpoint
  CreateOrder.cs                 # use case: Command + Handler in one file (or CreateOrderUseCase)
  Order.cs                       # entity: data and relations
  OrderDto.cs                    # request/response (records)
src/Integrations/Payments/
  IPaymentGateway.cs             # port (real integration only)
  StripePaymentGateway.cs        # adapter
```

No MediatR required: register the use case class in DI and inject it into the controller. The Command record and the Handler live in the same file while they stay small.

## File budget per issue type

| Issue type | Files |
| --- | --- |
| New endpoint | Controller/endpoint method, use case (Command + Handler), DTO record, entity change (4) + migration + test |
| Bugfix | Use case or entity + test (2) |
| New CRUD | Controller, 2-3 use cases, entity, DTOs (~6) + migration + tests |
| Refactor step | One use case extracted per PR |

## Naming

- Use case `<Verb><Noun>` with one public `Handle()` or `ExecuteAsync()`.
- DTOs as `record`; entity named after the table concept.

## Do not

- No logic in controllers or in entities beyond invariants of its own data.
- No generic `IRepository<T>`; use `DbContext` in the use case.
- No interface per use case or per entity (`IOrderService` with one implementation).
- No AutoMapper profile for 2-3 properties; map by hand.
- No Service class with many unrelated methods.
- No pipeline behaviors or mediator until 3 cross-cutting needs repeat.

## Worked example: "POST /orders"

Creates: endpoint in `OrdersController`, `CreateOrder.cs` (Command + Handler), `OrderDto.cs`, `Order.cs` change = 4 files, plus 1 EF migration and 1 integration test. Payment uses the existing `IPaymentGateway`.
