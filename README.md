# order_query [![Build Status][travis-badge]][travis] [![Coverage Status][coverage-badge]][coverage]

<a href="http://use-the-index-luke.com/no-offset">
  <img src="http://use-the-index-luke.com/img/no-offset.q200.png" alt="100% offset-free" align="right" width="106" height="106">
</a>

This gem finds the next or previous record(s) relative to the current one efficiently using [keyset pagination](http://use-the-index-luke.com/no-offset), e.g. for navigation or infinite scroll.

## Installation

Add to Gemfile:

```ruby
gem 'order_query', '~> 0.5.1'
```

## Usage

Use `order_query(scope_name, *order_option)` to create scopes and class methods
in your model and specify how you want results ordered. A basic example:

```ruby
class Post < ActiveRecord::Base
  include OrderQuery
  order_query :order_home,
    [:pinned, [true, false]], # First sort by :pinned over t/f in :desc order
    [:published_at, :desc] # Next sort :published_at in :desc order
end
```

Each order option specified in `order_query` is an array in the following form:

1. Symbol of the attribute name (required).
2. An array of values to order by, such as `%w(high medium low)` or `[true, false]` (optional).
3. Sort direction, `:asc` or `:desc` (optional). Default: `:asc`; `:desc` when values to order by are specified.
4. A hash (optional):

| option     | description                                                                |
|------------|----------------------------------------------------------------------------|
| unique     | Unique attribute. Default: `true` for primary key, `false` otherwise.      |
| sql        | Customize column SQL.                                                      |
| nulls      | If set to `:first` or `:last`, orders `NULL`s accordingly.                 |

If no unique column is specified, `[primary_key, :asc]` is used. Unique column must be last.

### Scopes for `ORDER BY`

```ruby
Post.published.order_home         #=> #<ActiveRecord::Relation>
Post.published.order_home_reverse #=> #<ActiveRecord::Relation>
```

### Before / after, previous / next, and position

First, get an `OrderQuery::Point` for the record:

```ruby
p = Post.published.order_home_at(Post.find(31)) #=> #<OrderQuery::Point>
```

It exposes these finder methods:

```ruby
p.before   #=> #<ActiveRecord::Relation>
p.after    #=> #<ActiveRecord::Relation>
p.previous #=> #<Post>
p.next     #=> #<Post>
p.position #=> 5
```

The `before` and `after` methods also accept a boolean argument that indicates
whether the relation should exclude the given point or not.
By default the given point is excluded, if you want to include it,
use `before(false)` / `after(false)`.

If you want to obtain only a chunk (i.e., a page), use `before` or `after`
with ActiveRecord's `limit` method:

```ruby
p.after.limit(20) #=> #<ActiveRecord::Relation>
```

Looping to the first / last record is enabled for `next` / `previous` by default. Pass `false` to disable:

```ruby
p = Post.order_home_at(Post.order_home.first)
p.previous        #=> #<Post>
p.previous(false) #=> nil
```

Even with looping, `nil` will be returned if there is only one record.

You can also get an `OrderQuery::Point` from an instance and a scope:

```ruby
posts = Post.published
post  = posts.find(42)
post.order_home(posts) #=> #<OrderQuery::Point>
```

### Dynamic columns

Query with dynamic order columns using the `seek(*order)` class method:

```ruby
space = Post.visible.seek([:id, :desc]) #=> #<OrderQuery::Space>
```

This returns an `OrderQuery::Space` that exposes these methods:

```ruby
space.scope           #=> #<ActiveRecord::Relation>
space.scope_reverse   #=> #<ActiveRecord::Relation>
space.first           #=> scope.first
space.last            #=> scope_reverse.first
space.at(Post.first)  #=> #<OrderQuery::Point>
```

`OrderQuery::Space` is also available for defined order_queries:

```ruby
Post.visible.order_home_space #=> #<OrderQuery::Space>
```

Alternatively, get an `OrderQuery::Point` using the `seek(scope, *order)` instance method:

```ruby
Post.find(42).seek(Post.visible, [:id, :desc]) #=> #<OrderQuery::Point>
# scope defaults to Post.all
Post.find(42).seek([:id, :desc]) #=> #<OrderQuery::Point>
```

### Advanced example

```ruby
class Post < ActiveRecord::Base
  include OrderQuery
  order_query :order_home,
    # For an array of order values, default direction is :desc
    # High-priority issues will be ordered first in this example
    [:priority, %w(high medium low)],
    # A method and custom SQL can be used instead of an attribute
    [:valid_votes_count, :desc, sql: '(votes - suspicious_votes)'],
    # Default sort order for non-array columns is :asc, just like SQL
    [:updated_at, :desc],
    # pass unique: true for unique attributes to get more optimized queries
    # unique is true by default for primary_key
    [:id, :desc]
  def valid_votes_count
    votes - suspicious_votes
  end
end
```

## How it works

Internally this gem builds a query that depends on the current record's values and looks like this:

```sql
-- Current post: pinned=true published_at='2014-03-21 15:01:35.064096' id=9
SELECT "posts".* FROM "posts"  WHERE
  ("posts"."pinned" = 'f' OR
   "posts"."pinned" = 't' AND (
      "posts"."published_at" < '2014-03-21 15:01:35.064096' OR
      "posts"."published_at" = '2014-03-21 15:01:35.064096' AND "posts"."id" < 9))
ORDER BY
  "posts"."pinned"='t' DESC, "posts"."pinned"='f' DESC,
  "posts"."published_at" DESC,
  "posts"."id" DESC
LIMIT 1
```

The actual query is a bit different because `order_query` wraps the top-level `OR` with a (redundant) non-strict column `x0' AND (x0 OR ...)`
for [performance reasons](https://github.com/glebm/order_query/issues/3).
This can be disabled with `OrderQuery.wrap_top_level_or = false`.

See the implementation in [sql/where.rb](/lib/order_query/sql/where.rb).

See how this affects query planning in Markus Winand's slides on [Pagination done the Right Way](http://use-the-index-luke.com/blog/2013-07/pagination-done-the-postgresql-way).

This project uses MIT license.


[travis]: http://travis-ci.org/glebm/order_query
[travis-badge]: http://img.shields.io/travis/glebm/order_query.svg
[gemnasium]: https://gemnasium.com/glebm/order_query
[coverage]: https://codeclimate.com/github/glebm/order_query
[coverage-badge]: https://api.codeclimate.com/v1/badges/82e424e9ee2acb02292c/test_coverage
