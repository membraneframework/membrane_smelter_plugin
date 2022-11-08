defmodule Membrane.VideoCompositor do
  @moduledoc """
  The element responsible for placing the first received frame
  above the other and sending forward buffer with
  merged frame binary in the payload.
  """

  use Membrane.Filter
  alias Membrane.RawVideo
  alias Membrane.VideoCompositor.Implementations

  def_options implementation: [
                type: :atom,
                spec: Implementations.implementation_t() | {:mock, module()},
                description: "Implementation of video composer."
              ],
              caps: [
                type: RawVideo,
                description: "Struct with video width, height, framerate and pixel format."
              ]

  def_input_pad :input,
    demand_unit: :buffers,
    availability: :on_request,
    demand_mode: :auto,
    caps: {RawVideo, pixel_format: :I420},
    options: [
      position: [
        type: :tuple,
        spec: {integer(), integer()},
        description:
          "Initial position of the video on the screen, given in the pixels, relative to the upper left corner of the screen",
        default: {0, 0}
      ]
    ]

  def_output_pad :output,
    demand_unit: :buffers,
    demand_mode: :auto,
    caps: {RawVideo, pixel_format: :I420}

  @impl true
  def handle_init(options) do
    compositor_module = determine_compositor_module(options.implementation)

    {:ok, internal_state} = compositor_module.init(options.caps)

    state = %{
      video_positions_waiting_for_caps: %{},
      caps: options.caps,
      compositor_module: compositor_module,
      internal_state: internal_state,
      pads_to_ids: %{},
      new_pad_id: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_prepared_to_playing(_ctx, state) do
    {{:ok, caps: {:output, state.caps}}, state}
  end

  @impl true
  def handle_pad_added(pad, context, state) do
    position = context.options.position

    state = register_pad(state, pad, position)
    {:ok, state}
  end

  defp register_pad(state, pad, position) do
    new_id = state.new_pad_id

    %{
      state
      | video_positions_waiting_for_caps:
          Map.put(state.video_positions_waiting_for_caps, new_id, position),
        pads_to_ids: Map.put(state.pads_to_ids, pad, new_id),
        new_pad_id: new_id + 1
    }
  end

  @impl true
  def handle_caps(pad, caps, _context, state) do
    %{
      pads_to_ids: pads_to_ids,
      internal_state: internal_state,
      video_positions_waiting_for_caps: video_positions_waiting_for_caps
    } = state

    id = Map.get(pads_to_ids, pad)

    {position, video_positions_waiting_for_caps} = Map.pop!(video_positions_waiting_for_caps, id)
    {:ok, internal_state} = state.compositor_module.add_video(internal_state, id, caps, position)

    state = %{
      state
      | internal_state: internal_state,
        video_positions_waiting_for_caps: video_positions_waiting_for_caps
    }

    {:ok, state}
  end

  @impl true
  def handle_process(
        pad,
        buffer,
        _context,
        state
      ) do
    %{
      pads_to_ids: pads_to_ids,
      internal_state: internal_state
    } = state

    id = Map.get(pads_to_ids, pad)

    %Membrane.Buffer{payload: frame, pts: pts} = buffer

    case state.compositor_module.upload_frame(internal_state, id, {frame, pts}) do
      {{:ok, {frame, pts}}, internal_state} ->
        {
          {
            :ok,
            buffer: {
              :output,
              %Membrane.Buffer{payload: frame, pts: pts}
            }
          },
          %{state | internal_state: internal_state}
        }

      {:ok, internal_state} ->
        {:ok, %{state | internal_state: internal_state}}
    end
  end

  @impl true
  def handle_end_of_stream(
        pad,
        context,
        state
      ) do
    %{pads_to_ids: pads_to_ids, internal_state: internal_state} = state
    id = Map.get(pads_to_ids, pad)

    {:ok, internal_state} = state.compositor_module.send_end_of_stream(internal_state, id)
    state = %{state | internal_state: internal_state}

    if all_input_pads_received_end_of_stream?(context.pads) do
      {{:ok, end_of_stream: :output}, state}
    else
      {:ok, state}
    end
  end

  defp all_input_pads_received_end_of_stream?(pads) do
    Map.to_list(pads)
    |> Enum.all?(fn {ref, pad} -> ref == :output or pad.end_of_stream? end)
  end

  defp determine_compositor_module(implementation) do
    case implementation do
      {:mock, module} ->
        module

      implementation ->
        case Implementations.get_implementation_module(implementation) do
          {:ok, module} -> module
          {:error, error} -> raise error
        end
    end
  end
end
