defmodule HngetTest do
  use ExUnit.Case
  doctest Hnget

  test "greets the world" do
    assert Hnget.hello() == :world
  end
end
