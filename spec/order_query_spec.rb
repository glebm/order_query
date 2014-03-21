require 'spec_helper'

# Simple example
class Post < ActiveRecord::Base
  include OrderQuery
  order_query :order_list, [
      [:pinned, [true, false]],
      [:published_at, :desc],
      [:id, :desc]
  ]
end

def create_post(attr = {})
  Post.create!({pinned: false, published_at: Time.now}.merge(attr))
end

# Advanced example
class Issue < ActiveRecord::Base
  DISPLAY_ORDER = [
      [:priority, %w(high medium low)],
      [:valid_votes_count, :desc, sql: '(votes - suspicious_votes)'],
      [:updated_at, :desc],
      [:id, :desc]
  ]

  def valid_votes_count
    votes - suspicious_votes
  end

  include OrderQuery
  order_query :display_order, DISPLAY_ORDER
  order_query :id_order_asc, [[:id, :asc]]
end

def create_issue(attr = {})
  Issue.create!({priority: 'high', votes: 3, suspicious_votes: 0, updated_at: Time.now}.merge(attr))
end

describe 'OrderQuery.order_query' do

  context 'Issue test model' do
    t        = Time.now
    datasets = [
        [
            ['high', 5, 0, t],
            ['high', 5, 1, t],
            ['high', 5, 1, t - 1.day],
            ['medium', 10, 0, t],
            ['medium', 10, 5, t - 12.hours],
            ['low', 30, 0, t + 1.day]
        ],
        [
            ['high', 5, 0, t],
            ['high', 5, 1, t],
            ['high', 5, 1, t - 1.day],
            ['low', 30, 0, t + 1.day]
        ],
        [
            ['high', 5, 1, t - 1.day],
            ['low', 30, 0, t + 1.day]
        ],
    ]

    datasets.each_with_index do |ds, i|
      it "is ordered correctly (test data #{i})" do
        issues = ds.map do |attr|
          Issue.new(priority: attr[0], votes: attr[1], suspicious_votes: attr[2], updated_at: attr[3])
        end
        issues.reverse_each(&:save!)
        expect(Issue.display_order.to_a).to eq(issues)
        issues.each_slice(2) do |prev, cur|
          cur ||= issues.first
          expect(prev.display_order.next).to eq(cur)
          expect(cur.display_order.previous).to eq(prev)
          expect(cur.display_order.scope.count).to eq(Issue.count)
          expect(cur.display_order.before.count + 1 + cur.display_order.after.count).to eq(cur.display_order.count)

          expect(cur.display_order.before.to_a.reverse + [cur] + cur.display_order.after.to_a).to eq(Issue.display_order.to_a)
        end
      end
    end

    it '#next returns nil when there is only 1 record' do
      p = create_issue.display_order
      expect(p.next).to be_nil
      expect(p.next(true)).to be_nil
    end

    it 'is ordered correctly for order query [[:id, :asc]]' do
      a = create_issue
      b = create_issue
      expect(a.id_order_asc.next).to eq b
      expect(b.id_order_asc.previous).to eq a
      expect([a] + a.id_order_asc.after.to_a).to eq(Issue.id_order_asc.to_a)
      expect(b.id_order_asc.before.reverse.to_a + [b]).to eq(Issue.id_order_asc.to_a)
      expect(Issue.id_order_asc.count).to eq(2)
    end

    it '.order_by_query works on a list of ids' do
      ids = (1..3).map { create_issue.id }
      expect(Issue.order_by_query([[:id, ids]])).to have(ids.length).issues
    end

    it '.order_by_query preserves previous' do
      create_issue(active: true)
      expect(Issue.where(active: false).order_by_query([[:id, :desc]])).to have(0).records
      expect(Issue.where(active: true).order_by_query([[:id, :desc]])).to have(1).record
    end

    it '#relative_order_by_query falls back to scope when order condition is missing self' do
      a = create_issue(priority: 'medium')
      b = create_issue(priority: 'high')
      expect(a.relative_order_by_query(Issue.display_order, [[:priority, ['wontfix', 'askbob']], [:id, :desc]]).next).to eq(b)
    end

    before do
      Issue.delete_all
    end

    before :all do
      ActiveRecord::Schema.define do
        self.verbose = false

        create_table :issues do |t|
          t.column :priority, :string
          t.column :votes, :integer
          t.column :suspicious_votes, :integer
          t.column :announced_at, :datetime
          t.column :updated_at, :datetime
          t.column :active, :boolen, null: false, default: true
        end
      end

      Issue.reset_column_information
    end
  end

  context 'Post test model' do
    it '#next works' do
      p1 = create_post(pinned: true)
      o1 = p1.order_list
      expect(o1.next).to be_nil
      expect(o1.next(true)).to be_nil
      p2 = create_post(pinned: false)
      o2 = p2.order_list
      expect(o1.next(false)).to eq(p2)
      expect(o2.next(false)).to be_nil
      expect(o2.next(true)).to eq(p1)
    end

    before do
      Post.delete_all
    end
    before :all do
      ActiveRecord::Schema.define do
        self.verbose = false
        create_table :posts do |t|
          t.boolean :pinned
          t.datetime :published_at
        end
      end
    end
  end
end
