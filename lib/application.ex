defmodule ExBanking.Application do
  @moduledoc """
  The ExBanking Application Service.

  The ExBanking system business domain lives in this application.

  Exposes API to client.
  """
  use Application

  def start(_type, _args) do
    children = [
      ExBanking.Registry
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
