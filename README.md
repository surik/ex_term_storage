# ExTermStorage

[![Build Status](https://travis-ci.org/surik/ex_term_storage.svg?branch=master)](https://travis-ci.org/surik/ex_term_storage)

An example of how `Access` behaviour, `Inspect` and `Enumerable` protocols 
can be used to work with `ETS` as a typical `Keyword` list.

## Installation

The package can be installed by adding `ex_term_storage` to your list of dependencies 
in `mix.exs`:

```elixir
def deps do
  [
    {:ex_term_storage, github: "surik/ex_term_storage"}
  ]
end
```

I don't want to publish the package on `hex.pm` and the documentation on `hexdocs.pm` 
because this application is mosly a small sample. An example of usage can be found
in [ExTermStorage.ex](lib/ex_term_storage.ex)
