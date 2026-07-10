defmodule Tranca.Game do
  @moduledoc """
  The pure data model and rule engine for Tranca com morto.

  A `Tranca.Game` struct holds the complete state of a match. All game
  actions return a new struct (or an error tuple), keeping the engine
  free of side effects and easy to test.
  """

  alias Tranca.Game.Card
  alias Tranca.Game.Meld
  alias Tranca.Game.Player
  alias Tranca.Game.Team

  @type status :: :waiting | :playing | :finished
  @type player_count :: 2 | 4

  @type t :: %__MODULE__{
          id: String.t(),
          status: status(),
          player_count: player_count(),
          players: [Player.t()],
          teams: %{a: Team.t(), b: Team.t()},
          deck: [Card.t()],
          morto: [Card.t()],
          discard_pile: [Card.t()],
          turn: integer(),
          drawn_this_turn: boolean(),
          round: integer(),
          winner: Team.id() | nil
        }

  defstruct [
    :id,
    :status,
    :player_count,
    :players,
    :teams,
    :deck,
    :morto,
    :discard_pile,
    :turn,
    :drawn_this_turn,
    :round,
    :winner
  ]

  @doc """
  Creates a new game in the `:waiting` state.

  `player_count` must be 2 or 4. The game is initialized with empty
  players, teams, and piles. Cards are not dealt until the game starts.
  """
  @spec new(String.t(), player_count()) :: t()
  def new(id, player_count) when player_count in [2, 4] do
    %__MODULE__{
      id: id,
      status: :waiting,
      player_count: player_count,
      players: [],
      teams: %{a: Team.new(:a), b: Team.new(:b)},
      deck: [],
      morto: [],
      discard_pile: [],
      turn: 0,
      drawn_this_turn: false,
      round: 1,
      winner: nil
    }
  end

  @doc """
  Adds a player to the game while it is in the `:waiting` state.

  The seat must be unique and within the valid range for the game's
  player count. The team must be `:a` or `:b`.
  """
  @spec add_player(t(), String.t(), String.t() | nil, Player.team()) ::
          {:ok, t()} | {:error, atom()}
  def add_player(%__MODULE__{status: :waiting} = game, user_id, seat, team)
      when is_integer(seat) and seat >= 0 and seat < game.player_count and
             team in [:a, :b] do
    if Enum.any?(game.players, &(&1.seat == seat)) do
      {:error, :seat_taken}
    else
      player = Player.new("player-#{seat}", user_id, seat, team)

      teams =
        Map.update!(game.teams, team, fn team_struct ->
          Team.add_player(team_struct, player.id)
        end)

      {:ok, %{game | players: game.players ++ [player], teams: teams}}
    end
  end

  def add_player(%__MODULE__{status: :waiting}, _user_id, _seat, _team),
    do: {:error, :invalid_seat_or_team}

  def add_player(%__MODULE__{}, _user_id, _seat, _team),
    do: {:error, :game_already_started}

  @doc """
  Starts the game, dealing cards and creating the morto and discard pile.

  Requires the correct number of players and a seed for deterministic
  shuffling. Returns an error if the game is not in the `:waiting` state
  or does not have the expected number of players.
  """
  @spec start(t(), integer()) :: {:ok, t()} | {:error, atom()}
  def start(%__MODULE__{status: :waiting} = game, seed)
      when is_integer(seed) and length(game.players) == game.player_count do
    shuffled = Card.deck() |> Card.shuffle(seed)

    {players, remaining} = deal_players(shuffled, game.players, [])
    {morto, [discard_top | deck]} = Enum.split(remaining, 11)

    {:ok,
     %{
       game
       | status: :playing,
         players: players,
         morto: morto,
         deck: deck,
         discard_pile: [discard_top],
         turn: 0,
         drawn_this_turn: false
     }}
  end

  def start(%__MODULE__{status: :waiting}, _seed),
    do: {:error, :not_enough_players}

  def start(%__MODULE__{}, _seed),
    do: {:error, :game_already_started}

  @doc """
  Returns the player whose turn it currently is.
  """
  @spec current_player(t()) :: Player.t() | nil
  def current_player(%__MODULE__{players: players, turn: turn}) do
    Enum.at(players, turn)
  end

  @doc """
  Marks the game as finished and records the winning team.
  """
  @spec finish(t(), Team.id()) :: t()
  def finish(%__MODULE__{status: :playing} = game, winner) when winner in [:a, :b] do
    %{game | status: :finished, winner: winner}
  end

  @doc """
  Applies a -100 point penalty for each black 3 remaining in players' hands.

  Penalties are applied per team.
  """
  @spec apply_black_three_penalties(t()) :: t()
  def apply_black_three_penalties(%__MODULE__{} = game) do
    teams =
      Map.new(game.teams, fn {team_id, team} ->
        penalty = black_three_penalty(game, team_id)
        {team_id, %{team | score: team.score + penalty}}
      end)

    %{game | teams: teams}
  end

  @doc """
  Awards a +100 point bonus for each red 3 that has been melded to the table.

  Bonuses are applied per team.
  """
  @spec apply_red_three_bonus(t()) :: t()
  def apply_red_three_bonus(%__MODULE__{} = game) do
    teams =
      Map.new(game.teams, fn {team_id, team} ->
        bonus = red_three_bonus(team)
        {team_id, %{team | score: team.score + bonus}}
      end)

    %{game | teams: teams}
  end

  @doc """
  Gives the morto cards to the appropriate player on the going-out player's team.

  In a 2-player game the morto goes to the same player. In a 4-player game it
  goes to the teammate (partner). Returns an error if the morto is empty.
  """
  @spec pickup_morto(t(), String.t()) :: {:ok, t()} | {:error, atom()}
  def pickup_morto(%__MODULE__{morto: []}, _player_id), do: {:error, :empty_morto}

  def pickup_morto(%__MODULE__{} = game, player_id) do
    current_player = Enum.find(game.players, &(&1.id == player_id))

    if current_player do
      target_id = morto_target_id(game, current_player)

      game =
        game
        |> give_cards_to_player(target_id, game.morto)
        |> Map.put(:morto, [])

      {:ok, game}
    else
      {:error, :player_not_found}
    end
  end

  @doc """
  Draws the top card from the deck for the given player.
  """
  @spec draw_from_deck(t(), String.t()) :: {:ok, t()} | {:error, atom()}
  def draw_from_deck(%__MODULE__{status: :playing} = game, player_id) do
    with :ok <- validate_turn(game, player_id),
         :ok <- validate_not_drawn(game),
         {card, deck} <- List.pop_at(game.deck, 0) do
      if card do
        game = give_card_to_player(game, player_id, card)
        {:ok, %{game | deck: deck, drawn_this_turn: true}}
      else
        {:error, :empty_deck}
      end
    end
  end

  def draw_from_deck(%__MODULE__{}, _player_id),
    do: {:error, :game_not_playing}

  @doc """
  Draws the top card from the discard pile for the given player.

  Drawing is blocked when the top card is a black three.
  """
  @spec draw_from_discard(t(), String.t()) :: {:ok, t()} | {:error, atom()}
  def draw_from_discard(%__MODULE__{status: :playing} = game, player_id) do
    with :ok <- validate_turn(game, player_id),
         :ok <- validate_not_drawn(game),
         :ok <- validate_discard_not_blocked(game),
         {card, discard_pile} <- List.pop_at(game.discard_pile, 0) do
      if card do
        game = give_card_to_player(game, player_id, card)
        {:ok, %{game | discard_pile: discard_pile, drawn_this_turn: true}}
      else
        {:error, :empty_discard_pile}
      end
    end
  end

  def draw_from_discard(%__MODULE__{}, _player_id),
    do: {:error, :game_not_playing}

  @doc """
  Discards a card from the player's hand to the discard pile.

  Ends the player's turn and advances to the next player.
  """
  @spec discard(t(), String.t(), String.t()) :: {:ok, t()} | {:error, atom()}
  def discard(%__MODULE__{status: :playing} = game, player_id, card_id) do
    with :ok <- validate_turn(game, player_id),
         :ok <- validate_drawn(game),
         {:ok, card, hand} <- remove_card_from_hand(game, player_id, card_id) do
      game =
        game
        |> update_player_hand(player_id, hand)
        |> add_card_to_discard(card)
        |> advance_turn()

      game = %{game | drawn_this_turn: false}

      if hand == [] and team_has_canastra?(game, player_id) do
        case pickup_morto(game, player_id) do
          {:ok, game} -> {:ok, game}
          {:error, _} -> {:ok, game}
        end
      else
        {:ok, game}
      end
    end
  end

  def discard(%__MODULE__{}, _player_id, _card_id),
    do: {:error, :game_not_playing}

  @doc """
  Lays down a meld from the player's hand to their team's meld area.

  The selected cards must form a valid meld (three or more cards of the
  same rank, with at least one natural card).
  """
  @spec meld(t(), String.t(), [String.t()]) :: {:ok, t()} | {:error, atom()}
  def meld(%__MODULE__{status: :playing} = game, player_id, card_ids)
      when is_list(card_ids) do
    with :ok <- validate_turn(game, player_id),
         :ok <- validate_drawn(game),
         {:ok, cards, hand} <- remove_cards_from_hand(game, player_id, card_ids),
         true <- Meld.valid?(Meld.new(cards)),
         :ok <- validate_first_meld(game, cards) do
      meld = Meld.new(cards)
      current_player = Enum.at(game.players, game.turn)

      game =
        game
        |> update_player_hand(player_id, hand)
        |> add_meld_to_team(current_player.team, meld)

      {:ok, game}
    else
      false -> {:error, :invalid_meld}
      error -> error
    end
  end

  def meld(%__MODULE__{}, _player_id, _card_ids),
    do: {:error, :game_not_playing}

  defp validate_turn(game, player_id) do
    current_player = Enum.at(game.players, game.turn)

    if current_player && current_player.id == player_id do
      :ok
    else
      {:error, :not_your_turn}
    end
  end

  defp validate_not_drawn(%__MODULE__{drawn_this_turn: false}), do: :ok
  defp validate_not_drawn(%__MODULE__{}), do: {:error, :already_drew}

  defp validate_drawn(%__MODULE__{drawn_this_turn: true}), do: :ok
  defp validate_drawn(%__MODULE__{}), do: {:error, :must_draw_first}

  defp validate_first_meld(game, cards) do
    current_player = Enum.at(game.players, game.turn)
    team = game.teams[current_player.team]

    if team.first_meld_done or Meld.new(cards) |> Meld.points() >= 75 do
      :ok
    else
      {:error, :first_meld_minimum_not_met}
    end
  end

  defp black_three_penalty(game, team_id) do
    game.players
    |> Enum.filter(&(&1.team == team_id))
    |> Enum.flat_map(&Player.black_threes/1)
    |> Enum.reduce(0, fn _, acc -> acc - 100 end)
  end

  defp team_has_canastra?(game, player_id) do
    player = Enum.find(game.players, &(&1.id == player_id))

    if player do
      team = game.teams[player.team]
      Enum.any?(team.melds, &Meld.canastra?/1)
    else
      false
    end
  end

  defp red_three_bonus(team) do
    team.melds
    |> Enum.flat_map(&Meld.red_threes/1)
    |> Enum.reduce(0, fn _, acc -> acc + 100 end)
  end

  defp validate_discard_not_blocked(%__MODULE__{discard_pile: [top | _]}) do
    if Card.black_three?(top) do
      {:error, :discard_blocked_by_black_three}
    else
      :ok
    end
  end

  defp validate_discard_not_blocked(%__MODULE__{}), do: :ok

  defp give_card_to_player(game, player_id, card) do
    give_cards_to_player(game, player_id, [card])
  end

  defp give_cards_to_player(game, player_id, cards) do
    players =
      Enum.map(game.players, fn player ->
        if player.id == player_id do
          %{player | hand: player.hand ++ cards}
        else
          player
        end
      end)

    %{game | players: players}
  end

  defp morto_target_id(game, current_player) do
    if game.player_count == 2 do
      current_player.id
    else
      teammate =
        Enum.find(game.players, fn player ->
          player.team == current_player.team and player.id != current_player.id
        end)

      if teammate, do: teammate.id, else: current_player.id
    end
  end

  defp remove_card_from_hand(game, player_id, card_id) do
    case remove_cards_from_hand(game, player_id, [card_id]) do
      {:ok, [card], hand} -> {:ok, card, hand}
      error -> error
    end
  end

  defp remove_cards_from_hand(game, player_id, card_ids) do
    player = Enum.at(game.players, game.turn)

    if player && player.id == player_id do
      {removed, remaining} = Enum.split_with(player.hand, &(&1.id in card_ids))

      if length(removed) == length(card_ids) and unique_ids?(removed, card_ids) do
        {:ok, removed, remaining}
      else
        {:error, :card_not_in_hand}
      end
    else
      {:error, :not_your_turn}
    end
  end

  defp unique_ids?(cards, card_ids) do
    ids = Enum.map(cards, & &1.id)
    length(ids) == length(Enum.uniq(ids)) and length(ids) == length(card_ids)
  end

  defp update_player_hand(game, player_id, hand) do
    players =
      Enum.map(game.players, fn player ->
        if player.id == player_id do
          %{player | hand: hand}
        else
          player
        end
      end)

    %{game | players: players}
  end

  defp add_card_to_discard(game, card) do
    %{game | discard_pile: [card | game.discard_pile]}
  end

  defp add_meld_to_team(game, team_id, meld) do
    teams =
      Map.update!(game.teams, team_id, fn team ->
        %{team | melds: team.melds ++ [meld], first_meld_done: true}
      end)

    %{game | teams: teams}
  end

  defp advance_turn(game) do
    %{game | turn: rem(game.turn + 1, game.player_count)}
  end

  defp deal_players(cards, [], dealt_players), do: {Enum.reverse(dealt_players), cards}

  defp deal_players(cards, [player | rest], dealt_players) do
    {hand, remaining} = Enum.split(cards, 11)
    deal_players(remaining, rest, [%{player | hand: hand} | dealt_players])
  end
end
