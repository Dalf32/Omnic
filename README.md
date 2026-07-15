# Omnic
Discord bot framework built on top of [discordrb](https://github.com/shardlab/discordrb) and inspired by [Lita](https://github.com/litaio/lita), with [Redis](https://redis.io/) serving as the backing database. 

## Overview
The goal of Omnic is to be highly extensible, multi-purpose, and customizable per-server.

Functionality is bundled into Handlers, which are added to the bot via configuration. It is further grouped into Features, which can be enabled and disabled at the server level. Bot-level configuration for a Handler is scoped by its name, as is database storage, to help keep things separate.

## Setup and Usage
Omnic is run via `ruby omnic.rb [config.rb]`

If the path to the config file is not provided then it looks for one in the working directory. The configuration file specifies details of the bot application needed to authenticate with Discord, as well as logging, database details, and some other important options, all as key-value pairs. This file is still Ruby code, so simple calculations or other operations can be performed, though it is suggested that this be kept to a minimum.

The list of Handlers to load resides within the config file as well; they will be loaded in order and any failures encountered logged. Handler-specific configuration should also be included here, following this pattern: config.handlers.<handler_name>

## Development
Handlers are subclasses of CommandHandler and can register Features, Events, and Commands, as well as the names to be used for it in configuration and in the database. They are loaded on bot startup, but each triggered Event or Command is executed within a new instance.

- It is recommended that each Handler have one Feature, though this is not a rule
- Events allow triggering functionality in response to arbitrary Discord activity, or perform one-time setup (starting a thread, loading large amounts of data)
- Commands are actions initiated by users with the name of the command preceded by the configured prefix (default '!') 

Scoped configuration is accessible via the `config` method, and the logger via the `log` method. The Omnic module is globally accessible and allows access to the bot itself, as well as coordinating data structures, but should not be needed frequently.

### Features
Features are required to register a name, whether it is enabled by default, and a description. Events and Commands belonging to the feature will the specify the name. The Feature list shows each Feature name and description, as well as whether it is enabled on the current server, and all Commands that belong to it. If a Feature is not enabled on a given server, no Events or Commands belonging to that Feature will be triggered.

### Events
Events are required to register the name of the discord event and the method to be called when triggered. The method is called if the event is received, and the Feature is enabled (if any). The list of supported discord events can be found in the discordrb documentation [here](https://drb.shardlab.dev/v3.8.0/Discordrb/EventContainer.html). The method is passed an event object when called.

It is suggested that Events also specify the following, when applicable:

- Owning Feature (not relevant for all discord events)
- Whether it can be triggered from a private message (not relevant for all discord events)

### Commands
Commands are required to register a name and the method to be called when triggered. The method is called if the Feature is enabled (if any), the triggering message is well-formed & sent in an allowed channel, and the user has the needed permissions (if any). The method is passed an event object and all parameters (space delimited) provided by the user. The return value of the method is sent as a response message if not nil.

It is suggested that Commands also specify the following, when applicable:

- Owning Feature
- Whether it can be triggered from a private message
- Minimum and/or maximum number of arguments accepted (or none)
- Usage details (shown in help and if the message is not well-formed)
- Description (shown in help)
- Required user permissions (list [here](https://drb.shardlab.dev/v3.8.0/Discordrb/Permissions.html))
- Whether only the bot owner can use it
- Rate limiting

### Database
All Redis access should go through the following namespace convenience methods, which scope keys at various levels and then further by the Handler's name:

- `global_redis` - Bot-level data, the same for all servers and all users 
- `server_redis` - Server-level data, the same for all users within the same server
- `user_redis` - User-level data, the same across all servers, but different for each user

## Advanced
Omnic has additional built-in support for long-running threads, long-lived cached objects, and mutexes for simple locking.
