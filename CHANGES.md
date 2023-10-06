## 0.5.3

* Rails 7.1 now supported.

## 0.5.2

* Ruby 3.0 now supported.
* Rails 7.0 now supported.

## 0.5.1

* Rails 6.1 now supported.
## 0.5.0

* Rails 6 now supported.
* Fixes support for `nil`s with explicit order, when a `nil` is neither
  the first nor the last element of the explicit order,
  e.g. `status: ['assigned', nil, 'fixed']`.
  [#93b08877](https://github.com/glebm/order_query/commit/93b08877790a0ff02eea0d835def6ff3c40a83da)

## 0.4.1

* If a column had a `nulls:` option and there were multiple records with `NULL`,
  all of these records but one were previously skipped. This is now fixed.
  [#21](https://github.com/glebm/order_query/issues/21)

## 0.4.0

* Adds nulls ordering options `nulls: :first` and `nulls: :last`.
* Now supports Rails 5.2.
* Dropped support for Rails < 5 and Ruby < 2.3.

## 0.3.4

* The `before` and `after` methods now accept a boolean argument that indicates
  whether the relation should exclude the given point or not.
  By default the given point is excluded, if you want to include it,
  use `before(false)` / `after(false)`.

## 0.3.3

* Now compatible with Rails 5 beta 1.

## 0.3.2

* Optimization: do not wrap top-level disjunctive in `AND` when the column has an enumerated order. [Read more](https://github.com/glebm/order_query/issues/3#issuecomment-54764638).
* Boolean enum columns (e.g. `[:pinned, [true, false]]`) are now automatically collapsed to `ORDER by column ASC|DESC`.

## 0.3.1

* Automatically add primary key when there is no unique column for the order
* Remove `complete` option
* Fix Rubinius compatibility

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
