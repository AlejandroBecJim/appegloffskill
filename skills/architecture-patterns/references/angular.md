# Angular

## Folder layout

```
src/app/orders/
  order-list.component.ts        # edge: smart component (template inline or .html)
  order-list.component.html
  orders.service.ts              # use cases: one method per use case, grouped by feature
  order.model.ts                 # typed interfaces
```

A service method is one use case. When `orders.service.ts` exceeds ~250 lines or mixes unrelated flows, split by use case group (`order-checkout.service.ts`), never into one class per method.

## File budget per issue type

| Issue type | Files |
| --- | --- |
| New screen | Component (.ts + .html counted as 1), service method, model, route entry (4) + test |
| Bugfix | Component or service + test (2) |
| New CRUD | List component, form component, service, model, routes (~6) + tests |
| Refactor step | One service split or one component slimmed per PR |

## Naming

- `<feature>.service.ts`, `<name>.component.ts`, `<entity>.model.ts`.
- Service methods named by use case: `createOrder()`, `cancelOrder()`.
- Facade only when 2+ components share the same state; otherwise a service is enough.

## Do not

- No HTTP calls or business rules inside components; the component calls the service and renders.
- No god service holding every feature's methods and state.
- No `any`; type responses with the model.
- No NgRx/store for state used by one component (rule of 3).
- No service that only forwards to `HttpClient` without a rule: call it from the feature service that owns the use case.
- No separate module or file per tiny pipe/directive used once.

## Worked example: "Screen to create an order"

Creates: `order-form.component.ts` (+ html), `OrdersService.createOrder()` added to the existing service, `order.model.ts`, route entry = 4 files, plus 1 component test. No new interface, no store.
