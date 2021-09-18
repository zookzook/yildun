defmodule Yildun.MixProject do
  use Mix.Project

  @version "0.1.1"

  def project do
    [
      source_url: "https://github.com/zookzook/yildun",
      app: :yildun,
      name: "yidun",
      version: @version,
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      docs: docs()
   ]
  end

  defp description() do
    """
    Yildun is a white-hued star in the northern circumpolar constellation of Ursa Minor, forming the second star in the bear's tail.
    And it is a very small library to support structs while using the MongoDB driver for Elixir.
    """
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:mongodb_driver, "~> 0.7.4"},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false}
    ]
  end

  defp package() do
    [maintainers: ["Michael Maier"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/zookzook/yildun"}]
  end

  defp docs() do
    [main: "Yildun.Collection", # The main page in the docs
      source_ref: "#{@version}",
      source_url: "https://github.com/zookzook/yildun",
      extras: ["README.md"]]
  end
end
