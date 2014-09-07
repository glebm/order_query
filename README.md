# order_query [![Build Status][travis-badge]][travis] [![Code Climate][codeclimate-badge]][codeclimate] [![Coverage Status][coverage-badge]][coverage]

<a href="http://use-the-index-luke.com/no-offset">
  <img src="http://use-the-index-luke.com/img/no-offset.q200.png" alt="100% offset-free" align="right" width="106" height="106">
</a>

This gem finds the next or previous record(s) relative to the current one efficiently. It is also useful for implementing infinite scroll.
It uses [keyset pagination](http://use-the-index-luke.com/no-offset) to achieve this.

## Installation

Add to Gemfile:

```ruby
gem 'order_query', '~> 0.3.1'
```

## Usage

Define named order columns with `order_query`:

```ruby
class Post < ActiveRecord::Base
  include OrderQuery
  order_query :order_home,
    [:pinned, [true, false]],
    [:published_at, :desc],
    [:id, :desc]
end
```

Order query accepts a list of order columns as varargs or one array, each one specified as:

```ruby
[<attribute name>, (attribute values in order), (:asc or :desc), (options hash)]
```

Available options:

| option     | description                                                                |
|------------|----------------------------------------------------------------------------|
| unique     | Unique attribute. Default: `true` for primary key, `false` otherwise.      |
| sql        | Customize attribute value SQL                                              |


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

Looping to the first / last record is enabled by default. Pass `false` to disable:

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

Query with dynamic order columns using the `seek(*spec)` class method:

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

Alternatively, get an `OrderQuery::Point` using the `seek(scope, *spec)` instance method:

```ruby
Post.find(42).seek(Post.visible, [:id, :desc]) #=> #<OrderQuery::Point>
# scope defaults to Post.all
Post.find(42).seek([:id, :desc]) #=> #<OrderQuery::Point>
```

#### Advanced options example

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
[codeclimate]: https://codeclimate.com/github/glebm/order_query
[codeclimate-badge]: http://img.shields.io/codeclimate/github/glebm/order_query.svg
[coverage]: https://codeclimate.com/github/glebm/order_query
[coverage-badge]: https://codeclimate.com/github/glebm/order_query/badges/coverage.svg
