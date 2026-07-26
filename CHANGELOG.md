## 0.0.4

- Fix memory leak when creating derived contexts via `withCancel()` or `withTimeout()` from uncancelable parent contexts (e.g., `Context.empty()`).

## 0.0.3

- Added `withCancel` to support context cancellation.
- Added `withoutCancel` to detach context cancellation from parent.
- Added `withTimeout` and `withDeadline` for automatic time-based cancellation.

## 0.0.2

- Changed context key type from `String` to `Object`.

## 0.0.1

- Initial version.
