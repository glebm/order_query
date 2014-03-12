order_query [![Build Status](https://travis-ci.org/glebm/order_query.png)](https://travis-ci.org/glebm/order_query) [![Code Climate](https://codeclimate.com/github/glebm/order_query.png)](https://codeclimate.com/github/glebm/order_query)
================================

ActiveRecord extension that can find next / previous item(s) in 1 query.
This gem is super-alpha, and the queries it generates do not have common conditions factorized yet.

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

Issue.order_display         #=> ActiveRecord::Relation<...>
Issue.reverse_order_display #=> ActiveRecord::Relation<...>

p = Issue.find(31).order_display(scope) # scope default: Issue.all
p.items_before  #=> ActiveRecord::Relation<...>
p.prev_item     #=> Issue<...>
p.position      #=> 5
p.next_item     #=> Issue<...>
p.items_after   #=> ActiveRecord::Relation<...>


```

This project uses MIT-LICENSE.
