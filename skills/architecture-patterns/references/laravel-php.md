# Laravel / PHP

## Folder layout (Laravel)

```
app/
  Http/
    Controllers/OrderController.php     # edge: thin
    Requests/StoreOrderRequest.php      # validation (FormRequest)
    Resources/OrderResource.php         # response shape
  Actions/Orders/CreateOrder.php        # use case: handle()
  Models/Order.php                      # fields, casts, relations
  Integrations/Payments/PaymentGateway.php        # port (real integration only)
  Integrations/Payments/StripePaymentGateway.php  # adapter
```

Plain PHP: same layers without the framework classes: `public/index.php` or router -> `OrderController` -> `Actions\CreateOrder` -> `Models\Order` (PDO or ORM), validation as a small function or class in the controller folder.

## File budget per issue type

| Issue type | Files |
| --- | --- |
| New endpoint | Controller method, FormRequest, Action, Resource (4) + migration + test |
| Bugfix | Action or Model + test (2) |
| New CRUD | Controller, 2 FormRequests, 1-2 Actions, Model, Resource (~6) + migration + tests |
| Refactor step | One Action extracted per PR |

## Naming

- Action: verb + noun, `CreateOrder`, `CancelOrder`; one public `handle()`.
- FormRequest: `StoreOrderRequest`, `UpdateOrderRequest`.
- Port: capability name (`PaymentGateway`), adapter prefixed by vendor.

## Do not

- No logic, queries or HTTP calls to third parties in controllers.
- No Repository per model; use Eloquent in the Action.
- No Service class with many unrelated methods (god service); one Action per use case.
- No Interface for an Action or a Model.
- No Action that only calls one Eloquent method: keep it in the controller until a rule appears.
- No logic in Models beyond relations, casts and scopes.

## Worked example: "POST /orders"

Creates: `OrderController@store`, `StoreOrderRequest`, `CreateOrder`, `OrderResource` = 4 files, plus 1 migration and 1 feature test. Payment goes through the existing `PaymentGateway` port (a real external integration), no new files.
