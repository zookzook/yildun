defmodule User do
  use Collection

  #@id_generator  {:id, &IDGenerator.generate/0}
  #@id_generator  false

  collection "users" do

    attribute :name, String.t(), default: "Michael"
    attribute :created, DateTime.t(), default: &DateTime.utc_now/0
    attribute :modified, DateTime.t(), default: &DateTime.utc_now/0

    after_load &User.on_load/1

  end

  def on_load(struct) do
    Map.put(struct, :name, "XXX")
  end

end


defmodule IDGenerator do
  def generate() do
    "2"
  end
end

defmodule Configuration do

  use Collection

  document do
    attribute :name, String.t()
    embeds_many :admins, User

    #before_dump &Label.before_dump/1
    #after_load &Label.after_load/1
  end
end

