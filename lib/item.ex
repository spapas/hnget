defmodule Item do
  @type kinds :: :job | :story | :comment | :poll | :pollopt

  @type t :: %__MODULE__{
    id: integer(),
    kind: kinds(),
    by: String.t(),
    time: integer(),
    url: String.t(),
    title: String.t(),
    score: integer(),
    fav_count: integer(),
  }

  @enforce_keys [:id, :kind, :by, :time, :url, :title, :score, :fav_count]
  defstruct [:id, :kind, :by, :time, :url, :title, :score, fav_count: 0]
end
