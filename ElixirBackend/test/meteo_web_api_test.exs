defmodule MeteoWebApiTest do
  use ExUnit.Case
  doctest MeteoWebApi

  test "greets the world" do
    assert MeteoWebApi.hello() == :world
  end
end
