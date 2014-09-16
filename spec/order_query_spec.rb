require 'spec_helper'

# Bare model
class User < ActiveRecord::Base
  include OrderQuery
end

# Simple model
class Post < ActiveRecord::Base
  include OrderQuery
  order_query :order_list,
              [:pinned, [true, false]],
              [:published_at, :desc],
              [:id, :desc]
end

def create_post(attr = {})
  Post.create!({pinned: false, published_at: Time.now}.merge(attr))
end

# Advanced model
class Issue < ActiveRecord::Base
  DISPLAY_ORDER = [
      [:pinned, [true, false]],
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

def wrap_top_level_or(value)
  conf = ::OrderQuery
  around do |ex|
    was = conf.wrap_top_level_or
    begin
      conf.wrap_top_level_or = value
      ex.run
    ensure
      conf.wrap_top_level_or = was
    end
  end
end

describe 'OrderQuery' do

  [false, true].each do |wrap_top_level_or|
    context "(wtlo: #{wrap_top_level_or})" do
      wrap_top_level_or wrap_top_level_or

      context 'Issue test model' do
        t        = Time.now
        datasets = [
            [
                ['high', 5, 0, t, true],
                ['high', 5, 1, t, true],
                ['high', 5, 0, t],
                ['high', 5, 0, t - 1.day],
                ['high', 5, 1, t],
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
              Issue.new(priority: attr[0], votes: attr[1], suspicious_votes: attr[2], updated_at: attr[3], pinned: attr[4] || false)
            end
            issues.shuffle.reverse_each(&:save!)
            expect(Issue.display_order.to_a).to eq(issues)
            issues.zip(issues.rotate).each_with_index do |(cur, nxt), i|
              expect(cur.display_order.position).to eq(i + 1)
              expect(cur.display_order.next).to eq(nxt)
              expect(cur.display_order.space.count).to eq(Issue.count)
              expect(cur.display_order.before.count + 1 + cur.display_order.after.count).to eq(nxt.display_order.count)
              expect(nxt.display_order.previous).to eq(cur)
              expect(nxt.display_order.before.to_a.reverse + [nxt] + nxt.display_order.after.to_a).to eq(Issue.display_order.to_a)
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

        it '.seek works on a list of ids' do
          ids = 3.times.map { create_issue.id }
          expect(Issue.seek([[:id, ids]]).scope.count).to eq ids.length
          expect(Issue.seek([:id, ids]).scope.count).to eq ids.length
        end

        context 'partitioned on a boolean flag' do
          before do
            create_issue(active: true)
            create_issue(active: false)
            create_issue(active: true)
          end

          let!(:order) { [[:id, :desc]] }
          let!(:active) { Issue.where(active: true).seek(order) }
          let!(:inactive) { Issue.where(active: false).seek(order) }

          it '.seek preserves scope' do
            expect(inactive.scope.count).to eq 1
            expect(inactive.count).to eq 1
            expect(active.count).to eq 2
            expect(active.scope.count).to eq 2
          end

          it 'gives a valid result if at argument is outside of the space' do
            expect(inactive.at(active.first).next).to_not be_active
            expect(inactive.at(active.last).next).to_not be_active
            expect(active.at(inactive.first).next).to be_active
            expect(active.at(inactive.last).next).to be_active
          end

          it 'next/previous(false)' do
            expect(active.at(active.first).next(false)).to_not be_nil
            expect(active.at(active.last).next(false)).to be_nil
            expect(inactive.at(inactive.first).previous(false)).to be_nil
            # there is only one, so previous(last) is also nil
            expect(inactive.at(inactive.last).previous(false)).to be_nil
          end

          it 'previous(true) with only 1 record' do
            expect(inactive.at(inactive.last).previous(true)).to be_nil
          end
        end

        it '#seek falls back to scope when order column is missing self' do
          a = create_issue(priority: 'medium')
          b = create_issue(priority: 'high')
          expect(a.seek(Issue.display_order, [[:priority, ['wontfix', 'askbob']], [:id, :desc]]).next).to eq(b)
        end

        before do
          Issue.delete_all
        end

        before :all do
          ActiveRecord::Schema.define do
            self.verbose = false

            create_table :issues do |t|
              t.column :pinned, :boolean, null: false, default: false
              t.column :priority, :string
              t.column :votes, :integer
              t.column :suspicious_votes, :integer
              t.column :announced_at, :datetime
              t.column :updated_at, :datetime
              t.column :active, :boolean, null: false, default: true
            end
          end

          Issue.reset_column_information
        end

        after :all do
          ActiveRecord::Migration.drop_table :issues
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

        context '#inspect' do
          it 'Column' do
            expect(OrderQuery::Column.new([:id, :desc], Post).inspect).to eq '(id unique desc)'
            expect(OrderQuery::Column.new([:virtual, :desc, sql: 'SIN(id)'], Post).inspect).to eq '(virtual SIN(id) desc)'
          end

          let(:space) {
            OrderQuery::Space.new(Post, [[:pinned, [true, false]]])
          }

          it 'Point' do
            post  = create_post
            point = OrderQuery::Point.new(post, space)
            expect(point.inspect).to(
                eq %Q(#<OrderQuery::Point @record=#<Post id: #{post.id}, pinned: false, published_at: #{post.published_at.to_s[0..-7].inspect}> @space=#<OrderQuery::Space @columns=[(pinned [true, false] desc), (id unique asc)] @base_scope=Post(id: integer, pinned: boolean, published_at: datetime)>>)
            )
          end

          it 'Space' do
            expect(space.inspect).to eq '#<OrderQuery::Space @columns=[(pinned [true, false] desc), (id unique asc)] @base_scope=Post(id: integer, pinned: boolean, published_at: datetime)>'
          end
        end


        context 'boolean enum order' do
          before do
            create_post pinned: true
            create_post pinned: false
          end
          after do
            Post.delete_all
          end
          it 'ORDER BY is collapsed' do
            expect(Post.seek([:pinned, [true, false]]).scope.to_sql).to include('ORDER BY "posts"."pinned" DESC')
          end
          it 'enum asc' do
            expect(Post.seek([:pinned, [false, true], :asc]).scope.pluck(:pinned)).to eq([true, false])
            expect(Post.seek([:pinned, [true, false], :asc]).scope.pluck(:pinned)).to eq([false, true])
          end
          it 'enum desc' do
            expect(Post.seek([:pinned, [false, true], :desc]).scope.pluck(:pinned)).to eq([false, true])
            expect(Post.seek([:pinned, [true, false], :desc]).scope.pluck(:pinned)).to eq([true, false])
          end
        end

        xcontext 'nil in enum' do
          states = [nil, false, true]
          let!(:posts) { states.map { |state| create_post(pinned: state) } }
          states.permutation do |p|
            # There is no cross-DB SQL that can be generated to position nil results
            # http://use-the-index-luke.com/sql/sorting-grouping/order-by-asc-desc-nulls-last
            next unless p.first.nil? || p.last.nil?
            # Positioning NULLs first or last can be achieved, but remains on the ToDo / contributions welcome list
            it "nil in enum works for #{p}" do
              expect(Post.seek([:pinned, p]).scope.all.map(&:pinned)).to eq(p)
              expect(Post.seek([:pinned, p, :asc]).scope.all.map(&:pinned)).to eq(p.reverse)
            end
          end
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
        after :all do
          ActiveRecord::Migration.drop_table :posts
        end
      end
    end
  end

  context 'SQL generation' do
    context 'wrap top-level OR on' do
      wrap_top_level_or true
      it 'wraps top-level OR' do
        after_scope = User.create!(updated_at: Date.parse('2014-09-06')).seek([[:updated_at, :desc], [:id, :desc]]).after
        expect(after_scope.to_sql).to include('<=')
      end
    end

    context 'wrap top-level OR off' do
      wrap_top_level_or false
      it 'does not wrap top-level OR' do
        after_scope = User.create!(updated_at: Date.parse('2014-09-06')).seek([[:updated_at, :desc], [:id, :desc]]).after
        expect(after_scope.to_sql).to_not include('<=')
      end
    end

    before do
      User.delete_all
    end

    before :all do
      ActiveRecord::Schema.define do
        self.verbose = false
        create_table :users do |t|
          t.datetime :updated_at, null: false
        end
      end
    end

    after :all do
      ActiveRecord::Migration.drop_table :users
    end
  end
end
