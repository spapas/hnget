defmodule Hnget do
  @moduledoc """
  Documentation for `Hnget`.
  """

  require Logger

  @temp_file "fin.bin"
  @increase_size 100_000

  def get_max do
    # HTTPoison.start()

    with {:ok, r} <- HTTPoison.get("https://hacker-news.firebaseio.com/v0/maxitem.json"),
         {max, ""} <- Integer.parse(r.body),
         do: max
  end

  def get_stream(min, max) when is_integer(min) and is_integer(max) and min < max do
    Stream.unfold(max, fn
      ^min -> nil
      n -> {n, n - 1}
    end)
  end

  def parse_item(id) when is_integer(id) do
    url = "https://hacker-news.firebaseio.com/v0/item/#{id}.json"

    with {:get, {:ok, r}} <- {:get, HTTPoison.get(url)},
         {:dec, {:ok, j}} <- {:dec, Poison.decode(r.body)},
         {:fetch, {:ok, by}} <- {:fetch, Map.fetch(j, "by")} do
      by
    else
      {:fetch, :error} ->
        # Logger.debug("Id #{id} is deleted")
        {:error, :deleted}

      error ->
        Logger.warn("Id #{id} errored: #{error |> inspect}")
        {:error, :error}
    end
  end

  def get_usernames(workers, min, max) do
    Task.async_stream(get_stream(min, max), &parse_item/1,
      max_concurrency: workers,
      timeout: 60000
    )
    |> Enum.reduce(MapSet.new(), fn {:ok, by}, acc -> MapSet.put(acc, by) end)
  end

  def get_initial_data0() do
    case File.open(@temp_file, [:read]) do
      {:ok, file} ->
        initial = :erlang.binary_to_term(IO.binread(file, :all))
        File.close(file)
        initial

      {:error, _reason} ->
        {1, MapSet.new()}
    end
  end

  @spec get_initial_data :: any
  def get_initial_data() do
    @temp_file
    |> File.read()
    |> case do
      {:ok, contents} -> :erlang.binary_to_term(contents)
      _ -> {1, MapSet.new()}
    end
  end

  def save_data(next_start, users) do
    case File.open(@temp_file, [:write]) do
      {:ok, file} ->
        IO.binwrite(file, :erlang.term_to_binary({next_start, users}))
        File.close(file)

      {:error, reason} ->
        {:error, reason} |> IO.inspect()
    end
  end

  @spec read_some_usernames :: any
  def read_some_usernames() do
    {start, current_users} = get_initial_data()

    Logger.info(
      "Will start from item #{start} - got #{current_users |> Enum.count()} users already!"
    )

    max_id = get_max()

    next_start = start + @increase_size

    if next_start < max_id do
      new_users = get_usernames(100, start, next_start)
      save_data(next_start, MapSet.union(current_users, new_users))
    else
      new_users = get_usernames(100, start, max_id)
      save_data(next_start, MapSet.union(current_users, new_users))

      Logger.info("Reached max_id !")
    end
  end

  def read_more_usernames() do
    for i <- 1..220 do
      Logger.info("Reading chunk #{i}!")
      read_some_usernames()
    end
  end
end
