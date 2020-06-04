defmodule Hnget do
  @moduledoc """
  Documentation for `Hnget`.
  """

  require Logger
  @temp_file "fin.bin"


  def get_max_id do
    with {:ok, r} <- HTTPoison.get("https://hacker-news.firebaseio.com/v0/maxitem.json"),
         {max, ""} <- Integer.parse(r.body),
         do: max
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

end
