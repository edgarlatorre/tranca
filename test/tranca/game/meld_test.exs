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

    test "returns false when wildcards exceed natural cards" do
      meld =
        Meld.new([
          Card.new("1", :seven, :hearts, 5),
          Card.new("2", :two, :diamonds, 20),
          Card.new("3", :joker, nil, 50)
        ])

      refute Meld.valid?(meld)
    end

    test "returns true when wildcards equal natural cards" do
      meld =
        Meld.new([
          Card.new("1", :seven, :hearts, 5),
          Card.new("2", :seven, :diamonds, 5),
          Card.new("3", :two, :spades, 20),
          Card.new("4", :joker, nil, 50)
        ])

      assert Meld.valid?(meld)
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

  describe "points/1" do
    test "sums card values in the meld" do
      meld =
        Meld.new([
          Card.new("1", :ace, :hearts, 20),
          Card.new("2", :ace, :diamonds, 20),
          Card.new("3", :two, :spades, 20)
        ])

      assert Meld.points(meld) == 60
    end
  end

  describe "canastra classification" do
    test "classifies seven natural cards as canastra limpa" do
      cards =
        for {suit, i} <-
              Enum.with_index([:hearts, :diamonds, :spades, :clubs, :hearts, :diamonds, :spades]) do
          Card.new("limpa-#{i}", :seven, suit, 5)
        end

      meld = Meld.new(cards)

      assert meld.type == :limpa
      assert Meld.canastra?(meld)
      assert Meld.valid?(meld)
    end

    test "classifies seven cards with a wildcard as canastra suja" do
      naturals =
        for {suit, i} <-
              Enum.with_index([:hearts, :diamonds, :spades, :clubs, :hearts, :diamonds]) do
          Card.new("suja-nat-#{i}", :seven, suit, 5)
        end

      wildcard = Card.new("suja-wild", :two, :spades, 20)
      meld = Meld.new(naturals ++ [wildcard])

      assert meld.type == :suja
      assert Meld.canastra?(meld)
      assert Meld.valid?(meld)
    end

    test "classifies six natural cards as normal" do
      cards =
        for {suit, i} <-
              Enum.with_index([:hearts, :diamonds, :spades, :clubs, :hearts, :diamonds]) do
          Card.new("normal-#{i}", :seven, suit, 5)
        end

      meld = Meld.new(cards)

      assert meld.type == :normal
      refute Meld.canastra?(meld)
      assert Meld.valid?(meld)
    end

    test "does not classify invalid seven-card melds as canastra" do
      cards = [
        Card.new("1", :seven, :hearts, 5),
        Card.new("2", :seven, :diamonds, 5),
        Card.new("3", :seven, :spades, 5),
        Card.new("4", :seven, :clubs, 5),
        Card.new("5", :eight, :hearts, 5),
        Card.new("6", :eight, :diamonds, 5),
        Card.new("7", :eight, :spades, 5)
      ]

      meld = Meld.new(cards)

      assert meld.type == :normal
      refute Meld.canastra?(meld)
      refute Meld.valid?(meld)
    end
  end
end
