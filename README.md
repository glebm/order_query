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
gem 'order_query', '~> 0.1.2'
```

## Usage

Define the criteria with `order_query`:

```ruby
class Post < ActiveRecord::Base
  include OrderQuery
  order_query :order_list, [
    [:pinned, [true, false]],
    [:published_at, :desc],
    [:id, :desc]
  ]
end
```

### Order scopes

Defining the criteria adds `ORDER BY` scopes:

```ruby
Post.order_list #=> ActiveRecord::Relation<...>
Post.reverse_order_list #=> ActiveRecord::Relation<...>
```

### Records relative to a given one

`order_query` also adds an instance method for querying relative to the record:

```ruby
# get the order object, scope default: Post.all
p = Post.find(31).order_list(scope) #=> OrderQuery::RelativeOrder<...>
p.before         #=> ActiveRecord::Relation<...>
p.previous       #=> Post<...>
# pass true to #next and #previous in order to loop onto the the first / last record
# will not loop onto itself
p.previous(true) #=> Post<...>
p.position   #=> 5
p.next       #=> Post<...>
p.after      #=> ActiveRecord::Relation<...>
```

### Advanced options

Pass arrays and custom sql as order conditions:

```ruby
class Issue < ActiveRecord::Base
  include OrderQuery
  order_query :order_display, [
    # Pass an array for attribute order, and an optional sort direction for the array,
    # default is *:desc*, so that first in the array <=> first in the result
    [:priority, %w(high medium low), :desc],
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

To query with dynamic order conditions use `Model.order_by_query` and `Model#relative_order_by_query`:

```ruby
Issue.order_by_query([[:id, :desc]])         #=> ActiveRecord::Relation<...>
Issue.reverse_order_by_query([[:id, :desc]]) #=> ActiveRecord::Relation<...>
Issue.find(31).relative_order_by_query([[:id, :desc]]).next #=> Issue<...>
Issue.find(31).relative_order_by_query(Issue.visible, [[:id, :desc]]).next #=> Issue<...>
```

For example, consider ordering by a list of ids returned from an elasticsearh query:

```ruby
ids = Issue.keyword_search('ruby') #=> [7, 3, 5]
Issue.where(id: ids).order_by_query([[:id, ids]]).first(2).to_a #=> [Issue<id=7>, Issue<id=3>]
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
for [performance reasons](https://github.com/glebm/order_query/issues/3).

See how this affects query planning in Markus Winand's slides on [Pagination done the Right Way](http://use-the-index-luke.com/blog/2013-07/pagination-done-the-postgresql-way).

This project uses MIT license.


[travis]: http://travis-ci.org/glebm/order_query
[travis-badge]: http://img.shields.io/travis/glebm/order_query.svg
[gemnasium]: https://gemnasium.com/glebm/order_query
[codeclimate]: https://codeclimate.com/github/glebm/order_query
[codeclimate-badge]: http://img.shields.io/codeclimate/github/glebm/order_query.svg
[coveralls]: https://coveralls.io/r/glebm/order_query
[coveralls-badge]: http://img.shields.io/coveralls/glebm/order_query.svg
