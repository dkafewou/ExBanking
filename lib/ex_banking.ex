defmodule ExBanking do
  @moduledoc """
  Documentation for ExBanking.
  """
  alias ExBanking.Registry

  @typedoc """
  banking_error generic error type result
  """
  @type banking_error ::
          {:error,
           :wrong_arguments
           | :user_already_exists
           | :user_does_not_exist
           | :not_enough_money
           | :sender_does_not_exist
           | :receiver_does_not_exist
           | :too_many_requests_to_user
           | :too_many_requests_to_sender
           | :too_many_requests_to_receiver}

  @spec create_user(user :: String.t()) :: :ok | banking_error
  def create_user(user) do
    if is_to_many_requests?(user) do
      {:error, :too_many_requests_to_user}
    else
      if !is_binary(user) do
        {:error, :wrong_arguments}
      else
        case Registry.get(:banking_registry, user) do
          {:ok, _} ->
            {:error, :user_already_exists}

          {:error, :not_found} ->
            user_account = %{
              "name" => user,
              "myr" => 0
            }

            Registry.create(:banking_registry, {user, user_account})
        end
      end

      decrease_request(user)
      :ok
    end
  end

  @spec deposit(user :: String.t(), amount :: number, currency :: String.t()) ::
          {:ok, new_balance :: number} | banking_error
  def deposit(user, amount, currency) do
    if is_to_many_requests?(user) do
      {:error, :too_many_requests_to_user}
    else
      if !is_binary(user) || !is_number(amount) || amount < 0 || !is_binary(currency) do
        decrease_request(user)
        {:error, :wrong_arguments}
      else
        case Registry.get(:banking_registry, user) do
          {:ok, user_account} ->
            new_balance =
              if is_nil(user_account[currency]) do
                amount
              else
                user_account[currency] + amount
              end

            user_account =
              user_account
              |> Map.put(currency, new_balance)

            Registry.create(:banking_registry, {user, user_account})
            decrease_request(user)

            {:ok, new_balance}

          {:error, :not_found} ->
            decrease_request(user)
            {:error, :user_does_not_exist}
        end
      end
    end
  end

  @spec withdraw(user :: String.t(), amount :: number, currency :: String.t()) ::
          {:ok, new_balance :: number} | banking_error
  def withdraw(user, amount, currency) do
    if is_to_many_requests?(user) do
      {:error, :too_many_requests_to_user}
    else
      if !is_binary(user) || !is_number(amount) || amount < 0 || !is_binary(currency) do
        decrease_request(user)
        {:error, :wrong_arguments}
      else
        case Registry.get(:banking_registry, user) do
          {:ok, user_account} ->
            if !is_nil(user_account[currency]) && user_account[currency] >= amount do
              user_account =
                user_account
                |> Map.put(currency, user_account[currency] - amount)

              Registry.create(:banking_registry, {user, user_account})
              decrease_request(user)

              {:ok, user_account[currency]}
            else
              decrease_request(user)
              {:error, :not_enough_money}
            end

          {:error, :not_found} ->
            decrease_request(user)
            {:error, :user_does_not_exist}
        end
      end
    end
  end

  @spec get_balance(user :: String.t(), currency :: String.t()) ::
          {:ok, balance :: number} | banking_error
  def get_balance(user, currency) do
    if is_to_many_requests?(user) do
      {:error, :too_many_requests_to_user}
    else
      if !is_binary(user) || !is_binary(currency) do
        decrease_request(user)
        {:error, :wrong_arguments}
      else
        case Registry.get(:banking_registry, user) do
          {:ok, user_account} ->
            decrease_request(user)

            if !is_nil(user_account[currency]) do
              {:ok, user_account[currency]}
            else
              {:error, :not_enough_money}
            end

          {:error, :not_found} ->
            decrease_request(user)
            {:error, :user_does_not_exist}
        end
      end
    end
  end

  @spec send(
          from_user :: String.t(),
          to_user :: String.t(),
          amount :: number,
          currency :: String.t()
        ) :: {:ok, from_user_balance :: number, to_user_balance :: number} | banking_error
  def send(from_user, to_user, amount, currency) do
    if !is_binary(from_user) || !is_binary(to_user) || !is_number(amount) || amount < 0 ||
         !is_binary(currency) do
      {:error, :wrong_arguments}
    else
      case withdraw(from_user, amount, currency) do
        {:ok, from_user_balance} ->
          case deposit(to_user, amount, currency) do
            {:ok, to_user_balance} ->
              {:ok, from_user_balance, to_user_balance}

            {:error, :user_does_not_exist} ->
              # Reverse transaction in case receiver does not exist
              deposit(from_user, amount, currency)
              {:error, :receiver_does_not_exist}

            {:error, :too_many_requests_to_user} ->
              # Reverse transaction in case receiver have too many requests
              deposit(from_user, amount, currency)
              {:error, :too_many_requests_to_receiver}
          end

        {:error, :not_enough_money} ->
          {:error, :not_enough_money}

        {:error, :user_does_not_exist} ->
          {:error, :sender_does_not_exist}

        {:error, :too_many_requests_to_user} ->
          {:error, :too_many_requests_to_sender}
      end
    end
  end

  @spec is_to_many_requests?(user :: String.t()) :: true | false
  defp is_to_many_requests?(user) do
    case Registry.get(:users_request, user) do
      {:ok, request} ->
        if request >= 10 do
          true
        else
          # Add new request on the process
          Registry.create(:users_request, {user, request + 1})

          false
        end

      {:error, :not_found} ->
        # No request found then create first request
        Registry.create(:users_request, {user, 1})
        false
    end
  end

  @spec decrease_request(user :: String.t()) :: :ok | {:error, String.t()}
  defp decrease_request(user) do
    case Registry.get(:users_request, user) do
      {:ok, request} ->
        Registry.create(:users_request, {user, request - 1})

      {:error, :not_found} ->
        {:error, "Something went wrong"}
    end
  end
end
