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
gem 'order_query', '~> 0.1.0'
```

## Usage

### Simple example

```ruby
class Post < ActiveRecord::Base
  include OrderQuery
  order_query :order_list, [
    [:pinned, [true, false]],
    [:published_at, :desc],
    [:id, :desc]
  ]
end

Post.find(31).order_list.next
```

### Advanced example

```ruby
class Issue < ActiveRecord::Base
  include OrderQuery
  order_query :order_display, [
    [:priority, %w(high medium low)],
    [:valid_votes_count, :desc, sql: '(votes - suspicious_votes)'],
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

### Order scopes

```ruby
Issue.order_display         #=> ActiveRecord::Relation<...>
Issue.reverse_order_display #=> ActiveRecord::Relation<...>
```

### Relative order

```ruby
# get the order object, scope default: Issue.all
p = Issue.find(31).order_display(scope)
p.before         #=> ActiveRecord::Relation<...>
p.previous       #=> Issue<...>
# pass true to #next and #previous in order to loop onto the the first / last record
# will not loop onto itself
p.previous(true) #=> Issue<...>
p.position   #=> 5
p.next       #=> Issue<...>
p.after      #=> ActiveRecord::Relation<...>
```

### Dynamic criteria

`order_query` defines methods that call `.order_by_query` and `#relative_order_by_query`, also public:

```ruby
Issue.order_by_query([[:id, :desc]])         #=> ActiveRecord::Relation<...>
Issue.reverse_order_by_query([[:id, :desc]]) #=> ActiveRecord::Relation<...>
Issue.find(31).relative_order_by_query([[:id, :desc]]).next #=> Issue<...>
Issue.find(31).relative_order_by_query(Issue.visible, [[:id, :desc]]).next #=> Issue<...>
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

A query may then look like this (with `?` for values):

```sql
-- Current record: priority='high' (votes - suspicious_votes)=4 updated_at='2014-03-19 10:23:18.671039' id=9
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

This project uses MIT license.


[travis]: http://travis-ci.org/glebm/order_query
[travis-badge]: http://img.shields.io/travis/glebm/order_query.svg
[gemnasium]: https://gemnasium.com/glebm/order_query
[codeclimate]: https://codeclimate.com/github/glebm/order_query
[codeclimate-badge]: http://img.shields.io/codeclimate/github/glebm/order_query.svg
[coveralls]: https://coveralls.io/r/glebm/order_query
[coveralls-badge]: http://img.shields.io/coveralls/glebm/order_query.svg
