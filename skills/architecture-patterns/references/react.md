# React

## Folder layout

```
src/features/orders/
  OrdersPage.tsx              # edge: page/container, wires hook and components
  useCreateOrder.ts           # one hook per use case
  OrderForm.tsx               # presentational: props in, events out
  order.types.ts              # types
  ordersApi.ts                # fetch calls for the feature (only if >1 hook uses them)
```

Hook = use case: it holds the rules and the calls to the API. Presentational components have no fetch, no business rules.

## File budget per issue type

| Issue type | Files |
| --- | --- |
| New screen | Page, hook, presentational component, types (4) + test |
| Bugfix | Hook or component + test (2) |
| New CRUD | Page, 2-3 hooks, form + list components, types (~6) + tests |
| Refactor step | One hook extracted or one component split per PR |

## Naming

- Hooks `use<Verb><Noun>`: `useCreateOrder`, `useCancelOrder`.
- Pages `<Feature>Page`, components PascalCase, types `<entity>.types.ts`.

## Do not

- No fetch or business logic inside components; use the hook.
- No generic `useApi`/`useFetch` wrapper until 3 hooks repeat the same shape.
- No global store (Redux/Zustand) for state used by one page.
- No component per HTML element wrapper (`<Title>` that only renders `<h1>`).
- No context provider for data passed one level down.
- No hook that only calls another hook.

## Worked example: "Screen to create an order"

Creates: `OrdersPage.tsx`, `useCreateOrder.ts`, `OrderForm.tsx`, `order.types.ts` = 4 files, plus 1 test for the hook. The API call lives inside the hook until a second hook needs it.
