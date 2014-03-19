order_query [![Build Status](https://travis-ci.org/glebm/order_query.png)](https://travis-ci.org/glebm/order_query) [![Code Climate](https://codeclimate.com/github/glebm/order_query.png)](https://codeclimate.com/github/glebm/order_query) [![Coverage Status](https://coveralls.io/repos/glebm/order_query/badge.png?branch=master)](https://coveralls.io/r/glebm/order_query?branch=master)
================================

order_query provides ActiveRecord methods to find items relative to the position of a given one for a particular ordering. These methods are useful for many navigation scenarios, e.g. links to the next / previous search result from the show page in a typical index/search -> show scenario.

order_query generates queries that only use `WHERE`, `ORDER BY`, and `LIMIT`, and *not* `OFFSET`. It only takes 1 query (returning 1 row) to get the record before or after the given one.

This gem is alpha, and the queries it generates are not fully optimized yet.

No gem has been released, to install from git:

```ruby
gem 'order_query', git: 'https://github.com/glebm/order_query'
```

## Usage

```ruby
class Issue < ActiveRecord::Base
  include OrderQuery
  order_query :order_display, [
    [:priority, %w(high medium low)],
    [:valid_votes_count, :desc, sql: '(votes - suspicious_votes)'],
    [:updated_at, :desc],
    [:id, :desc]
  ]
  def valid_votes_count
    votes - suspicious_votes
  end
end
```

Order scopes:

```ruby
Issue.order_display         #=> ActiveRecord::Relation<...>
Issue.reverse_order_display #=> ActiveRecord::Relation<...>
```

Relative order:

```ruby
p = Issue.find(31).order_display(scope) # scope default: Issue.all
p.items_before  #=> ActiveRecord::Relation<...>
p.prev_item     #=> Issue<...>
p.position      #=> 5
p.next_item     #=> Issue<...>
p.items_after   #=> ActiveRecord::Relation<...>
```

`order_query` defines methods that call `.order_by_query` and `#relative_order_by_query`, also public:

```ruby
Issue.order_by_query([[:id, :desc]])         #=> ActiveRecord::Relation<...>
Issue.reverse_order_by_query([[:id, :desc]]) #=> ActiveRecord::Relation<...>
Issue.find(31).relative_order_by_query([[:id, :desc]]).next_item #=> Issue<...>
```

This project uses MIT license.
