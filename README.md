# order_query [![Build Status][travis-badge]][travis] [![Code Climate][codeclimate-badge]][codeclimate] [![Coverage Status][coveralls-badge]][coveralls]

order_query provides ActiveRecord methods to find items relative to the position of a given one for a particular ordering. These methods are useful for many navigation scenarios, e.g. links to the next / previous search result from the show page in a typical index/search -> show scenario.
order_query generates queries that only use `WHERE`, `ORDER BY`, and `LIMIT`, and *not* `OFFSET`. It only takes 1 query (returning 1 row) to get the record before or after the given one.

No gem has been released yet, to install from git:

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
p.before     #=> ActiveRecord::Relation<...>
p.previous   #=> Issue<...>
p.position   #=> 5
p.next       #=> Issue<...>
# pass true to #next and #previous in order to loop onto the the first / last record if there are no records after / before this one.
# will not loop onto itself
p.next(true)
p.after      #=> ActiveRecord::Relation<...>
```

`order_query` defines methods that call `.order_by_query` and `#relative_order_by_query`, also public:

```ruby
Issue.order_by_query([[:id, :desc]])         #=> ActiveRecord::Relation<...>
Issue.reverse_order_by_query([[:id, :desc]]) #=> ActiveRecord::Relation<...>
Issue.find(31).relative_order_by_query([[:id, :desc]]).next #=> Issue<...>
Issue.find(31).relative_order_by_query(Issue.visible, [[:id, :desc]]).next #=> Issue<...>
```

This project uses MIT license.


[travis]: http://travis-ci.org/glebm/order_query
[travis-badge]: http://img.shields.io/travis/glebm/order_query.svg
[gemnasium]: https://gemnasium.com/glebm/order_query
[codeclimate]: https://codeclimate.com/github/glebm/order_query
[codeclimate-badge]: http://img.shields.io/codeclimate/github/glebm/order_query.svg
[coveralls]: https://coveralls.io/r/glebm/order_query
[coveralls-badge]: http://img.shields.io/coveralls/glebm/order_query.svg
