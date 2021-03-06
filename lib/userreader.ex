defmodule UserReader do
  require Logger
  @increase_size 100_000
  @temp_file "fin.bin"

  def parse_user_from_item(id) when is_integer(id) do
    url = "https://hacker-news.firebaseio.com/v0/item/#{id}.json"

    with {:get, {:ok, r}} <- {:get, HTTPoison.get(url)},
         {:dec, {:ok, %{}=j}} <- {:dec, Poison.decode(r.body)},
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

  def get_int_stream(min, max) when is_integer(min) and is_integer(max) and min < max do
    Stream.unfold(max, fn
      ^min -> nil
      n -> {n, n - 1}
    end)
  end


  def get_usernames(workers, min, max) do
    Task.async_stream(get_int_stream(min, max), &parse_user_from_item/1,
      max_concurrency: workers,
      timeout: 60000
    )
    |> Enum.reduce(MapSet.new(), fn {:ok, by}, acc -> MapSet.put(acc, by) end)
  end


  def read_some_usernames() do
    {start, current_users} = get_initial_data()

    Logger.info(
      "Will start from item #{start} - got #{current_users |> Enum.count()} users already!"
    )

    max_id = Hnget.get_max_id() |> IO.inspect

    next_start = start + @increase_size |> IO.inspect

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
    for i <- 1..10 do
      Logger.info("Reading chunk #{i}!")
      read_some_usernames()
    end
  end


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


end
