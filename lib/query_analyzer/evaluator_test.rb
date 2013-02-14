#! /usr/bin/ruby

require 'test/unit'
require './evaluator'

class EvaluatorTest < Test::Unit::TestCase
  def setup
    @ev = Evaluator.new 'localhost', 27017
    @ns = 'dbname.collname'
  end

  def perform_query(query, expected_suggestions_no)
    begin
      result = @ev.evaluate_query({"query" => query}, @ns)
      assert_equal( expected_suggestions_no, result.size,
                   'Wrong number of evaluation results')
      return result
    rescue => ex
      assert false, 'Exception raised: ' + ex.to_s
    end
  end

  # The purpose of the following tests is to check if Evaluator
  # is able to decompose and evaluate each query

  def test_subdocument_comparison
    perform_query(
      {
        'field1' => {
          'sub1' => 3,
          'sub2' => 'string_val',
        },
        'field2' => 99,
      },
      0
    )
  end

  def test_in
    perform_query(
      {
        'field1' => {'$gt' => 20 },
        'field2' => {'$in' => [1]*10000},
      },
      1
    )
  end

  def test_nin
    perform_query(
      {
        'field1' => {'$nin' => [1,2,3]},
      },
      1
    )
  end

  def test_ne
    perform_query(
      {
        'field1' => {'$ne' => 'orange' }
      },
      1
    )
  end

  def test_comparison_operators
    perform_query(
      {
        'field1' => {'$lt' => 1},
        'field2' => {'$lte' => 2},
        'field3' => {'$gt' => 3},
        'field4' => {'$gte' => 4},
      },
      0
    )
  end

  def test_all
    perform_query(
      {
        'field1' => {'$all' => [1,2,3,4]},
      },
      1
    )
  end

  def test_or_and
    for op in ['$or', '$and'] do
      perform_query(
        {
          op => [
            'field1' => 2.15,
            'field2' => 'red',
            'field3' => { '$ne' => 15 },
            'field4' => { 'sub1' => 1, 'sub2' => 2 },
          ]
        },
        1 #one warning for using $ne
      )
    end
  end

  def test_not
    perform_query(
      {
        'field1' => { '$not' => { '$in' => [1,2,3]*10000 } }
      },
      2 # one for $not, one for $in with a big array
    )
  end

  def test_nor
    perform_query(
      {
        '$nor' => [
          'field1' => 2.15,
          'field2' => 'red',
          'field3' => { '$ne' => 15 },
          'field4' => { 'sub1' => 1, 'sub2' => 2 },
        ]
      },
      2 # one for $nor, one for $ne
    )
  end

  def test_regex
    perform_query(
      {
        "A" => { "$regex" => "^acme.*corp", "$options" => 'i'},
      },
      1 # case insensitive
    )

    perform_query(
      {
        "A" => { "$regex" => "acme.*corp" },
      },
      1 # no ^ anchor
    )

    perform_query(
      {
        "A" => { "$regex" => "^acme.*corp.*$" },
      },
      1 # '.*$' at the end
    )

    perform_query(
      {
        "A" => { "$regex" => "acme.*corp.*", "$options" => 'i'},
      },
      3 # all three inefficient patterns in one query
    )
  end

  def test_where
    perform_query(
      {
        '$where' => 'this.credits == this.debits'
      },
      1
    )
  end

  # Make sure that evaluator raises exceptions when it encounters
  # unknow operators.

  def test_unknown_operator
    query = {
      'A' => {'$brighter_than'=> '#AAFFCC'}
    }
    assert_raise RuntimeError do
      @ev.evaluate_query({"query" => query}, @ns)
    end
  end
end