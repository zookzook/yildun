defmodule YildunTest do

  use Yildun.Collection

  @collection "rooms"
  collection @collection do
    attribute(:roomId, String.t())
  end

end
