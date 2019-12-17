defmodule ExBanking.Registry do
  @moduledoc """

  Uses ETS to cache ExBanking Registry data
  """
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [],
      name: __MODULE__,
      strategy: :one_for_one
    )
  end

  def init(_) do
    :ets.new(:banking_registry, [:set, :protected, :named_table])
    :ets.new(:users_request, [:set, :protected, :named_table])

    {:ok, []}
  end

  # API
  def get(table, key) do
    GenServer.call(__MODULE__, {:get, table, key})
  end

  def create(table, value) do
    GenServer.cast(__MODULE__, {:create, table, value})
  end

  # CALLBACKS
  def handle_call({:get, table, key}, _, state) do
    reply =
      case :ets.lookup(table, key) do
        [{_key, value}] ->
          {:ok, value}

        _ ->
          {:error, :not_found}
      end

    {:reply, reply, state}
  end

  def handle_cast({:create, table, value}, state) do
    :ets.insert(table, value)

    {:noreply, state}
  end
end
