## about fediverse.network

**Fediverse.network's goal is to build a comprehensible list/map and statistics of the known oStatus/ActivityPub fediverse.**

As side-goals, it provides a [monitoring service](/monitoring) for instance owners.

Warning: **The site and its data is far from perfect yet!**

Other protocols than oStatus/ActivityPub may be added some day, for more details see [the info page](/info).

### Contact

* By e-mail: [root@fediverse.network](mailto:root@fediverse.network)
* On the fediverse: [@href@pleroma.fr](https://pleroma.fr/users/href)
* Matrix: #fd:random.sh
* IRC: irc.random.sh #fd (TLS mandatory, port 6697)

### API
{: #api}

It's planned as the next step once the underlying crawler will be more correct. :)

### Code

It's quite ugly right now, but you can find it at [git.yt/random/fediverse-network](https://git.yt/random/fediverse-network).

Written in Elixir, uses PostgreSQL with TimescaleDB, and licensed under AGPL; hosted on the glorious FreeBSD.

[Internal metrics](https://grafana.random.sh/dashboards/f/nUslNGVmz/fediverse-network) for the curious.

### Credits

Mostly made and hosted by [@href](https://soc.ialis.me/@href).

Thanks to the [contributors on the code](https://git.yt/random/fediverse-network/graphs/master); especially to [@heacte](https://soc.ialis.me/@hecate) who's done a huge work on the stats queries,

Thanks to everyone who helped me test, implemented nodeinfo endpoints, … ([@dashie](https://oldbytes.space/@dashie), …).

Thanks to [@Famine](https://soc.ialis.me/@Famine) for the logo.

Thanks to [chartd.co](https://chartd.co) for generating for us the png/svg charts used in lists.

