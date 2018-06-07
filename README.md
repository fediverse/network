# Fd - A Fediverse Network Directory

The code that powers [fediverse.network](https://fediverse.network), maybe some day fediverse.directory too.

Development dependencies:

* Erlang, Elixir
* PostgreSQL
* TimescaleDB PostgreSQL extension
* Node.JS, NPM

## Development setup

Configure `config/dev.exs` if you need another db/user than `fd_dev` and `postgres`.

Checkout dependencies

    mix deps.get
    cd assets && npm install && cd ..

Create the database

    mix ecto.migrate

If your postgresql user is not a superuser, you will need to create the database manually and load the extensions:

    psql -d fd_database
    create extension timescaledb;

Run the database migrations

    mix ecto.migrate

Run it

    iex -S mix phx.server

## CLI Admin

Add an instance:

    instance_domain = "soc.ialis.me"
    {:ok, instance} = Fd.Instances.create_instance(%{"domain" => instance_domain})

Crawl an instance:

    Fd.Instances.Server.crawl(instance.id)

Switch flags for an instance:

    Fd.Instances.switch_flag(id, "dead", true)

Flags:

* dead
* monitor
* hidden
* valid

