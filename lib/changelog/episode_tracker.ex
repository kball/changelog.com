defmodule Changelog.EpisodeTracker do
    use GenServer

    alias Changelog.Episode
    alias Changelog.Metacasts.Filterer.Cache

    def start_link do
        GenServer.start_link(__MODULE__, nil, name: __MODULE__)
    end

    def list do
        GenServer.call(__MODULE__, :list)
    end

    # This is advantageous to avoid passing a copy of a thousand episode list
    # across the process boundary, it filters on the GenServer side
    def filter(filter_string) do
        GenServer.call(__MODULE__, {:filter, filter_string})
    end

    # Allow further stripping out of information my running an Enum.map with
    # the passed callback before crossing the process boundary
    def filter(filter_string, map_callback) do
        GenServer.call(__MODULE__, {:filter, filter_string, map_callback})
    end

    def get_episodes_as_ids(filter_string) do
        filter(filter_string, fn episode -> episode.id end)
    end

    def refresh do
        GenServer.cast(__MODULE__, :refresh)
    end

    @impl true
    def init(_) do
        episodes = refresh_episodes()
        {:ok, episodes}
    end

    @impl true
    def handle_call(_, _, [] = episodes) do
        {:reply, {:error, :no_episodes}, episodes}
    end

    @impl true
    def handle_call(:list, _from, episodes) do
        {:reply, {:ok, episodes}, episodes}
    end

    @impl true
    def handle_call({:filter, filter_string}, _from, episodes) do
        filtered = case Cache.filter(episodes, filter_string) do
            {:ok, episode_stream} -> {:ok, Enum.to_list(episode_stream)}
            error -> error
        end
        {:reply, filtered, episodes}
    end

    @impl true
    def handle_call({:filter, filter_string, map_callback}, _from, episodes) do
        filtered = case Cache.filter(episodes, filter_string) do
            {:ok, episode_stream} -> {:ok, Enum.map(episode_stream, map_callback)}
            error -> error
        end
        {:reply, filtered, episodes}
    end

    @impl true
    def handle_cast(:refresh, _episodes) do
        episodes = refresh_episodes()
        {:noreply, episodes}
    end

    defp refresh_episodes do
        {:ok, episodes} = Episode.flatten_for_filtering()
        episodes
    end
end