defmodule Collection do
  @moduledoc """

  When using the [MongoDB driver](https://hex.pm/packages/mongodb_driver) only maps and keyword lists are used to
  represent documents.
  If you would prefer to use structs instead of the maps to give the document a stronger meaning or to emphasize
  its importance, you have to create a `defstruct` and fill it from the map manually:

      defmodule Label do
        defstruct name: "warning", color: "red"
      end

      iex> label_map = Mongo.find_one(:mongo, "labels", %{})
      %{"name" => "warning", "color" => "red"}
      iex> label = %Label{name: label_map["name"], color: label_map["color"]}

  We have defined a module `Label` as` defstruct`, then we get the first label document
  the collection `labels`. The function `find_one` returns a map. We convert the map manually and
  get the desired struct.

  If we want to save a new structure, we have to do the reverse. We convert the struct into a map:

      iex> label = %Label{}
      iex> label_map = %{"name" => label.name, "color" => label.color}
      iex> {:ok, _} = Mongo.insert_one(:mongo, "labels", label_map)

  Alternatively, you can also remove the `__struct__` key from `label`. The MongoDB driver automatically
  converts the atom keys into strings.

      iex>  Map.drop(label, [:__struct__])
      %{color: :red, name: "warning"}

  If you use nested structures, the work becomes a bit more complex. In this case, you have to use the inner structures
  convert manually, too.

  If you take a closer look at the necessary work, two basic functions can be derived:

    * `load` Conversion of the map into a struct.
    * `dump` Conversion of the struct into a map.

  This module provides the necessary macros to automate this boilerplate code.
  The above example can be rewritten as follows:

      defmodule Label do

        use Collection

        document do
          attribute :name, String.t(), default: "warning"
          attribute :color, String.t(), default: :red
        end

      end

  This results in the following module:

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

  You can now create new structs with the default values and use the conversion functions between maps and
  structs:

      iex(1)> x = Label.new()
      %Label{color: :red, name: "warning"}
      iex(2)> m = Label.dump(x)
      %{color: :red, name: "warning"}
      iex(3)> Label.load(m, true)
      %Label{color: :red, name: "warning"}

  The `load/2` function distinguishes between keys of type binarys `load(map, false)` and keys of type atoms `load(map, true)`.
  The default is `load(map, false)`:

      iex(1)> m = %{"color" => :red, "name" => "warning"}
      iex(2)> Label.load(m)
      %Label{color: :red, name: "warning"}

  If you would now expect atoms as keys, the result of the conversion is not correct in this case:

      iex(3)> Label.load(m, true)
      %Label{color: nil, name: nil}

  The background is that MongoDB always returns binarys as keys and structs use atoms as keys.

  ## Collections

  In MongoDB, documents are written in collections. We can use the `collection/2` macro to create
  a collection:

        defmodule Card do

          use Collection

          @collection nil

          collection "cards" do
            attribute :title, String.t(), "new title"
          end

        end

  The `collection/2` macro creates a collection that is basically similar to a document, where
  an attribute for the ID is added automatically. Additionally the attribute `@collection` is assigned and
  can be used as a constant in other functions.

  In the example above we only suppress a warning of the editor by '@collection'. The macro creates the following
  expression: `@collection "cards"`. By default, the following attribute is created for the ID:

      {:_id, BSON.ObjectId.t(), &Mongo.object_id()/0}

  where the default value is created via the function '&Mongo.object_id()/0' when calling 'new/0':

        iex> Card.new()
        %Card{_id: #BSON.ObjectId<5ec3d04a306a5f296448a695>, title: "new title"}

  Two additional reflection features are also provided:

        iex> Card.__collection__(:id)
        :_id
        iex(3)> Card.__collection__(:collection)
        "cards"

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
            |> Mongo.find_one(@collection, %{@id => id})
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

  ## id generator

  In der MongoDB ist es üblich, dass als id das attribut `_id` verwendet wird. Als Wert wird
  ein objectid verwendet, dass vom mongodb-treiber erzeugt wird. Dieses verhalten kann durch
  das module attribut `@id_generator` bei Verwendung von `collection` gesteuert werden.
  Die Default-Einstellung lautet:

        {:_id, BSON.ObjectId.t(), &Mongo.object_id()/0}

  Nun kann man dieses Tupel `{name, type, function}` nach belieben überschreiben:

        @id_generator false # keine ID-Erstellung
        @id_generator {id, String.t, &IDGenerator.next()/0} # customized name and generator
        @id_generator nil # use default: {:_id, BSON.ObjectId.t(), &Mongo.object_id()/0}

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

  ## Example `embeds_many`

  ## `after_load/1` and `before_dump/1` macros

  Manchmal möchte man nach dem Laden des Datensatzes eine Nachbearbeitung durchführen, ob z.B.
  abgeleitete Attribute zu erstellen. Umgekehrt möchte man vor dem Speichern diese Attribute
  wieder entfernen, damit diese nicht gespeichert werden.

  Aus diesem Grund gibt es die beiden Macros `after_load/1` and `before_dump/1`. Hier wird eine
  Funktion angegeben, die nach dem `load/0` bzw. vor dem `dump` aufgerufen wird:

        defmodule Board do

        use Collection

          collection "boards" do

            attribute   :id, String.t() ## derived attribute
            attribute   :title, String.t()
            attribute   :created, DateString.t(), default: &DateTime.utc_now/0
            attribute   :modified, DateString.t(), default: &DateTime.utc_now/0
            embeds_many :lists, BoardList

            after_load  &Board.after_load/1
            before_dump &Board.before_dump/1
          end

          def after_load(%Board{_id: id} = board) do
            %Board{board | id: BSON.ObjectId.encode!(id)}
          end

          def before_dump(board) do
            %Board{board | id: nil}
          end

          def new(title) do
            new()
            |> Map.put(:title, title)
            |> Map.put(:lists, [])
            |> after_load()
          end

          def store(board) do
            with map <- dump(board),
                {:ok, _} <- Mongo.insert_one(:mongo, @collection, map) do
              :ok
            end
          end

          def fetch(id) do
            :mongo
            |> Mongo.find_one(@collection, %{@id => id})
            |> load()
          end

        end

  In diesem Beispiel wird das Attribut `id` von der eigentlich ID abgeleitet und als String gespeichert.
  Diese Attribut wird häufig verwendet und daher ersparen wir uns die ständige Konvertierung der ID. Damit die
  abgeleitete `id` nicht gespeichert wird, wird eine `before_dump/1` Funktion aufgerufen, die das Attribut
  einfach entfernt:

        iex(1)> board = Board.new("Vega")
        %Board{
          _id: #BSON.ObjectId<5ec3f802306a5f3ee3b71cf2>,
          created: ~U[2020-05-19 15:15:14.374556Z],
          id: "5ec3f802306a5f3ee3b71cf2",
          lists: [],
          modified: ~U[2020-05-19 15:15:14.374549Z],
          title: "Vega"
        }
        iex(2)> Board.store(board)
        :ok
        iex(3)> Board.fetch(board._id)
        %Board{
          _id: #BSON.ObjectId<5ec3f802306a5f3ee3b71cf2>,
          created: ~U[2020-05-19 15:15:14.374Z],
          id: "5ec3f802306a5f3ee3b71cf2",
          lists: [],
          modified: ~U[2020-05-19 15:15:14.374Z],
          title: "Vega"
        }

  Rufen wir den Datensatz in der Mongo-Shell auf, dann sehen wir, dass das Attribute `id` dort nicht gespeichert wurde:

        > db.boards.findOne({"_id" : ObjectId("5ec3f802306a5f3ee3b71cf2")})
        {
          "_id" : ObjectId("5ec3f802306a5f3ee3b71cf2"),
          "created" : ISODate("2020-05-19T15:15:14.374Z"),
          "lists" : [ ],
          "modified" : ISODate("2020-05-19T15:15:14.374Z"),
          "title" : "Vega"
        }

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
