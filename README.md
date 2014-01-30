# Spool

Spool is a monitor for [Slush's Bitcoin Mining Pool] [1]. It presents all available information about your mining account and workers.

## Installation

Spool requires [`jq`] [2] to parse the JSON API response and [`spark`] [3] to generate bar graphs.

Once `jq` and `spark` are installed, run the command to clone and install Spool:

`git clone https://github.com/adamlazz/spool.git; cd spool; chmod +x spool.sh`

## Configuration

The configuration file is a text file named `config` in the same directory as `spool.sh`

The first line of the config file is your API key for Slush's pool. You can get yours [here] [4].

The remaining lines of the `config` file are a list of keys in the JSON API response that you are interested in. Worker options (eg. `worker_hashrate`) show information for all workers. You may also use `newline` to print a new line.

## Execution

To run the script, `cd` into the directory with `spool.sh` and your `config` file in it and run `./spool.sh`

[1]: http://mining.bitcoin.cz/
[2]: http://stedolan.github.io/jq/
[3]: https://github.com/holman/spark
[4]: https://mining.bitcoin.cz/accounts/token-manage/
