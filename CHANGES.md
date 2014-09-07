## 0.3.0

* `order_query` now accepts columns as varargs. Array form is still supported.
* `order_by` renamed to `seek`

## 0.2.1

* `complete` now defaults to true for list attributes as well.

## 0.2.0

* Dynamic query methods renamed to `order_by`

## 0.1.3

* New condition option `complete` for list conditions for optimized query generation

## 0.1.2

* Wrap top-level `OR` with a redundant `AND` for [performance reasons](https://github.com/glebm/order_query/issues/3).
* Remove redundant parens from the query

## 0.1.1

* `#next(true)` and `#previous(true)` return `nil` if there is only one record in total.

## 0.1.0

Initial release
