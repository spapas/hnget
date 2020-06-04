defmodule FavReader do
  require Logger
  @temp_file "favs.bin"

  @spec get_all_user_favs(String.t()) :: MapSet.t()
  def get_all_user_favs(username) when is_binary(username) do
    story_favs = parse_favs_from_user(username, false)
    comment_favs = parse_favs_from_user(username, true)
    MapSet.union(story_favs, comment_favs)
  end

  @spec parse_favs_from_user(String.t(), boolean(), integer(), MapSet.t()) :: MapSet.t()
  def parse_favs_from_user(username, comments, page \\ 1, favs \\ MapSet.new()) when is_binary(username) and is_boolean(comments) and is_integer(page) do
    url = get_fav_url(username, comments, page)
    Logger.debug "Parsing #{url}"

    with {:get, {:ok, r}} <- {:get, HTTPoison.get(url)},
         {:dec, {:ok, doc}} <- {:dec, Floki.parse_document(r.body)} do

          new_favs = MapSet.union(favs, MapSet.new(Floki.attribute(doc, ".athing", "id")))
        if Floki.find(doc, ".morelink" ) |> Enum.count() > 0 do
          parse_favs_from_user(username, comments, page + 1, new_favs)
        else
          new_favs
        end

    else
      error ->
        Logger.warn("Username #{username} errored on page #{page} with comments #{comments}: #{error |> inspect}")
        favs
    end
  end

  @spec get_fav_url(String.t(), boolean, integer) :: String.t()
  def get_fav_url(username, comments, page \\ 1 ) when is_binary(username) and is_boolean(comments) and is_integer(page) do
    "https://news.ycombinator.com/favorites?id=#{username}&p=#{page}&comments=#{if comments, do: "t", else: "f"}"
  end

  def prepare_username_chunks() do
    {_num, names} = UserReader.get_initial_data
    names |> Enum.filter(&is_binary/1) |> Enum.sort |> Enum.chunk_every(100)

  end

  def get_initial_data() do
    @temp_file
    |> File.read()
    |> case do
      {:ok, contents} -> :erlang.binary_to_term(contents)
      _ -> {prepare_username_chunks(), Map.new()}
    end
  end


  def get_favs(workers, usernames) do
    inner_reducer = fn id, acc2 -> Map.update(acc2, id, 1, &(&1+1)) end
    outer_reducer = fn {:ok, ids}, acc -> Enum.reduce(ids, acc, inner_reducer) end
    Task.async_stream(usernames, &get_all_user_favs/1,
      max_concurrency: workers,
      timeout: 60000
    )
  |> Enum.reduce(Map.new(), outer_reducer)
  end

  def read_some_favs() do
    {[usernames | rest], current_favs} = get_initial_data()

    Logger.info(
      "Will start reading favs - #{rest|>Enum.count} user chunks remaining..."
    )

    new_favs = current_favs |> Map.merge(get_favs(100, usernames), fn _k, v1, v2 -> v1 + v2 end )

    save_data(rest, new_favs)

  end


  def save_data(usernames, favs) do
    case File.open(@temp_file, [:write]) do
      {:ok, file} ->
        IO.binwrite(file, :erlang.term_to_binary({usernames, favs}))
        File.close(file)

      {:error, reason} ->
        {:error, reason} |> IO.inspect()
    end
  end
end
