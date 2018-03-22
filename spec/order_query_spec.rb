# frozen_string_literal: true

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
              %i[published_at desc],
              %i[id desc]
end

def create_post(attr = {})
  Post.create!({ pinned: false, published_at: Time.now }.merge(attr))
end

# Advanced model
class Issue < ActiveRecord::Base
  DISPLAY_ORDER = [
    [:pinned, [true, false]],
    [:priority, %w[high medium low]],
    [:valid_votes_count, :desc, sql: '(votes - suspicious_votes)'],
    %i[updated_at desc],
    %i[id desc]
  ].freeze

  def valid_votes_count
    votes - suspicious_votes
  end

  include OrderQuery
  order_query :display_order, DISPLAY_ORDER
  order_query :id_order_asc, [%i[id asc]]
end

def create_issue(attr = {})
  Issue.create!(
    { priority: 'high', votes: 3, suspicious_votes: 0, updated_at: Time.now }
      .merge(attr)
  )
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

RSpec.describe 'OrderQuery' do
  context 'Column' do
    it 'fails with ArgumentError if invalid vals_and_or_dir is passed' do
      expect do
        OrderQuery::Column.new(Post.all, :pinned, :desc, :extra)
      end.to raise_error(ArgumentError)
    end
  end

  context 'Point' do
    context '#value' do
      it 'fails if nil on non-nullable column' do
        post = OpenStruct.new
        post.pinned = nil
        space = Post.seek([:pinned])
        expect do
          OrderQuery::Point.new(post, space)
                           .value(space.columns.find { |c| c.name == :pinned })
        end.to raise_error(OrderQuery::Errors::NonNullableColumnIsNullError)
      end
    end
  end

  [false, true].each do |wrap_top_level_or|
    context "(wtlo: #{wrap_top_level_or})" do
      wrap_top_level_or wrap_top_level_or

      context 'Issue test model' do
        datasets = lambda {
          t = Time.now
          [
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
            ]
          ]
        }.call

        datasets.each_with_index do |ds, i|
          it "is ordered correctly (test data #{i})" do
            issues = ds.map do |attr|
              Issue.new(priority: attr[0], votes: attr[1],
                        suspicious_votes: attr[2], updated_at: attr[3],
                        pinned: attr[4] || false)
            end
            issues.shuffle.reverse_each(&:save!)
            expect(Issue.display_order.to_a).to eq(issues)
            expect(Issue.display_order_reverse.to_a).to eq(issues.reverse)
            issues.zip(issues.rotate).each_with_index do |(cur, nxt), j|
              expect(cur.display_order.position).to eq(j + 1)
              expect(cur.display_order.next).to eq(nxt)
              expect(Issue.display_order_at(cur).next).to eq nxt
              expect(cur.display_order.space.count).to eq(Issue.count)
              expect(
                cur.display_order.before.count + 1 +
                  cur.display_order.after.count
              ).to eq(nxt.display_order.count)
              expect(nxt.display_order.previous).to eq(cur)
              expect(
                nxt.display_order.before.to_a.reverse + [nxt] +
                  nxt.display_order.after.to_a
              ).to eq(Issue.display_order.to_a)
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
          expect(b.id_order_asc.before.reverse.to_a + [b]).to(
            eq Issue.id_order_asc.to_a
          )
          expect(Issue.id_order_asc.count).to eq(2)
        end

        it '.seek works on a list of ids' do
          ids = Array.new(3) { create_issue.id }
          expect(Issue.seek([[:id, ids]]).count).to eq ids.length
          expect(Issue.seek([:id, ids]).count).to eq ids.length
          expect(Issue.seek([:id, ids]).scope.pluck(:id)).to eq ids
          expect(Issue.seek([:id, ids]).scope_reverse.pluck(:id)).to(
            eq(ids.reverse)
          )
        end

        context 'partitioned on a boolean flag' do
          before do
            create_issue(active: true)
            create_issue(active: false)
            create_issue(active: true)
          end

          let!(:order) { [%i[id desc]] }
          let!(:active) { Issue.where(active: true).seek(order) }
          let!(:inactive) { Issue.where(active: false).seek(order) }

          it '.seek preserves scope' do
            expect(inactive.count).to eq 1
            expect(inactive.scope.count).to eq 1
            expect(inactive.scope_reverse.count).to eq 1
            expect(active.count).to eq 2
            expect(active.scope.count).to eq 2
            expect(active.scope_reverse.count).to eq 2
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
          expect(
            a.seek(
              Issue.display_order,
              [[:priority, %w[wontfix askbob]], %i[id desc]]
            ).next
          ).to eq(b)
        end

        context 'nil in string enum' do
          display = ->(issue) { "##{issue.id}-#{issue.priority || 'NULL'}" }
          priorities = [nil, 'low', 'medium', 'high']
          let!(:issues) do
            priorities.flat_map do |p|
              [create_issue(priority: p), create_issue(priority: p)]
            end
          end
          priorities.permutation do |perm|
            it "works for #{perm} (desc)" do
              expect_order(
                Issue.seek([:priority, perm]),
                issues.sort_by { |x| [perm.index(x.priority), x.id] },
                &display
              )
            end
            it "works for #{perm} (asc)" do
              expect_order(
                Issue.seek([:priority, perm, :asc]),
                issues.sort_by { |x| [perm.index(x.priority), -x.id] }.reverse,
                &display
              )
            end
          end
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
            expect(OrderQuery::Column.new(Post, :id, :desc).inspect)
              .to eq '(id unique desc)'
            expect(
              OrderQuery::Column.new(Post, :virtual, :desc, sql: 'SIN(id)')
                  .inspect
            ).to eq '(virtual SIN(id) desc)'
          end

          let(:space) do
            OrderQuery::Space.new(Post, [[:pinned, [true, false]]])
          end

          it 'Point' do
            post = create_post
            point = OrderQuery::Point.new(post, space)
            # rubocop:disable Metrics/LineLength
            expect(point.inspect).to eq %(#<OrderQuery::Point @record=#<Post id: #{post.id}, title: nil, pinned: false, published_at: #{post.attribute_for_inspect(:published_at)}> @space=#<OrderQuery::Space @columns=[(pinned [true, false] desc), (id unique asc)] @base_scope=Post(id: integer, title: string, pinned: boolean, published_at: datetime)>>)
            # rubocop:enable Metrics/LineLength
          end

          it 'Space' do
            # rubocop:disable Metrics/LineLength
            expect(space.inspect).to eq '#<OrderQuery::Space @columns=[(pinned [true, false] desc), (id unique asc)] @base_scope=Post(id: integer, title: string, pinned: boolean, published_at: datetime)>'
            # rubocop:enable Metrics/LineLength
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
            expect(Post.seek([:pinned, [true, false]]).scope.to_sql).to(
              match(/ORDER BY .posts.\..pinned. DESC/)
            )
          end
          it 'enum asc' do
            expect(
              Post.seek([:pinned, [false, true], :asc]).scope.pluck(:pinned)
            ).to eq([true, false])
            expect(
              Post.seek([:pinned, [true, false], :asc]).scope.pluck(:pinned)
            ).to eq([false, true])
          end
          it 'enum desc' do
            expect(
              Post.seek([:pinned, [false, true], :desc]).scope.pluck(:pinned)
            ).to eq([false, true])
            expect(
              Post.seek([:pinned, [true, false], :desc]).scope.pluck(:pinned)
            ).to eq([true, false])
          end
        end

        context 'nil in boolean enum' do
          display = ->(post) { "##{post.id}-#{post.pinned || 'NULL'}" }
          states = [nil, false, true]
          let!(:posts) do
            states.flat_map do |state|
              [create_post(pinned: state), create_post(pinned: state)]
            end
          end
          states.permutation do |perm|
            it "works for #{perm} (desc)" do
              expect_order(
                Post.seek([:pinned, perm]),
                posts.sort_by { |x| [perm.index(x.pinned), x.id] },
                &display
              )
            end
            it "works for #{perm} (asc)" do
              expect_order(
                Post.seek([:pinned, perm, :asc]),
                posts.sort_by { |x| [-perm.index(x.pinned), x.id] },
                &display
              )
            end
          end
        end

        context 'nil published_at' do
          display = ->(post) { post.title }

          let! :null_1 do
            Post.create!(title: 'null_1', published_at: nil).reload
          end
          let! :null_2 do
            Post.create!(title: 'null_2', published_at: nil).reload
          end
          let! :older do
            Post.create!(title: 'older', published_at: Time.now + 1.hour)
          end
          let! :newer do
            Post.create!(title: 'newer', published_at: Time.now - 1.hour)
          end

          it 'orders nulls first (desc)' do
            space = Post.seek([:published_at, :desc, nulls: :first])
            expect_order space, [null_1, null_2, older, newer], &display
          end

          it 'orders nulls first (asc)' do
            space = Post.seek([:published_at, :asc, nulls: :first])
            expect_order space, [null_1, null_2, newer, older], &display
          end

          it 'orders nulls last (desc)' do
            space = Post.seek([:published_at, :desc, nulls: :last])
            expect_order space, [older, newer, null_1, null_2], &display
          end

          it 'orders nulls last (asc)' do
            space = Post.seek([:published_at, :asc, nulls: :last])
            expect_order space, [newer, older, null_1, null_2], &display
          end
        end

        context 'after/before no strict' do
          context 'by middle attribute in search order' do
            let! :base do
              Post.create! pinned: true, published_at: Time.now
            end
            let! :older do
              Post.create! pinned: true, published_at: Time.now + 1.hour
            end
            let! :newer do
              Post.create! pinned: true, published_at: Time.now - 1.hour
            end

            it 'includes first element' do
              point = Post.order_list_at(base)

              expect(point.after.count).to eq 1
              expect(point.after.to_a).to eq [newer]

              expect(point.after(false).count).to eq 2
              expect(point.after(false).to_a).to eq [base, newer]
              expect(point.before(false).to_a).to eq [base, older]
            end
          end

          context 'by last attribute in search order' do
            let!(:base) do
              Post.create! pinned: true,
                           published_at: Time.new(2016, 5, 1, 5, 4, 3),
                           id: 6
            end
            let!(:previous) do
              Post.create! pinned: true,
                           published_at: Time.new(2016, 5, 1, 5, 4, 3),
                           id: 4
            end
            let!(:next_one) do
              Post.create! pinned: true,
                           published_at: Time.new(2016, 5, 1, 5, 4, 3),
                           id: 9
            end

            it 'includes first element' do
              point = Post.order_list_at(base)

              expect(point.after.count).to eq 1
              expect(point.after.to_a).to eq [previous]

              expect(point.after(false).count).to eq 2
              expect(point.after(false).to_a).to eq [base, previous]
              expect(point.before(false).to_a).to eq [base, next_one]
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
              t.string :title
              t.boolean :pinned
              t.datetime :published_at
            end
          end
          Post.reset_column_information
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
        after_scope = User.create!(updated_at: Date.parse('2014-09-06'))
                          .seek([%i[updated_at desc], %i[id desc]]).after
        expect(after_scope.to_sql).to include('<=')
      end
    end

    context 'wrap top-level OR off' do
      wrap_top_level_or false
      it 'does not wrap top-level OR' do
        after_scope = User.create!(updated_at: Date.parse('2014-09-06'))
                          .seek([%i[updated_at desc], %i[id desc]]).after
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
      User.reset_column_information
    end

    after :all do
      ActiveRecord::Migration.drop_table :users
    end
  end
end
