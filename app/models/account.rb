class Account < ApplicationRecord
  include Joinable

  has_one_attached :logo
  has_json :settings, restrict_room_creation_to_administrators: false, allowed_bot_user_ids_csv: ""

  def settings
    _write_attribute("settings", {}) if attribute("settings").nil?

    hash = attribute("settings")
    hash = {} unless hash.is_a?(Hash)
    hash.deep_stringify_keys!

    schema = { restrict_room_creation_to_administrators: false }
    schema[:allowed_bot_user_ids_csv] = "" if hash.key?("allowed_bot_user_ids_csv") || hash.key?(:allowed_bot_user_ids_csv)

    ActiveModel::SchematizedJson::DataAccessor.new(schema, data: hash)
  end

  def allowed_bot_user_ids
    allowed_ids = normalized_allowed_bot_user_ids_from_settings
    allowed_ids = User.active_bots.pluck(:id) if allowed_ids.nil?

    User.active_bots.where(id: allowed_ids).pluck(:id)
  end

  def allowed_bot_users
    ids = allowed_bot_user_ids
    return User.none if ids.empty?

    User.active_bots.where(id: ids).ordered
  end

  def settings_with_allowed_bot_user_ids(ids)
    normalized = normalize_bot_user_ids(ids)
    write_attribute(:settings, settings_hash.merge("allowed_bot_user_ids_csv" => normalized.join(",")))
  end

  private
    def normalized_allowed_bot_user_ids_from_settings
      hash = settings_hash
      return nil unless hash.key?("allowed_bot_user_ids_csv")

      normalize_bot_user_ids(hash["allowed_bot_user_ids_csv"].to_s.split(","))
    end

    def settings_hash
      raw = self[:settings]
      return {} unless raw.is_a?(Hash)

      raw.deep_stringify_keys
    end

    def normalize_bot_user_ids(value)
      Array(value).filter_map do |id|
        Integer(id, exception: false)
      end.uniq
    end
end
