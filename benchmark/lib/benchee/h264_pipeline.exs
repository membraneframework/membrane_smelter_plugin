defmodule Membrane.VideoCompositor.Benchmark.Benchee.H264 do
  @moduledoc """
  Benchmark for merge frames function.
  """
  alias Membrane.RawVideo
  alias Membrane.VideoCompositor.Pipeline.Utility.InputStream
  alias Membrane.VideoCompositor.Pipeline.Utility.Options
  alias Membrane.VideoCompositor.Test.Support.Utility

  @spec benchmark() :: :ok
  def benchmark() do
    report_output_dir = "./results/benchee/h264_pipeline_results"

    video_duration = 30

    output_dir = "./tmp_dir"
    output_path_720p = Path.join(output_dir, "output_#{video_duration}s_1280x1440.h264")
    output_path_1080p = Path.join(output_dir, "output_#{video_duration}s_1280x1440.h264")

    caps_720p = %RawVideo{
      width: 1280,
      height: 720,
      framerate: {30, 1},
      pixel_format: :I420,
      aligned: true
    }

    caps_1080p = %RawVideo{
      width: 1920,
      height: 1080,
      framerate: {30, 1},
      pixel_format: :I420,
      aligned: true
    }

    input_path_720p = "./tmp_dir/input_#{video_duration}s_720p.h264"
    input_path_1080p = "./tmp_dir/input_#{video_duration}s_1080p.h264"

    :ok = Utility.generate_testing_video(input_path_720p, caps_720p, video_duration)
    :ok = Utility.generate_testing_video(input_path_1080p, caps_1080p, video_duration)

    options_720p = %Options{
      inputs: [
        %InputStream{caps: caps_720p, position: {0, 0}, input: input_path_720p},
        %InputStream{caps: caps_720p, position: {0, caps_720p.height}, input: input_path_720p}
      ],
      output: output_path_720p,
      caps: %RawVideo{caps_720p | height: caps_720p.height * 2},
      implementation: nil
    }

    options_1080p = %Options{
      inputs: [
        %InputStream{caps: caps_1080p, position: {0, 0}, input: input_path_1080p},
        %InputStream{caps: caps_1080p, position: {0, caps_1080p.height}, input: input_path_1080p}
      ],
      output: output_path_1080p,
      caps: %RawVideo{caps_1080p | height: caps_1080p.height * 2},
      implementation: nil
    }

    Benchee.run(
      %{
        "OpenGL Rust - Two videos into one h264 pipeline benchmark" => fn options ->
          run_h264_pipeline(%{options | implementation: :opengl_rust})
        end
      },
      inputs: %{
        "1. 720p #{video_duration}s 30fps" => options_720p,
        "2. 1080p #{video_duration}s 30fps" => options_1080p
      },
      title: "H264 pipeline benchmark",
      parallel: 1,
      warmup: 2,
      time: 90,
      memory_time: 2,
      formatters: [
        {Benchee.Formatters.HTML,
         file: Path.join(report_output_dir, "h264_pipeline_benchmark.html")},
        Benchee.Formatters.Console
      ]
    )

    File.rm(input_path_720p)
    File.rm(input_path_1080p)
    File.rm(output_path_720p)
    File.rm(output_path_1080p)
    :ok
  end

  defp run_h264_pipeline(options) do
    {:ok, pid} = Membrane.VideoCompositor.Test.Support.Pipeline.H264.start(options)

    Process.monitor(pid)

    receive do
      {:DOWN, _ref, :process, _pid, :normal} -> :ok
    end
  end
end

Membrane.VideoCompositor.Benchmark.Benchee.H264.benchmark()
