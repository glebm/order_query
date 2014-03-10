search_in_order [![Build Status](https://travis-ci.org/glebm/search_in_order.png)](https://travis-ci.org/glebm/search_in_order) [![Code Climate](https://codeclimate.com/github/glebm/search_in_order.png)](https://codeclimate.com/github/glebm/search_in_order)
================================

ActiveRecord plugin that can find next / previous item(s) in 1 query.
This gem is super-alpha, and the queries it generates are not yet fully optimized yet.

No gem has been released yet, but you can install it from the repository:

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

scope = Issue.open.search(params[:search])
ord = Issue.find(31).display_order(scope) # scope default: Issue.all
ord.prev_item     #=> Issue<...>
ord.next_item     #=> Issue<...>
ord.items_after   #=> ActiveRecord::Relation<...>
ord.items_before  #=> ActiveRecord::Relation<...>
ord.position      #=> 5
ord.ordered_scope #=> ActiveRecord::Relation<...>
```

This project uses MIT-LICENSE.
