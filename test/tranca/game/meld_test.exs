defmodule Tranca.Game.MeldTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Tranca.Game.Card
  alias Tranca.Game.Meld

  describe "valid?/1" do
    test "returns true for three natural cards of the same rank" do
      meld =
        Meld.new([
          Card.new("1", :seven, :hearts, 5),
          Card.new("2", :seven, :diamonds, 5),
          Card.new("3", :seven, :spades, 5)
        ])

      assert Meld.valid?(meld)
    end

    test "returns true for a meld with wildcards" do
      meld =
        Meld.new([
          Card.new("1", :seven, :hearts, 5),
          Card.new("2", :seven, :diamonds, 5),
          Card.new("3", :two, :spades, 20)
        ])

      assert Meld.valid?(meld)
    end

    test "returns false for fewer than three cards" do
      meld =
        Meld.new([
          Card.new("1", :seven, :hearts, 5),
          Card.new("2", :seven, :diamonds, 5)
        ])

      refute Meld.valid?(meld)
    end

    test "returns false for mixed ranks" do
      meld =
        Meld.new([
          Card.new("1", :seven, :hearts, 5),
          Card.new("2", :seven, :diamonds, 5),
          Card.new("3", :eight, :spades, 5)
        ])

      refute Meld.valid?(meld)
    end

    test "returns false for only wildcards" do
      meld =
        Meld.new([
          Card.new("1", :two, :hearts, 20),
          Card.new("2", :joker, nil, 50),
          Card.new("3", :two, :spades, 20)
        ])

      refute Meld.valid?(meld)
    end
  end

  describe "rank/1" do
    test "returns the natural rank of the meld" do
      meld =
        Meld.new([
          Card.new("1", :seven, :hearts, 5),
          Card.new("2", :seven, :diamonds, 5),
          Card.new("3", :two, :spades, 20)
        ])

      assert Meld.rank(meld) == :seven
    end

    test "returns nil for a meld with only wildcards" do
      meld =
        Meld.new([
          Card.new("1", :two, :hearts, 20),
          Card.new("2", :joker, nil, 50)
        ])

      assert Meld.rank(meld) == nil
    end
  end

  describe "natural_cards/1 and wildcards/1" do
    test "split cards correctly" do
      natural = Card.new("1", :seven, :hearts, 5)
      wildcard = Card.new("2", :two, :spades, 20)
      meld = Meld.new([natural, wildcard])

      assert Meld.natural_cards(meld) == [natural]
      assert Meld.wildcards(meld) == [wildcard]
    end
  end
end
