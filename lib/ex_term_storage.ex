defmodule ExTermStorage do
  @moduledoc """
  An example of how `Access` behaviour, `Inspect` and `Enumerable` protocols 
  can be used to work with `ETS` as a typucal `Keyword` list:

      iex> t = ExTermStorage.new()
      #ExTermStorage<[]>
      iex> put_in t[:a], 1
      #ExTermStorage<[a: 1]>
      iex> t[:a]
      1
      iex> put_in t[:a], 2
      #ExTermStorage<[a: 2]>

  A table can be initialized with list when creating:

      iex> ExTermStorage.new([a: 1, b: 2])
      #ExTermStorage<[a: 1, b: 2]>
    
  It supports Enumerable protocol so easy to transform into map or list:

      iex> t = ExTermStorage.new([a: 1, b: 2])
      iex> Enum.count(t)
      2
      iex> Enum.to_list(t)
      [a: 1, b: 2]
      iex> Enum.into t, %{}
      %{a: 1, b: 2}

  Check that key is in the table though `in` operator:

      iex> t = ExTermStorage.new([a: 1, b: 2])
      iex> :a in t
      true
      iex> :c in t
      false

  Enumerable protocol allows to use table in list comprehensions:

      iex> t = ExTermStorage.new([a: 1, b: 2])
      iex> for {_, v} <- t, do: v * 2
      [2, 4]

  And Streams:

      iex> t = ExTermStorage.new([a: 1, b: 2])
      iex> Stream.cycle(t) |> Enum.take(5)
      [a: 1, b: 2, a: 1, b: 2, a: 1]

  """

  defstruct [owner: nil, table: nil]

  alias ExTermStorage

  @behaviour Access

  @type t :: %ExTermStorage{}
  @type key :: any
  @type value :: any

  @spec new :: t
  def new() do
    t = :ets.new(:t, [:public, :ordered_set, 
                      {:read_concurrency, true}, 
                      {:write_concurrency, true}])
    %ExTermStorage{table: t, owner: :ets.info(t, :owner)}
  end

  @spec new(list) :: Enumerable.t
  def new(list) when is_list(list) do
    t = new()
    for {k, v} <- list, do: _ = put_in t[k], v
    t
  end

  @spec fetch(t, key) :: {:ok, value} | :error
  def fetch(container, key) do
    case lookup(container, key) do
      {^key, value} -> {:ok, value}
      _             -> :error
    end
  end

  @spec get(t, key, value) :: value
  def get(container, key, default) do
    case lookup(container, key) do
      {^key, value} -> value
      _             -> default
    end
  end

  defp lookup(%ExTermStorage{table: t} = _container, key) do
    case :ets.lookup(t, key) do
      [{^key, value}] -> {key, value}
      _               -> nil
    end
  end
  defp lookup(_t, _key), do: nil

  @spec get_and_update(t, key, (value -> {get, value} | :pop)) :: {get, map} when get: term
  def get_and_update(%ExTermStorage{table: t} = container, key, fun) do
    current = get(container, key, nil)

    case fun.(current) do
      {get, update} ->
        :ets.insert(t, {key, update})
        {get, container}
      :pop ->
        :ets.delete(t, key)
        {current, container}
      other ->
        raise "the given function must return a two-element tuple or :pop, got: #{inspect(other)}"
    end
  end

  @spec pop(t, key) :: {value, t}
  def pop(%ExTermStorage{table: t} = container, key) do
    case :ets.take(t, key) do
      [value] -> {value, container}
      _       -> {nil, container}
    end
  end

  @doc false
  def reduce(%ExTermStorage{table: t} = container, acc, fun), do:
    reduce(container, :ets.first(t), acc, fun)

  defp reduce(_stream, _key, {:halt, acc}, _fun), do: 
    {:halted, acc}

  defp reduce(container, key, {:suspend, acc}, fun), do:
    {:suspended, acc, &reduce(container, key, &1, fun)}

  defp reduce(_stream, :"$end_of_table", {:cont, acc}, _fun), do:
    {:done, acc}

  defp reduce(%ExTermStorage{table: t} = container, key, {:cont, acc}, fun), do:
    reduce(container, :ets.next(t, key), fun.(lookup(container, key), acc), fun)
end

defimpl Inspect, for: ExTermStorage do
  import Inspect.Algebra

  def inspect(%ExTermStorage{table: t}, opts) do
    concat ["#ExTermStorage<", to_doc(:ets.tab2list(t), opts), ">"]
  end
end

defimpl Enumerable, for: ExTermStorage do
  def count(%ExTermStorage{table: t}), do: {:ok, :ets.info(t, :size)}

  def member?(%ExTermStorage{table: t}, key), do: {:ok, :ets.member(t, key)}

  def reduce(container, acc, fun), do: ExTermStorage.reduce(container, acc, fun)
end
