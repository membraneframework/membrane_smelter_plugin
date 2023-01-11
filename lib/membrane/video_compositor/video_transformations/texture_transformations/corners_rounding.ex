defmodule Membrane.VideoCompositor.VideoTransformations.TextureTransformations.CornersRounding do
  @moduledoc """
  Describe cropping texture transformation parameter.
  Corner rounding transformation can be imagined as placing four circles with specified radius
  adjoining to frame borders, placed inside frame and making space between circle edge and
  nearest frame corner transparent.
  ## Values
  - corner_rounding_radius: non negative integer representing radius of circle "cutting"
  frame corner part.
  ## Examples
    Example struct describing transformation which rounds corners with 100 pixel radius:

      iex> alias Membrane.VideoCompositor.VideoTransformations.TextureTransformations.CornersRounding
      Membrane.VideoCompositor.VideoTransformations.TextureTransformations.CornersRounding
      iex> %CornersRounding{ corner_rounding_radius: 100 }
      %Membrane.VideoCompositor.VideoTransformations.TextureTransformations.CornersRounding{
        corner_rounding_radius: 100
      }
  """

  @typedoc """
  Describe cropping texture transformation parameter.
  """
  @type t :: %__MODULE__{
          corner_rounding_radius: non_neg_integer()
        }

  @enforce_keys [:corner_rounding_radius]
  defstruct @enforce_keys
end
