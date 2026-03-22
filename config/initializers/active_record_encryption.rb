# Configure ActiveRecord encryption for all environments.
# In production, these should be set via Rails credentials or ENV variables.
# For development and test, we use fixed deterministic keys.
if Rails.env.test? || Rails.env.development?
  ActiveRecord::Encryption.configure(
    primary_key: "test-primary-key-00000000000000000000000000000000",
    deterministic_key: "test-deterministic-key-000000000000000000000",
    key_derivation_salt: "test-key-derivation-salt-0000000000000000000"
  )
end
