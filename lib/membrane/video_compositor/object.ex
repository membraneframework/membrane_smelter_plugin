defmodule Membrane.VideoCompositor.Object do
  @moduledoc """
  This module holds common types for different kinds of Objects available.
  """

  alias Membrane.VideoCompositor.Object.{InputImage, InputVideo, Layout, Texture}

  @typedoc """
  Objects are renderable entities in VC, that can serve as input for other
  objects or as an output of the video.

  They can be understood as video processing graph nodes, that are either:
  - input nodes - Video.t() or StaticFrame.t() structs, or
  - video processing nodes - Texture.t() or layouts defining following
  Layout.t() definition structs.
  """
  @type t :: Layout.t() | Texture.t() | InputImage.t() | InputVideo.t()

  @typedoc """
  Defines how an object can be referenced in Scene.

  Objects can be assigned to names and identified
  at other objects as inputs based on assigned names
  """
  @type name :: atom() | {atom(), atom()} | {atom(), non_neg_integer()}

  @typedoc """
  Defines how the output resolution of an object can be specified.

  Additionally, in Textures resolution can be specified as
  transformed resolution of the object input
  (e.g. for corners rounding - same as input,
  for cropping - accordingly smaller than input)
  """
  @type object_output_resolution :: Texture.output_resolution() | Layout.output_resolution()

  @typedoc """
  Rust `WgpuCtx` passed through elixir in an opaque way. Should be received in rust as `StructElixirPacket<WgpuCtx>`
  """
  @opaque wgpu_ctx() :: non_neg_integer()

  defmodule RustlerFriendly do
    @moduledoc false
    # rustler-friendly versions of all types common to all objects
    alias Membrane.VideoCompositor.Object.InputImage.RustlerFriendly, as: RFInputImage
    alias Membrane.VideoCompositor.Object.InputVideo.RustlerFriendly, as: RFInputVideo
    alias Membrane.VideoCompositor.Object.Layout.RustlerFriendly, as: RFLayout
    alias Membrane.VideoCompositor.Object.Texture.RustlerFriendly, as: RFTexture

    @type name ::
            {:atom, binary()}
            | {:atom_pair, binary(), binary()}
            | {:atom_num, binary(), non_neg_integer()}

    @type t ::
            {:layout, RFLayout.t()}
            | {:texture, RFTexture.t()}
            | {:video, RFInputVideo.t()}
            | {:image, RFInputImage.t()}

    @type object_output_resolution :: RFTexture.output_resolution() | RFLayout.output_resolution()
  end

  @doc false
  # Encode the object to an Object.RustlerFriendly.t() in order to prepare it for
  # the rust conversion.
  @spec encode(t()) :: RustlerFriendly.t()
  def encode(object) do
    case object do
      %InputVideo{} ->
        {:video, InputVideo.encode(object)}

      %InputImage{} ->
        {:image, InputImage.encode(object)}

      %Texture{} ->
        {:texture, Texture.encode(object)}

      %_module{
        inputs: _inputs,
        resolution: _resolution
      } = layout ->
        {:layout, Layout.encode(layout)}
    end
  end

  @doc false
  @spec encode_name(name()) :: RustlerFriendly.name()
  def encode_name(name) do
    case name do
      a when is_atom(a) -> {:atom, Atom.to_string(a)}
      {a, b} when is_atom(a) and is_atom(b) -> {:atom_pair, Atom.to_string(a), Atom.to_string(b)}
      {a, b} when is_atom(a) and is_integer(b) and b >= 0 -> {:atom_num, Atom.to_string(a), b}
      sth -> raise "improper object name #{inspect(sth)}"
    end
  end

  @doc false
  @spec encode_output_resolution(object_output_resolution()) ::
          RustlerFriendly.object_output_resolution()
  def encode_output_resolution(resolution) do
    alias Membrane.VideoCompositor.Resolution

    case resolution do
      :transformed_input_resolution -> :transformed_input_resolution
      %Resolution{} = resolution -> {:resolution, resolution}
      object_name -> {:name, encode_name(object_name)}
    end
  end
end
