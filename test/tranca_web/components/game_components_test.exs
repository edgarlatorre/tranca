defmodule TrancaWeb.GameComponentsTest do
  @moduledoc false
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Tranca.Game.Card
  alias TrancaWeb.GameComponents

  @base %{
    deck_count: 74,
    discard_top: nil,
    discard_count: 0,
    morto_count: 11,
    on_draw_deck: "draw_deck",
    on_draw_discard: "draw_discard"
  }

  defp render_table(assigns) do
    html = render_component(&GameComponents.game_table/1, Map.merge(@base, assigns))
    LazyHTML.from_fragment(html)
  end

  defp count(doc, selector), do: doc |> LazyHTML.query(selector) |> Enum.count()
  defp text(doc, selector), do: doc |> LazyHTML.query(selector) |> LazyHTML.text()

  describe "game_table/1" do
    test "shows the deck as a face-down card with its count" do
      doc = render_table(%{deck_count: 74})

      assert count(doc, "#draw-deck[phx-click='draw_deck'] .card-back") == 1
      assert text(doc, "#draw-deck") =~ "74"
    end

    test "shows an empty slot when the deck is empty" do
      doc = render_table(%{deck_count: 0})

      assert count(doc, "#draw-deck .card-back") == 0
      assert count(doc, "#draw-deck .border-dashed") == 1
    end

    test "shows the top discard card face up" do
      doc =
        render_table(%{discard_top: Card.new("q", :queen, :hearts, 10), discard_count: 3})

      assert count(doc, "#draw-discard[phx-click='draw_discard'] #discard-top") == 1
      assert text(doc, "#discard-top") =~ "Q"
      assert text(doc, "#discard-top") =~ "♥"
      assert count(doc, "#draw-discard[disabled]") == 0
    end

    test "shows an empty slot when the discard pile is empty" do
      doc = render_table(%{})

      assert count(doc, "#discard-top") == 0
      assert count(doc, "#draw-discard .border-dashed") == 1
    end

    test "disables a blocked discard pile" do
      doc =
        render_table(%{
          discard_top: Card.new("b3", :three, :spades, 5),
          discard_count: 1,
          discard_disabled: true
        })

      assert count(doc, "#draw-discard[disabled]") == 1
      assert count(doc, "#discard-top.opacity-50") == 1
    end

    test "shows the morto face down with its count until taken" do
      doc = render_table(%{morto_count: 11})

      assert count(doc, "#morto-indicator .card-back") == 1
      assert text(doc, "#morto-indicator") =~ "11"
    end

    test "shows which team took the morto" do
      doc = render_table(%{morto_count: 0, morto_taken_by: :b})

      assert count(doc, "#morto-indicator .card-back") == 0
      assert text(doc, "#morto-indicator") =~ "Taken"
      assert text(doc, "#morto-indicator") =~ "Team B"
    end
  end
end
