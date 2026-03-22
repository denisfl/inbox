# Configure ActiveRecord encryption for all environments.
# In production, keys are derived from SECRET_KEY_BASE.
# For development and test, we use fixed deterministic keys.
if Rails.env.test? || Rails.env.development?
  ActiveRecord::Encryption.configure(
    primary_key: "test-primary-key-00000000000000000000000000000000",
    deterministic_key: "test-deterministic-key-000000000000000000000",
    key_derivation_salt: "test-key-derivation-salt-0000000000000000000"
  )
else
  secret = ENV["SECRET_KEY_BASE"] || Rails.application.secret_key_base
  if secret.present?
    ActiveRecord::Encryption.configure(
      primary_key: OpenSSL::HMAC.hexdigest("SHA256", secret, "active-record-encryption-primary-key"),
      deterministic_key: OpenSSL::HMAC.hexdigest("SHA256", secret, "active-record-encryption-deterministic-key"),
      key_derivation_salt: OpenSSL::HMAC.hexdigest("SHA256", secret, "active-record-encryption-key-derivation-salt")
    )
  end
end
