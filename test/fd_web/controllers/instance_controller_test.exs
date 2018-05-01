defmodule FdWeb.InstanceControllerTest do
  use FdWeb.ConnCase

  alias Fd.Instances

  @create_attrs %{domain: "some domain"}
  @update_attrs %{domain: "some updated domain"}
  @invalid_attrs %{domain: nil}

  def fixture(:instance) do
    {:ok, instance} = Instances.create_instance(@create_attrs)
    instance
  end

  describe "index" do
    test "lists all instances", %{conn: conn} do
      conn = get conn, instance_path(conn, :index)
      assert html_response(conn, 200) =~ "Listing Instances"
    end
  end

  describe "new instance" do
    test "renders form", %{conn: conn} do
      conn = get conn, instance_path(conn, :new)
      assert html_response(conn, 200) =~ "New Instance"
    end
  end

  describe "create instance" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post conn, instance_path(conn, :create), instance: @create_attrs

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == instance_path(conn, :show, id)

      conn = get conn, instance_path(conn, :show, id)
      assert html_response(conn, 200) =~ "Show Instance"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post conn, instance_path(conn, :create), instance: @invalid_attrs
      assert html_response(conn, 200) =~ "New Instance"
    end
  end

  describe "edit instance" do
    setup [:create_instance]

    test "renders form for editing chosen instance", %{conn: conn, instance: instance} do
      conn = get conn, instance_path(conn, :edit, instance)
      assert html_response(conn, 200) =~ "Edit Instance"
    end
  end

  describe "update instance" do
    setup [:create_instance]

    test "redirects when data is valid", %{conn: conn, instance: instance} do
      conn = put conn, instance_path(conn, :update, instance), instance: @update_attrs
      assert redirected_to(conn) == instance_path(conn, :show, instance)

      conn = get conn, instance_path(conn, :show, instance)
      assert html_response(conn, 200) =~ "some updated domain"
    end

    test "renders errors when data is invalid", %{conn: conn, instance: instance} do
      conn = put conn, instance_path(conn, :update, instance), instance: @invalid_attrs
      assert html_response(conn, 200) =~ "Edit Instance"
    end
  end

  describe "delete instance" do
    setup [:create_instance]

    test "deletes chosen instance", %{conn: conn, instance: instance} do
      conn = delete conn, instance_path(conn, :delete, instance)
      assert redirected_to(conn) == instance_path(conn, :index)
      assert_error_sent 404, fn ->
        get conn, instance_path(conn, :show, instance)
      end
    end
  end

  defp create_instance(_) do
    instance = fixture(:instance)
    {:ok, instance: instance}
  end
end
