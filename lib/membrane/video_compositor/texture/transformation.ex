defmodule Membrane.VideoCompositor.Texture.Transformation do
  @moduledoc false

  @type definition_t :: struct() | module()
  @type name_t :: any()

  # TODO: placeholder
  @callback render() :: any()
end
