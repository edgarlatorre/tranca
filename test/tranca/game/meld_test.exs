defmodule Tranca.Game.MeldTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Tranca.Game.Card
  alias Tranca.Game.Meld

  describe "valid?/1" do
    test "returns true for three natural cards of the same rank" do
      meld =
        Meld.new([
          Card.new("1", :four, :hearts, 5),
          Card.new("2", :four, :diamonds, 5),
          Card.new("3", :four, :spades, 5)
        ])

      assert Meld.valid?(meld)
    end

    test "returns true for a meld with wildcards" do
      meld =
        Meld.new([
          Card.new("1", :four, :hearts, 5),
          Card.new("2", :four, :diamonds, 5),
          Card.new("3", :two, :spades, 20)
        ])

      assert Meld.valid?(meld)
    end

    test "returns false for fewer than three cards" do
      meld =
        Meld.new([
          Card.new("1", :four, :hearts, 5),
          Card.new("2", :four, :diamonds, 5)
        ])

      refute Meld.valid?(meld)
    end

    test "returns false for mixed ranks" do
      meld =
        Meld.new([
          Card.new("1", :four, :hearts, 5),
          Card.new("2", :four, :diamonds, 5),
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
          Card.new("1", :four, :hearts, 5),
          Card.new("2", :two, :diamonds, 20),
          Card.new("3", :joker, nil, 50)
        ])

      refute Meld.valid?(meld)
    end

    test "returns true when wildcards equal natural cards" do
      meld =
        Meld.new([
          Card.new("1", :four, :hearts, 5),
          Card.new("2", :four, :diamonds, 5),
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
          Card.new("1", :four, :hearts, 5),
          Card.new("2", :four, :diamonds, 5),
          Card.new("3", :two, :spades, 20)
        ])

      assert Meld.rank(meld) == :four
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
      natural = Card.new("1", :four, :hearts, 5)
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
          Card.new("limpa-#{i}", :four, suit, 5)
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
          Card.new("suja-nat-#{i}", :four, suit, 5)
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
          Card.new("normal-#{i}", :four, suit, 5)
        end

      meld = Meld.new(cards)

      assert meld.type == :normal
      refute Meld.canastra?(meld)
      assert Meld.valid?(meld)
    end

    test "does not classify invalid seven-card melds as canastra" do
      cards = [
        Card.new("1", :four, :hearts, 5),
        Card.new("2", :four, :diamonds, 5),
        Card.new("3", :four, :spades, 5),
        Card.new("4", :four, :clubs, 5),
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

  describe "set ranks" do
    defp set_of(rank, wildcards \\ []) do
      naturals =
        for {suit, i} <- Enum.with_index([:hearts, :diamonds, :spades]) do
          Card.new("#{rank}-#{i}", rank, suit, 5)
        end

      Meld.new(naturals ++ wildcards)
    end

    test "allows sets of aces and 4s" do
      assert Meld.validate(set_of(:ace)) == :ok
      assert Meld.validate(set_of(:four)) == :ok
      assert Meld.kind(set_of(:ace)) == :set
    end

    test "allows wildcards in ace and 4 sets" do
      meld =
        Meld.new([
          Card.new("a1", :ace, :hearts, 15),
          Card.new("a2", :ace, :spades, 15),
          Card.new("w", :two, :clubs, 20)
        ])

      assert Meld.validate(meld) == :ok
    end

    test "rejects sets of any other rank with a specific error" do
      for rank <- [:three, :five, :six, :seven, :eight, :nine, :ten, :jack, :queen, :king] do
        assert Meld.validate(set_of(rank)) == {:error, :same_rank_meld_not_allowed}
        assert Meld.kind(set_of(rank)) == nil
        refute Meld.valid?(set_of(rank))
      end
    end

    test "rejects other-rank sets that include wildcards" do
      meld = set_of(:king, [Card.new("j", :joker, nil, 50)])

      assert Meld.validate(meld) == {:error, :same_rank_meld_not_allowed}
    end

    test "returns :invalid_meld for melds that are invalid for other reasons" do
      too_small =
        Meld.new([Card.new("k1", :king, :hearts, 10), Card.new("k2", :king, :spades, 10)])

      too_wild =
        Meld.new([
          Card.new("k1", :king, :hearts, 10),
          Card.new("w1", :two, :clubs, 20),
          Card.new("w2", :joker, nil, 50)
        ])

      assert Meld.validate(too_small) == {:error, :invalid_meld}
      assert Meld.validate(too_wild) == {:error, :invalid_meld}
    end
  end

  describe "sequences" do
    defp c(id, rank, suit), do: Card.new(id, rank, suit, 5)

    test "accepts a same-suit run of natural cards" do
      meld = Meld.new([c("1", :four, :hearts), c("2", :five, :hearts), c("3", :six, :hearts)])

      assert Meld.valid?(meld)
      assert Meld.kind(meld) == :sequence
      assert Meld.rank(meld) == nil
    end

    test "accepts a 2 filling a gap in a sequence" do
      meld = Meld.new([c("4", :four, :hearts), c("6", :six, :hearts), c("w", :two, :clubs)])

      assert Meld.valid?(meld)
      assert Enum.map(meld.cards, & &1.id) == ["4", "w", "6"]
    end

    test "accepts a joker filling a gap in a sequence" do
      meld = Meld.new([c("w", :joker, nil), c("4", :four, :hearts), c("6", :six, :hearts)])

      assert Meld.valid?(meld)
      assert Enum.map(meld.cards, & &1.id) == ["4", "w", "6"]
    end

    test "accepts a wildcard extending the end of a sequence" do
      meld = Meld.new([c("w", :two, :clubs), c("5", :five, :spades), c("6", :six, :spades)])

      assert Meld.valid?(meld)
      assert Enum.map(meld.cards, & &1.id) == ["5", "6", "w"]
    end

    test "extends below when the run already ends at the ace" do
      meld = Meld.new([c("w", :two, :clubs), c("k", :king, :spades), c("a", :ace, :spades)])

      assert Meld.valid?(meld)
      assert Enum.map(meld.cards, & &1.id) == ["w", "k", "a"]
    end

    test "accepts the ace low or high" do
      assert Meld.valid?(
               Meld.new([c("a", :ace, :clubs), c("w", :two, :clubs), c("3", :three, :clubs)])
             )

      assert Meld.valid?(
               Meld.new([c("q", :queen, :clubs), c("k", :king, :clubs), c("a", :ace, :clubs)])
             )
    end

    test "rejects a run that wraps around the ace" do
      refute Meld.valid?(
               Meld.new([c("k", :king, :clubs), c("a", :ace, :clubs), c("3", :three, :clubs)])
             )
    end

    test "rejects mixed suits" do
      refute Meld.valid?(
               Meld.new([c("4", :four, :hearts), c("5", :five, :spades), c("6", :six, :hearts)])
             )
    end

    test "rejects gaps larger than the available wildcards" do
      refute Meld.valid?(
               Meld.new([c("4", :four, :hearts), c("7", :seven, :hearts), c("w", :two, :clubs)])
             )
    end

    test "rejects duplicate ranks" do
      refute Meld.valid?(
               Meld.new([c("1", :four, :hearts), c("2", :four, :hearts), c("5", :five, :hearts)])
             )
    end

    test "rejects more wildcards than natural cards" do
      refute Meld.valid?(
               Meld.new([c("4", :four, :hearts), c("w1", :two, :clubs), c("w2", :joker, nil)])
             )
    end

    test "classifies seven-card sequences as canastras" do
      naturals =
        for {rank, i} <- Enum.with_index([:four, :five, :six, :seven, :eight, :nine, :ten]) do
          c("n#{i}", rank, :diamonds)
        end

      assert Meld.new(naturals).type == :limpa

      suja = naturals |> List.replace_at(3, c("w", :two, :clubs)) |> Meld.new()
      assert Meld.valid?(suja)
      assert suja.type == :suja
    end
  end
end
