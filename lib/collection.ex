defmodule Collection do
  @moduledoc """

  Bei der Benutzung der MongoDB-Drivers werden ausschließlich Maps und Keyword-Listen verwenden.
  Möchte man nun anstelle der Maps lieber Structs verwenden, um dem Dokument ein stärkere Bedeutung zu geben oder
  seine Wichtigkeit zu betonen,
  so muss man aus der Map manuell ein `defstruct` machen:

      defmodule Label do
        defstruct name: "warning", color: "red"
      end

      iex> label_map = Mongo.find_one(:mongo, "labels", %{})
      %{"name" => "warning", "color" => "red"}
      iex> label = %Label{name: label_map["name"], color: label_map["color"]}

  Wir haben ein Module `Label` als `defstruct` definiert, anschließend holen wir uns das erste Label-Dokument aus
  der Collection `labels`. Die Funktion `find_one` liefert eine Map zurück. Diese konvertieren wir dann manuell und
  erhalten damit das gewünschte struct zurück.

  Möchten wir ein neues Struct speichern, so müssen wir die umgekehrte Arbeit durchführen. Wir wandeln das struct in eine Map um:

      iex> label = %Label{}
      iex> label_map = %{"name" => label.name, "color" => label.color}
      iex> {:ok, _} = Mongo.insert_one(:mongo, "labels", label_map)

  Alternativ kann man auch den Key `__struct__` aus `label` entfernen. Der MongoDB-Treiber wandel die Atom-Keys automatisch
  in Strings um.

      iex>  Map.drop(label, [:__struct__])
      %{color: :red, name: "warning"}

  Wenn man verschachtelte Strukturen verwendet, wird die Arbeit etwas aufwändiger. In diesem Fall muss man die inneren Strukturen
  ebenfalls manuell konvertieren.

  Betrachtet man die notwendigen Arbeiten genauer, so lassen sich zwei grundlegende Funktionen daraus ableiten:

    * `load` Konvertierung der Map in eine Struct.
    * `dump` Konvertierung des Structs in eine Map.

  Diese Modul stellt die notwendigen Macros zur Verfügung, um diesen Boilerplate-Code zu automatisieren.
  Das obige Beispiel läßt sich wie folgt umschreiben:

      defmodule Label do

        use Collection

        document do
          attribute :name, String.t(), default: "warning"
          attribute :color, String.t(), default: :red
        end

      end

  Damit erhält man folgendes Modul:

      defmodule Label do

        defstruct [name: "warning", color: "red"]

        @type t() :: %Label{String.t(), String.t()}

        def new()...
        def load(map)...
        def dump(%Label{})...
        def __collection(:attributes)...
        def __collection(:types)...
        def __collection(:collection)...
        def __collection(:id)...

      end

  Man kann nun neue Strukturen mit den Default-Werten erzeugen und die Konvertierungsfunktionen zwischen Maps und
  Structs aufrufen:

      iex(1)> x = Label.new()
      %Label{color: :red, name: "warning"}
      iex(2)> m = Label.dump(x)
      %{color: :red, name: "warning"}
      iex(3)> Label.load(m, true)
      %Label{color: :red, name: "warning"}

  Die `load/2` Funktion unterscheidet zwischen Keys vom Typ Strings `load(map, false)` und Keys von Typ Atom `load(map, true)`.
  Der Default ist `load(map, false)`:

      iex(1)> m = %{"color" => :red, "name" => "warning"}
      iex(2)> Label.load(m)
      %Label{color: :red, name: "warning"}

  Würde man nun Atoms als Keys erwarten, ist das Ergebnis der Konvertierung in diesem Fall nicht korrekt:

      iex(3)> Label.load(m, true)
      %Label{color: nil, name: nil}

  ## Collections

  Bei der MongoDB werden die Dokumente in Collections geschrieben. Wir können durch das `collection/2` Macro eine
  Collection anlegen:

        defmodule Card do

          use Collection

          @collection nil

          collection "cards" do
            attribute :title, String.t(), "new title"
          end

        end

  Durch das Macro `collection/2` wird eine Collection angelegt, die im Prinzip einem Dokument gleicht, wobei
  ein Attribut für die ID automatisch hinzugefügt wird. Zusätzlich wird die Attribut `@collection` belegt und
  kann in Funktionen als Konstante verwendet werden.

  In dem obigen Beispiel unterdrücken wir nur eine Warnung des Editors durch `@collection`. Das Macro erzeugt
  in dem Beispiel den folgenden Ausdruck: `@collection "cards"`. Default-mäßig wird für die ID das folgende Attribut erzeugt:

      {:_id, BSON.ObjectId.t(), &Mongo.object_id()/0}

  wobei der Default-Wert über die Funktion `&Mongo.object_id()/0` beim Aufruf von `new/0` erzeugt wird.

        iex> Card.new()
        %Card{_id: #BSON.ObjectId<5ec3d04a306a5f296448a695>, title: "new title"}

  Zusätzlich werden zwei weitere Reflection-Funktionen bereitgestellt:

        iex> Card.__collection__(:id)
        :_id
        iex(3)> Card.__collection__(:collection)
        "cards"

  ## Load and dump functions

  Kernfunktion dieses Moduls sind die erzeugten `load/1` und `dump/1` Funktionen. Damit lassen sich auch
  komplexere Document-Strukturen von Maps in Structs und umgekehrt konvertieren.

  ## MongoDB example

  Wir definieren folgende Collection:

        defmodule Card do

          use Collection

          @collection nil ## keeps the editor happy
          @id nil

          collection "cards" do
            attribute :title, String.t(), default: "new title"
          end

          def insert_one(%Card{} = card) do
            with map <- dump(card),
                 {:ok, _} <- Mongo.insert_one(:mongo, @collection, map) do
              :ok
            end
          end

          def find_one(id) do
            :mongo
            |> Mongo.find_one(@collection, %{@id: id})
            |> load()
          end

        end

  Dann können wir die Funktionen `insert_one` und `find_one` aufrufen. Dabei
  verwenden wir immer die definierte Structs als Parameter oder erhalten die
  Structs als Ergebnis zurück:

      iex(1)> card = Card.new()
      %Card{_id: #BSON.ObjectId<5ec3ed0d306a5f377943c23c>, title: "new title"}
      iex(6)> Card.insert_one(card)
      :ok
      iex(2)> Card.find_one(card._id)
      %XCard{_id: #BSON.ObjectId<5ec3ecbf306a5f3779a5edaa>, title: "new title"}



  ### Embedded documents

  Bis jetzt hatten wir nur einfache Attribute gezeigt. Interessant wird es erst, wenn wir
  andere Dokumenate einbetten. Mit den Macros `embeds_on/3` und `embeds_many/3` lassen sich Dokumente
  zu den Attributen hinzufügen:

  ## Example `embeds_one`

        defmodule Label do

          use Collection

          document do
            attribute :name, String.t(), default: "warning"
            attribute :color, String.t(), default: :red
          end

        end

        defmodule Card do

          use Collection

          @collection nil

          collection "cards" do
            attribute   :title, String.t()
            attribute   :list, BSON.ObjectId.t()
            attribute   :created, DateString.t(), default: &DateTime.utc_now/0
            attribute   :modified, DateString.t(), default: &DateTime.utc_now/0
            embeds_one  :label, Label, default: &Label.new/0
          end

        end

  Wenn wir nun `new/0` aufrufen, dann erhalten wir die folgende Struktur:

        iex(1)> Card.new()
        %Card{
          _id: #BSON.ObjectId<5ec3f0f0306a5f3aa5418a24>,
          created: ~U[2020-05-19 14:45:04.141044Z],
          label: %Label{color: :red, name: "warning"},
          list: nil,
          modified: ~U[2020-05-19 14:45:04.141033Z],
          title: nil
        }

  Es geht hier weiter

  """

  @doc false
  defmacro __using__(_) do
    quote do

      @before_dump_fun &Function.identity/1
      @after_load_fun &Function.identity/1
      @id_generator nil

      import Collection, only: [document: 1, collection: 2]

      Module.register_attribute(__MODULE__, :attributes, accumulate: true)
      Module.register_attribute(__MODULE__, :types, accumulate: true)
      Module.register_attribute(__MODULE__, :embed_ones, accumulate: true)
      Module.register_attribute(__MODULE__, :embed_manys, accumulate: true)
      Module.register_attribute(__MODULE__, :after_load_fun, [])
      Module.register_attribute(__MODULE__, :before_dump_fun, [])
    end
  end

  defmacro collection(name, [do: block]) do
    make_collection(name, block)
  end

  defmacro document([do: block]) do
    make_collection(nil, block)
  end

  defp make_collection(name, block) do

    prelude =
      quote do

        @collection unquote(name)

        @id_generator (case @id_generator do
          nil   -> {:_id, quote(do: BSON.ObjectId.t()), &Mongo.object_id()/0}
          false -> {nil, nil, nil}
          other -> other
        end)

        @id elem(@id_generator, 0)

        Collection.__id__(@id_generator, @collection)

        try do
          import Collection
          unquote(block)
        after
          :ok
        end
      end

    postlude =
      quote unquote: false do

        attribute_names = @attributes |> Enum.reverse |> Enum.map(&elem(&1, 0))
        struct_attrs    = (@attributes |> Enum.reverse |> Enum.map(fn {name, opts} -> {name, opts[:default]} end)) ++
                          (@embed_ones |> Enum.map(fn {name, _mod, opts} -> {name, opts[:default]} end)) ++
                          (@embed_manys |> Enum.map(fn {name, _mod, opts} -> {name, opts[:default]} end))

        defstruct struct_attrs

        Collection.__type__(@types)

        def __collection__(:attributes), do: unquote(attribute_names)
        def __collection__(:types), do: @types
        def __collection__(:collection), do: unquote(@collection)
        def __collection__(:id), do: unquote(elem(@id_generator, 0))
      end

    new_function =
      quote unquote: false do

        embed_ones  = (@embed_ones |> Enum.map(fn {name, _mod, opts} -> {name, opts} end))
        embed_manys = (@embed_manys |> Enum.map(fn {name, _mod, opts} -> {name, opts} end))
        args        = (@attributes ++ embed_ones ++ embed_manys)
                      |> Enum.map(fn {name, opts} -> {name, opts[:default]} end)
                      |> Enum.filter(fn {_name, fun} -> is_function(fun) end)

        args = case @id_generator do
          {id, fun} when id != nil -> [@id_generator | args]
          _                        -> args
        end

        def new() do
          %__MODULE__{unquote_splicing(Collection.struct_args(args))}
        end
      end

    load_function =
      quote unquote: false do

        attribute_names = @attributes |> Enum.map(&elem(&1, 0))
        embed_ones      = @embed_ones
                          |> Enum.filter(fn {_name, mod, _opts} -> Collection.has_load_function?(mod) end)
                          |> Enum.map(fn {name, mod, _opts} -> {name, mod} end)

        embed_manys     = @embed_manys
                          |> Enum.filter(fn {_name, mod, _opts} -> Collection.has_load_function?(mod) end)
                          |> Enum.map(fn {name, mod, _opts} -> {name, mod} end)

        def load(map, use_atoms \\ false)
        def load(nil, _use_atoms) do
          nil
        end

        def load(xs, use_atoms) when is_list(xs) do
          Enum.map(xs, fn map -> load(map, use_atoms) end)
        end

        def load(map, false) when is_map(map) do

          struct = Enum.reduce(unquote(attribute_names),
            %__MODULE__{},
            fn name, result ->
              Map.put(result, name, map[Atom.to_string(name)])
            end)

          struct = unquote(embed_ones)
                   |> Enum.map(fn {name, mod} -> {name, mod.load(map[Atom.to_string(name)])} end)
                   |> Enum.reduce(struct, fn {name, doc}, acc -> Map.put(acc, name, doc)  end)

          unquote(embed_manys)
          |> Enum.map(fn {name, mod} -> {name, mod.load(map[Atom.to_string(name)])} end)
          |> Enum.reduce(struct, fn {name, doc}, acc -> Map.put(acc, name, doc)  end)
          |> @after_load_fun.()
        end
        def load(map, true) when is_map(map) do

          struct = Enum.reduce(unquote(attribute_names),
            %__MODULE__{},
            fn name, result ->
              Map.put(result, name, map[name])
            end)

          struct = unquote(embed_ones)
                   |> Enum.map(fn {name, mod} -> {name, mod.load(map[name])} end)
                   |> Enum.reduce(struct, fn {name, doc}, acc -> Map.put(acc, name, doc)  end)

          unquote(embed_manys)
          |> Enum.map(fn {name, mod} -> {name, mod.load(map[name])} end)
          |> Enum.reduce(struct, fn {name, doc}, acc -> Map.put(acc, name, doc)  end)
          |> @after_load_fun.()
        end

      end

    dump_function =
      quote unquote: false do

        embed_ones  = @embed_ones
                      |> Enum.filter(fn {_name, mod, _opts} -> Collection.has_dump_function?(mod) end)
                      |> Enum.map(fn {name, mod, _opts} -> {name, mod} end)

        embed_manys = @embed_manys
                      |> Enum.filter(fn {_name, mod, _opts} -> Collection.has_dump_function?(mod) end)
                      |> Enum.map(fn {name, mod, _opts} -> {name, mod} end)

        def dump(xs) when is_list(xs) do
          Enum.map(xs, fn struct -> dump(struct) end)
        end

        def dump(%__MODULE__{} = struct) do

          struct = unquote(embed_ones)
                   |> Enum.map(fn {name, mod} -> {name, mod.dump(Map.get(struct, name))} end)
                   |> Enum.reduce(struct, fn {name, doc}, acc -> Map.put(acc, name, doc)  end)

          struct = unquote(embed_manys)
                   |> Enum.map(fn {name, mod} -> {name, mod.dump(Map.get(struct, name))} end)
                   |> Enum.reduce(struct, fn {name, doc}, acc -> Map.put(acc, name, doc)  end)

          struct
          |> @before_dump_fun.()
          |> DumpHelper.dump()
        end
      end

    quote do
      unquote(prelude)
      unquote(postlude)
      unquote(new_function)
      unquote(load_function)
      unquote(dump_function)
    end

  end

  defmacro __id__(id_generator, name) do
    quote do
      Collection.add_id(__MODULE__, unquote(id_generator), unquote(name))
    end
  end

  def add_id(_mod, _id_generator, nil) do
  end
  def add_id(_mod, {nil, _type, _fun}, _name) do
  end
  def add_id(mod, {id, type, fun}, _name) do
    Module.put_attribute(mod, :types, {id, type_for(type, false)})
    Module.put_attribute(mod, :attributes, {id, default: fun})
  end

  defmacro __type__(types) do
    quote bind_quoted: [types: types] do
      @type t() :: %__MODULE__{unquote_splicing(types)}
    end
  end

  def has_dump_function?(mod) do
    Keyword.has_key?(mod.__info__(:functions), :dump)
  end
  def has_load_function?(mod) do
    Keyword.has_key?(mod.__info__(:functions), :load)
  end

  def struct_args(args) when is_list(args) do
    Enum.map(args, fn {arg, func} -> struct_args(arg, func) end)
  end

  def struct_args(arg, func) do
    quote do
      {unquote(arg), unquote(func).()}
    end
  end

  defmacro before_dump(fun) do
    quote do
      Module.put_attribute(__MODULE__, :before_dump_fun, unquote(fun))
    end
  end

  defmacro after_load(fun) do
    quote do
      Module.put_attribute(__MODULE__, :after_load_fun, unquote(fun))
    end
  end

  defmacro embeds_one(name, mod, opts \\ []) do
    quote do
      Collection.__embeds_one__(__MODULE__, unquote(name), unquote(mod), unquote(opts))
    end
  end

  def __embeds_one__(mod, name, target, opts) do
    Module.put_attribute(mod, :embed_ones, {name, target, opts})
  end

  defmacro embeds_many(name, mod, opts \\ []) do
    quote do
      type = unquote(Macro.escape({{:., [], [mod, :t]}, [], []}))
      Collection.__embeds_many__(__MODULE__, unquote(name), unquote(mod), type, unquote(opts))
    end
  end

  def __embeds_many__(mod, name, target, type, opts) do
    Module.put_attribute(mod, :types, {name, type_for(type, false)})
    Module.put_attribute(mod, :embed_manys, {name, target, opts})
  end

  defmacro attribute(name, type, opts \\ []) do
    quote do
      Collection.__attribute__(__MODULE__, unquote(name), unquote(Macro.escape(type)), unquote(opts))
    end
  end

  def __attribute__(mod, name, type, opts) do
    Module.put_attribute(mod, :types, {name, type_for(type, false)})
    Module.put_attribute(mod, :attributes, {name, opts})
  end

  # Makes the type nullable if the key is not enforced.
  defp type_for(type, false), do: type
  defp type_for(type, _), do: quote(do: unquote(type) | nil)

end
