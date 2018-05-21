## Info

**The site and its data is far from perfect yet!**

### Search Params
{: #search-params}

The UI is currently shit but you can filter with some URL params keywords all the pages who returns an instance list:

Filters:

* **server** known (default), all, mastodon, pleroma, ….
* **up** true (default), false, all
* **tld** (no default). Any top-level domain
* **domain** (no default). use any registerable domain.

Ordering:

* **age** newest, oldest. Sorts by date of discovery.
* **users** desc, asc. (instances without users stats are ignored)
* **statuses** desc, asc. (instances without statuses stats are ignored)
* **peers** desc, asc. (instances without peers stats are ignored)
* **emojis** desc, asc. (instances without emojis stats are ignored)
* **max_chars** desc, asc.

### How It Works
{: #how-it-works}

The whole section is a bit outdated and will be clarified later.

#### Instance
{: #instance}

Instances should be checked at least every 85 minute and at most every 45 minute. Instance on which admins had to monitoring alerts are checked every minute.

Currently it tries getting information from theses API endpoint:

* Nodeinfo
* Mastodon's `/api/v1/instance`
* Statusnet-like `/api/statusnet/config, /api/statusnet/version`
* PeerTube's `/api/v1/config`

It fetches theses endpoints one-by-one and mixes information from the endpoint(s) who works.

##### Server & Version
{: #server-and-version}

From Mastodon API: `mastodon_version (compatible; server_name server_version` (in the "version" field of
/api/v1/instance, like Pleroma does).

With statusnet API, it's either `{"site": "platform": {"PLATFORM_NAME": "Server name", "STD_VERSION":
  "version"}}` (in ./config, like Hubzilla) or `server_name server_version` (in ./version, like
Pleroma).

##### Registrations
{: #registrations}

* From statusnet API, with the `closed` and `inviteonly` parameters.
* From Nodeinfo API
* From PeerTube API

##### Private/Hidden
{: #hidden}

* From statusnet API, the `private` parameter.
* For Friendica instances who does not reply on the nodeinfo API,

#### Peers
{: #peers}

From Mastodon API's `/api/v1/peers` only.

#### Emojis
{: #emojis}

From Mastodon API's `/api/v1/emojis` only.

