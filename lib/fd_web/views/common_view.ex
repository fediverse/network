defmodule FdWeb.CommonView do
  use FdWeb, :view

  def idna(domain) do
    Fd.Util.idna(domain)
  end

end
