defmodule Membrane.VideoCompositor.Test.Support.Pipeline.H264.ParserDecoder do
  @moduledoc """
  Simple bin parsing and decoding H264 buffers into raw frames.
  """
  use Membrane.Bin
  alias Membrane.RawVideo

  def_options framerate: [
                spec: H264.framerate_t() | nil,
                default: nil,
                description: """
                Framerate of video stream, see `t:Membrane.H264.framerate_t/0`
                """
              ]

  def_input_pad :input,
    demand_unit: :buffers,
    demand_mode: :auto,
    caps: :any

  def_output_pad :output,
    demand_mode: :auto,
    caps: {RawVideo, pixel_format: one_of([:I420, :I422]), aligned: true}

  @impl true
  def handle_init(opts) do
    children = %{
      parser: %Membrane.H264.FFmpeg.Parser{framerate: opts.framerate},
      decoder: Membrane.H264.FFmpeg.Decoder
    }

    links = [
      link_bin_input(:input) |> to(:parser) |> to(:decoder) |> to_bin_output(:output)
    ]

    spec = %ParentSpec{children: children, links: links}

    {{:ok, spec: spec}, %{}}
  end
end
