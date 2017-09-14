# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_start_session',
  :secret      => '69abd60ee7f8328d0dbe1bb500bf9f4ea1b377e4afe40309acee6f82bd454b9f26965e68d86eb1d1ce390d01057a287ba21a776fa7e665c78eece5285890ca9d'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
