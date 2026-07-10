defmodule Tranca.Game.CardTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Tranca.Game.Card

  describe "deck/0" do
    test "returns 108 cards" do
      assert length(Card.deck()) == 108
    end

    test "contains two copies of each standard card" do
      deck = Card.deck()

      for rank <- ~w(ace two three four five six seven eight nine ten jack queen king)a,
          suit <- [:spades, :hearts, :diamonds, :clubs] do
        matching = Enum.filter(deck, &(&1.rank == rank and &1.suit == suit))
        assert length(matching) == 2
      end
    end

    test "contains four jokers" do
      jokers = Enum.filter(Card.deck(), &(&1.rank == :joker))
      assert length(jokers) == 4
    end

    test "every card has a unique id" do
      ids = Enum.map(Card.deck(), & &1.id)
      assert length(ids) == length(Enum.uniq(ids))
    end
  end

  describe "new/4" do
    test "creates a card with the correct properties" do
      card = Card.new("1", :ace, :spades, 10)

      assert card.id == "1"
      assert card.rank == :ace
      assert card.suit == :spades
      assert card.value == 10
      refute card.wildcard
    end

    test "marks twos and jokers as wildcards" do
      assert Card.new("1", :two, :hearts, 20).wildcard
      assert Card.new("1", :joker, nil, 50).wildcard
      refute Card.new("1", :ace, :spades, 10).wildcard
    end
  end

  describe "wildcard?/1" do
    test "returns true for wildcards" do
      assert Card.wildcard?(Card.new("1", :two, :hearts, 20))
      assert Card.wildcard?(Card.new("1", :joker, nil, 50))
    end

    test "returns false for non-wildcards" do
      refute Card.wildcard?(Card.new("1", :ace, :spades, 10))
      refute Card.wildcard?(Card.new("1", :three, :clubs, 5))
    end
  end

  describe "three?/1" do
    test "returns true only for threes" do
      assert Card.three?(Card.new("1", :three, :hearts, 5))
      refute Card.three?(Card.new("1", :four, :hearts, 5))
    end
  end

  describe "color/1" do
    test "returns red for hearts and diamonds" do
      assert Card.color(Card.new("1", :ace, :hearts, 10)) == :red
      assert Card.color(Card.new("1", :ace, :diamonds, 10)) == :red
    end

    test "returns black for spades and clubs" do
      assert Card.color(Card.new("1", :ace, :spades, 10)) == :black
      assert Card.color(Card.new("1", :ace, :clubs, 10)) == :black
    end

    test "returns nil for jokers" do
      assert Card.color(Card.new("1", :joker, nil, 50)) == nil
    end
  end

  describe "black_three?/1" do
    test "returns true only for black threes" do
      assert Card.black_three?(Card.new("1", :three, :spades, 5))
      assert Card.black_three?(Card.new("1", :three, :clubs, 5))
      refute Card.black_three?(Card.new("1", :three, :hearts, 5))
      refute Card.black_three?(Card.new("1", :four, :spades, 5))
    end
  end

  describe "red_three?/1" do
    test "returns true only for red threes" do
      assert Card.red_three?(Card.new("1", :three, :hearts, 5))
      assert Card.red_three?(Card.new("1", :three, :diamonds, 5))
      refute Card.red_three?(Card.new("1", :three, :spades, 5))
      refute Card.red_three?(Card.new("1", :four, :hearts, 5))
    end
  end
end
