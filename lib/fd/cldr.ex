defmodule Fd.Cldr do
  use Cldr,
    locales: ["en"],
    default_locale: "en",
    providers: [Cldr.Unit, Cldr.Number, Cldr.List]
end
