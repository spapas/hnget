defmodule Hnget do
  @moduledoc """
  Documentation for `Hnget`.
  """

  require Logger


  def get_max_id do
    with {:ok, r} <- HTTPoison.get("https://hacker-news.firebaseio.com/v0/maxitem.json"),
         {max, ""} <- Integer.parse(r.body),
         do: max
  end


end
