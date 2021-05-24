defmodule GeminiTest do
  use ExUnit.Case
  doctest Gemini

  test "greets the world" do
    assert Gemini.hello() == :world
  end
end
