defmodule Fd.InstancesTest do
  use Fd.DataCase

  alias Fd.Instances

  describe "instances" do
    alias Fd.Instances.Instance

    @valid_attrs %{domain: "some domain"}
    @update_attrs %{domain: "some updated domain"}
    @invalid_attrs %{domain: nil}

    def instance_fixture(attrs \\ %{}) do
      {:ok, instance} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Instances.create_instance()

      instance
    end

    test "list_instances/0 returns all instances" do
      instance = instance_fixture()
      assert Instances.list_instances() == [instance]
    end

    test "get_instance!/1 returns the instance with given id" do
      instance = instance_fixture()
      assert Instances.get_instance!(instance.id) == instance
    end

    test "create_instance/1 with valid data creates a instance" do
      assert {:ok, %Instance{} = instance} = Instances.create_instance(@valid_attrs)
      assert instance.domain == "some domain"
    end

    test "create_instance/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Instances.create_instance(@invalid_attrs)
    end

    test "update_instance/2 with valid data updates the instance" do
      instance = instance_fixture()
      assert {:ok, instance} = Instances.update_instance(instance, @update_attrs)
      assert %Instance{} = instance
      assert instance.domain == "some updated domain"
    end

    test "update_instance/2 with invalid data returns error changeset" do
      instance = instance_fixture()
      assert {:error, %Ecto.Changeset{}} = Instances.update_instance(instance, @invalid_attrs)
      assert instance == Instances.get_instance!(instance.id)
    end

    test "delete_instance/1 deletes the instance" do
      instance = instance_fixture()
      assert {:ok, %Instance{}} = Instances.delete_instance(instance)
      assert_raise Ecto.NoResultsError, fn -> Instances.get_instance!(instance.id) end
    end

    test "change_instance/1 returns a instance changeset" do
      instance = instance_fixture()
      assert %Ecto.Changeset{} = Instances.change_instance(instance)
    end
  end
end
