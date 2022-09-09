alias Membrane.RawVideo
alias Membrane.VideoCompositor.Implementations
alias Membrane.VideoCompositor.Testing.Utility

caps = %RawVideo{
  aligned: true,
  framerate: {30, 1},
  width: 1920,
  height: 1080,
  pixel_format: :I420
}

video_duration = 60

basename = Utility.get_file_base_name(caps, video_duration, "h264")
demo_path = Path.join([File.cwd!(), "lib", "tmp", "fixtures"])
in_path = Path.join(demo_path, "in-#{basename}")
out_path = Path.join(demo_path, "out-#{basename}")

Utility.generate_testing_video(in_path, caps, video_duration)

implementation = Implementations.get_implementation_atom_from_string(System.get_env("IMPL", "nx"))

{sink, encoder} =
  case s = System.get_env("SINK", "file") do
    "file" -> {out_path, Membrane.H264.FFmpeg.Encoder}
    "play" -> {Membrane.SDL.Player, nil}
    _unsupported -> raise "unsupported sink #{s}"
  end

src = in_path

paths = %{
  first_video_path: src,
  second_video_path: src,
  output_path: sink
}

options = %{
  paths: paths,
  caps: caps,
  implementation: implementation,
  encoder: encoder
}

{:ok, pid} = Membrane.VideoCompositor.Demo.Pipeline.H264.start(options)

Process.monitor(pid)

receive do
  {:DOWN, _ref, :process, _pid, :normal} -> :ok
end
