search_in_order [![Build Status](https://travis-ci.org/glebm/search_in_order.png)](https://travis-ci.org/glebm/search_in_order) [![Code Climate](https://codeclimate.com/github/glebm/search_in_order.png)](https://codeclimate.com/github/glebm/search_in_order)
================================

ActiveRecord extension that can find next / previous item(s) in 1 query.
This gem is super-alpha, and the queries it generates do not have common conditions factorized yet.

No gem has been released, to install from git:

```ruby
gem 'search_in_order', git: 'https://github.com/glebm/search_in_order'
```

## Usage

```ruby
class Issue < ActiveRecord::Base
  include SearchInOrder
  search_in_order :display_order, [
    [:priority, %w(high medium low)],
    [:valid_votes_count, :desc, sql: '(votes - suspicious_votes)'],
    [:updated_at, :desc],
    [:id, :desc]
  ]
  def valid_votes_count
    votes - suspicious_votes
  end
end

Issue.display_order.scope         #=> ActiveRecord::Relation<...>
Issue.display_order.reverse_scope #=> ActiveRecord::Relation<...>

q = Issue.find(31).display_order(scope) # scope default: Issue.all
q.items_before  #=> ActiveRecord::Relation<...>
q.prev_item     #=> Issue<...>
q.position      #=> 5
q.next_item     #=> Issue<...>
q.items_after   #=> ActiveRecord::Relation<...>
```

This project uses MIT-LICENSE.
