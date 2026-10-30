# Dart / Flutter

## Folder layout

```
lib/features/orders/
  orders_screen.dart            # edge: screen widget, reads state and sends events
  orders_controller.dart        # edge: one state holder per screen (Notifier/Cubit)
  create_order.dart             # use case: call()
  order.dart                    # model: fields, fromJson/toJson, copyWith
  widgets/order_form.dart       # presentational: props in, callbacks out
lib/integrations/payments/
  payment_gateway.dart          # port (real integration only)
  stripe_payment_gateway.dart   # adapter
```

Use the state library the repo already has (Riverpod, Bloc, Provider). If it has none, use Riverpod. The architecture is the same: the controller holds screen state and calls ONE use case; the use case holds the rules and calls the API client or a port.

## File budget per issue type

| Issue type | Files |
| --- | --- |
| New screen | Screen, controller, use case, model (4) + widget test |
| Bugfix | Controller, use case or widget + test (2) |
| New CRUD | Screen, controller, 2-3 use cases, model, form widget (~6) + tests |
| Refactor step | One use case extracted or one widget split per PR |

## Naming

- Files in `snake_case.dart`; classes in `PascalCase`.
- Use case: verb + noun, `CreateOrder`, `CancelOrder`; one public `call()`.
- Screen `<Feature>Screen`, controller `<Feature>Controller`, widgets named by what they show.

## Do not

- No HTTP calls, JSON parsing or business rules inside widgets or `build()`.
- No `Repository` per model; call the API client from the use case.
- No `Manager`, `Helper` or `Service` class with many unrelated methods; one use case per class.
- No interface for a use case or a model.
- No use case that only forwards to one API call: keep it in the controller until a rule appears.
- No `setState` for state shared between screens, and no global store for state used by one screen.
- No widget file over ~250 lines or `build()` over ~30 lines: extract a widget.

## Worked example: "Screen to create an order"

Creates: `orders_screen.dart`, `orders_controller.dart`, `create_order.dart`, `order.dart` = 4 files, plus 1 widget test. Payment goes through the existing `PaymentGateway` port (a real external integration), no new files.
