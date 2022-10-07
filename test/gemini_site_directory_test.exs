defmodule GeminiSiteDirectoryTest do
  use ExUnit.Case

  @meta %{
    ".txt" => "text/plain",
    ".gemini" => "text/gemini"
  }

  @base "test/fixtures" |> Path.expand()

  test "good text file" do
    assert {:ok, %Gemini.Response{status: {2, 0}, meta: "text/plain", body: "foo\n"}} ==
             Gemini.Site.Directory.read_dir(@base, @meta, "/d/file_a.txt", "/d")
  end

  test "good gemini file" do
    assert {:ok, %Gemini.Response{status: {2, 0}, meta: "text/gemini", body: "bar\n"}} ==
             Gemini.Site.Directory.read_dir(@base, @meta, "/d/file_a.gemini", "/d")
  end

  test "good binary file" do
    assert {:ok,
            %Gemini.Response{status: {2, 0}, meta: "application/octet-stream", body: "foo\n"}} ==
             Gemini.Site.Directory.read_dir(@base, @meta, "/d/xyz/file_a", "/d")
  end

  test "bad local file" do
    assert {:error, :notfound} == Gemini.Site.Directory.read_dir(@base, @meta, "d/file_b", "d")
    assert {:error, :notfound} == Gemini.Site.Directory.read_dir(@base, @meta, "/d/file_b", "/d")
  end

  test "bad local directory" do
    assert {:error, :notfound} == Gemini.Site.Directory.read_dir(@base, @meta, "d/xyz", "d")
    assert {:error, :notfound} == Gemini.Site.Directory.read_dir(@base, @meta, "/d/xyz", "/d")
  end

  test "bad outside" do
    assert {:error, :notfound} ==
             Gemini.Site.Directory.read_dir(@base, @meta, "///etc/hosts", "/d")

    assert {:error, :notfound} ==
             Gemini.Site.Directory.read_dir(@base, @meta, "/d/../test_helper.exs", "/d")

    assert {:error, :notfound} ==
             Gemini.Site.Directory.read_dir(@base, @meta, "/d/../test_helper.exs", "/d")

    assert {:error, :notfound} ==
             Gemini.Site.Directory.read_dir(@base, @meta, "/d/xyz/../../test_helper.exs", "/d")
  end

  test "bad random" do
    assert {:error, :notfound} == Gemini.Site.Directory.read_dir(@base, @meta, "/d", "/d")
    assert {:error, :notfound} == Gemini.Site.Directory.read_dir(@base, @meta, "/d/.", "/d")
    assert {:error, :notfound} == Gemini.Site.Directory.read_dir(@base, @meta, "/d/./", "/d")
    assert {:error, :notfound} == Gemini.Site.Directory.read_dir(@base, @meta, "/d/./", "/d")
    assert {:error, :notfound} == Gemini.Site.Directory.read_dir(@base, @meta, "/d/././", "/d")
  end
end
