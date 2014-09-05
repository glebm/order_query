# order_query [![Build Status][travis-badge]][travis] [![Code Climate][codeclimate-badge]][codeclimate] [![Coverage Status][coveralls-badge]][coveralls]

order_query gives you next or previous records relative to the current one efficiently.

For example, you have a list of items, sorted by priority. You have 10,000 items!
If you are showing the user a single item, how do you provide buttons for the user to see the previous item or the next item?

You could pass the item's position to the item page and use `OFFSET` in your SQL query.
The downside of this, apart from having to pass a number that may change, is that the database cannot jump to the offset; it has to read every record until it reaches, say, the 9001st record.
This is slow. Here is where `order_query` comes in!

`order_query` uses the same `ORDER BY` query, but also includes a `WHERE` clause that excludes records before (for next) or after (for prev) the current one.

## Installation

Add to Gemfile:

```ruby
gem 'order_query', '~> 0.1.3'
```

## Usage

Define a list of order conditions with `order_query`:

```ruby
class Post < ActiveRecord::Base
  include OrderQuery
  order_query :order_for_index, [
    [:pinned, [true, false], complete: true],
    [:published_at, :desc],
    [:id, :desc]
  ]
end
```

An order condition is specified as an attribute name, optionally an ordered list of values, and a sort direction.
Additional options are:

| option     | description                                                                                             |
|------------|---------------------------------------------------------------------------------------------------------|
| unique     | Unique attribute, avoids redundant comparisons. Default: `true` for primary key, `false` otherwise.     |
| complete   | Complete attribute, avoids redundant comparisons. Default: `false` for ordered lists, `true` otherwise. |
| sql        | Customize attribute value SQL                                                                           |

### Order scopes

Order scopes are defined by `order_query`:

```ruby
Post.order_for_index         #=> ActiveRecord::Relation<...>
Post.reverse_order_for_index #=> ActiveRecord::Relation<...>
```

### Before, after, previous, and next

An method is added by `order_query` to query around a record:

```ruby
# get the order object, scope default: Post.all
p = Post.find(31).order_for_index(scope) #=> OrderQuery::RelativeOrder<...>
p.before         #=> ActiveRecord::Relation<...>
p.previous       #=> Post<...>
# pass true to #next and #previous in order to loop onto the the first / last record
# will not loop onto itself
p.previous(true) #=> Post<...>
p.position   #=> 5
p.next       #=> Post<...>
p.after      #=> ActiveRecord::Relation<...>
```

#### Order conditions, advanced example

```ruby
class Issue < ActiveRecord::Base
  include OrderQuery
  order_query :order_display, [
    # Pass an array for attribute order, and an optional sort direction for the array,
    # default is *:desc*, so that first in the array <=> first in the result
    [:priority, %w(high medium low), :desc, complete: true],
    # Sort attribute can be a method name, provided you pass :sql for the attribute
    [:valid_votes_count, :desc, sql: '(votes - suspicious_votes)'],
    # Default sort order for non-array attributes is :asc, just like SQL
    [:updated_at, :desc],
    # pass unique: true for unique attributes to get more optimized queries
    # default: true for primary_key, false otherwise
    [:id, :desc, unique: true]
  ]
  def valid_votes_count
    votes - suspicious_votes
  end
end
```

### Dynamic order conditions

To query with dynamic order conditions use `Model.order_by` and `Model#order_by`:

```ruby
Issue.order_by([[:id, :desc]])         #=> ActiveRecord::Relation<...>
Issue.visible.reverse_order_by([[:id, :desc]]) #=> ActiveRecord::Relation<...>
Issue.find(31).order_by([[:id, :desc]]).next #=> Issue<...>
Issue.find(31).order_by(Issue.visible, [[:id, :desc]]).next #=> Issue<...>
```

For example, consider ordering by a list of ids returned from an elasticsearch query:

```ruby
ids = Issue.keyword_search('ruby') #=> [7, 3, 5]
Issue.where(id: ids).order_by([[:id, ids]]).first(2).to_a #=> [Issue<id=7>, Issue<id=3>]
```

## How it works

Internally this gem builds a query that depends on the current record's order values and looks like:

```sql
SELECT ... WHERE
x0 OR
y0 AND (x1 OR
        y1 AND (x2 OR
                y2 AND ...))
ORDER BY ...
LIMIT 1
```

Where `x` correspond to `>` / `<` terms, and `y` to `=` terms (for resolving ties), per order criterion.

A query may then look like this:

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

A query for the advanced example would look like this:

```sql
-- Current issue: priority='high' (votes - suspicious_votes)=4 updated_at='2014-03-19 10:23:18.671039' id=9
SELECT  "issues".* FROM "issues"  WHERE
  ("issues"."priority" IN ('medium','low') OR
   "issues"."priority" = 'high' AND (
       (votes - suspicious_votes) < 4 OR
       (votes - suspicious_votes) = 4 AND (
           "issues"."updated_at" < '2014-03-19 10:23:18.671039' OR
           "issues"."updated_at" = '2014-03-19 10:23:18.671039' AND
               "issues"."id" < 9)))
ORDER BY
  "issues"."priority"='high' DESC,
  "issues"."priority"='medium' DESC,
  "issues"."priority"='low' DESC,
  (votes - suspicious_votes) DESC,
  "issues"."updated_at" DESC,
  "issues"."id" DESC
LIMIT 1
```

The top-level `x0 OR ..` clause is actually wrapped with `x0' AND (x0 OR ...)`, where *x0'* is a non-strict condition,
for [performance reasons](https://github.com/glebm/order_query/issues/3). This can be disabled with `OrderQuery::WhereBuilder.wrap_top_level_or = false`.

See how this affects query planning in Markus Winand's slides on [Pagination done the Right Way](http://use-the-index-luke.com/blog/2013-07/pagination-done-the-postgresql-way).

This project uses MIT license.


[travis]: http://travis-ci.org/glebm/order_query
[travis-badge]: http://img.shields.io/travis/glebm/order_query.svg
[gemnasium]: https://gemnasium.com/glebm/order_query
[codeclimate]: https://codeclimate.com/github/glebm/order_query
[codeclimate-badge]: http://img.shields.io/codeclimate/github/glebm/order_query.svg
[coveralls]: https://coveralls.io/r/glebm/order_query
[coveralls-badge]: http://img.shields.io/coveralls/glebm/order_query.svg
