defmodule MyModule do
  require Mod
  Mod.definfo
end

defmodule Yildun do
  def hello do
    :world
  end
  def friendly_info do
    IO.puts """
    My name is #{__MODULE__}
    #My functions are #{inspect __MODULE__.__info__(:functions)}
    """
  end

end
