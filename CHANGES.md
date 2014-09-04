## 0.1.2

* Wrap top-level `OR` with a redundant `AND` for [performance reasons](https://github.com/glebm/order_query/issues/3).
* Remove redundant parens from the query

## 0.1.1

* `#next(true)` and `#previous(true)` return `nil` if there is only one record in total.

## 0.1.0

Initial release
