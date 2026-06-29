defmodule Membrane.Smelter.Mixfile do
  use Mix.Project

  @version "0.12.2"
  @github_url "https://github.com/membraneframework/membrane_smelter_plugin"

  def project do
    [
      app: :membrane_smelter_plugin,
      version: @version,
      compilers: compilers(),
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),

      # hex
      description: "Smelter SDK for Membrane Multimedia Framework",
      package: package(),

      # docs
      name: "Membrane Smelter Plugin",
      source_url: @github_url,
      docs: docs(),
      aliases: [docs: ["docs", &append_llms_links/1]]
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp compilers() do
    Mix.compilers() ++ [:download_compositor]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib", "test"]

  defp deps do
    [
      # Membrane
      {:membrane_core, "~> 1.0"},
      {:membrane_raw_video_format, "~> 0.3.0 or ~> 0.4.0"},
      {:membrane_opus_plugin, "~> 0.20.4"},
      ## RTP
      {:membrane_rtp_plugin, "~> 0.31.4"},
      {:membrane_rtp_h264_plugin, "~> 0.20.0"},
      {:membrane_tcp_plugin, "~> 0.6.0"},
      {:membrane_rtp_opus_plugin, "~> 0.10.0"},
      # VC server start
      {:muontrap, "~> 1.0"},
      # VC API
      {:req, "~> 0.5.0"},
      {:websockex, "~> 0.4.3"},
      {:jason, "~> 1.4"},
      # Dev
      {:ex_doc, ">= 0.40.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: :dev, runtime: false}
    ]
  end

  defp dialyzer() do
    opts = [
      flags: [:error_handling],
      ignore_warnings: ".dialyzer_ignore.exs",
      plt_add_apps: [:mix]
    ]

    if System.get_env("CI") == "true" do
      # Store PLTs in cacheable directory for CI
      [plt_local_path: "priv/plts", plt_core_path: "priv/plts"] ++ opts
    else
      opts
    end
  end

  defp package do
    [
      maintainers: ["Software Mansion"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @github_url,
        "Smelter Homepage" => "https://smelter.dev",
        "Membrane Framework Homepage" => "https://membrane.stream"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "LICENSE"],
      source_ref: "v#{@version}",
      nest_modules_by_prefix: [Membrane.Smelter, Membrane.Smelter.Request],
      groups_for_modules: [
        Encoders: [
          ~r/^Membrane\.Smelter\.Encoder($|\.)/
        ],
        Requests: [
          ~r/^Membrane\.Smelter\.Request($|\.)/
        ]
      ]
    ]
  end

  defp append_llms_links(_args) do
    output_dir = docs()[:output] || "doc"
    path = Path.join(output_dir, "llms.txt")

    if File.exists?(path) do
      existing = File.read!(path)

      footer = """


      ## See Also

      - [Membrane Framework AI Skill](https://hexdocs.pm/membrane_core/skill.md)
      - [Membrane Core](https://hexdocs.pm/membrane_core/llms.txt)
      """

      File.write!(path, String.trim_trailing(existing) <> footer)
    else
      IO.warn("#{path} not found — llms.txt was not generated, check your ex_doc configuration")
    end
  end
end
