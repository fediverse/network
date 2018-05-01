# Fd - A Fediverse Network Directory

The code that powers [fediverse.network](https://fediverse.network), maybe some day fediverse.directory too.

## CLI Admin

    Fd.Instances.switch_flag(id, "dead", true)

Flags:

* dead
* monitor
* hidden
* valid

Launch a crawl:

    Fd.Instances.Server.crawl(id)

