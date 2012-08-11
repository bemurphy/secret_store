SecretStore
===========

Store secrets for your app in a encrypted in a yaml file.

Often when working on a web application, you have the need for storing a
variety of API keys or secrets to 3rd party services.  However, it's not
desireable to check those secrets in as plain text to the code respository.
This means that any 3rd party access to your repository provides that info.
With SecretStore, parties without knowledge of the master password (this can
include your own team members!) will not have direct access to such secrets.

One common way around this is to set such keys in the environment.  This is,
for example, what [Heroku recommends](https://devcenter.heroku.com/articles/config-vars)
for use on their platform.  While it works, it can end up cumbersome, is not easily
replicatable, and can require additional restarts in addition to a code
deploy depending on the architecture.

Instead, SecretStore encrypts all secrets with one master password, so there's only
one key to inject into the environment.

Installation
------------

install it via rubygems:

```
gem install secret_store
```

or put it in your Gemfile:

```ruby
# Gemfile
gem 'secret_store'
```

Usage
-----

```ruby
require "secret_store"

secret_store = SecretStore.new("master_password", "/path/to/data.yml")
secret_store.store("some_api_key", "c7dd199")
secret_store.get("some_api_key") # => "c7dd199"
secret_store.get("unknown_key") # => raises IndexError

secret_store.store("known_key", "b123fa") => stores
secret_store.store("known_key", "new_val") => raises error
secret_store.store("known_key", "new_val", :force) => overwrites stored
```

For a typical application, it could be desirable to define a
single SecretStore instance;  for example, in a rails initializer.

How
---

SecretStore uses [Gibberish](https://github.com/mdp/gibberish/) under the
hood to AES encrypt secrets in a YAML file.  Gibbersh currently has only
stdlib and core ruby dependencies, so it makes this code easier to read
without any extra requirements.

Caveats
-------

SecretStore code is not recommended for high security (ex: PCI compliance required)
use.  For your Todos webapp, it's fine!

Credits
-------

This was inspired by the [passw3rd](https://github.com/oreoshake/passw3rd) gem.

#### Copyright

Copyright (c) (2012) Brendon Murphy. See license.txt for details.

