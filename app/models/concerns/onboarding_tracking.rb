module OnboardingTracking
  extend ActiveSupport::Concern

  DASHBOARD_ONBOARDING_STATE_VERSION = 1
  DASHBOARD_ONBOARDING_STATE_KEYS = %w[
    dismissed_at
    detailed_view_seen_at
    demo_seeded_at
    restarted_at
    data_exported_at
    version
  ].freeze

  def dashboard_onboarding_state
    normalized_dashboard_onboarding_state
  end

  def dashboard_onboarding_dismissed_at
    dashboard_onboarding_timestamp(:dismissed_at)
  end

  def dashboard_onboarding_detailed_view_seen_at
    dashboard_onboarding_timestamp(:detailed_view_seen_at)
  end

  def dashboard_onboarding_demo_seeded_at
    dashboard_onboarding_timestamp(:demo_seeded_at)
  end

  def dashboard_onboarding_restarted_at
    dashboard_onboarding_timestamp(:restarted_at)
  end

  def dashboard_onboarding_data_exported_at
    dashboard_onboarding_timestamp(:data_exported_at)
  end

  def dashboard_onboarding_data_exported?
    dashboard_onboarding_current_version? && dashboard_onboarding_data_exported_at.present?
  end

  def dashboard_onboarding_version
    normalized_dashboard_onboarding_state["version"].to_i
  end

  def dashboard_onboarding_current_version?
    dashboard_onboarding_version == DASHBOARD_ONBOARDING_STATE_VERSION
  end

  def dashboard_onboarding_dismissed?
    dashboard_onboarding_current_version? && dashboard_onboarding_dismissed_at.present?
  end

  def dashboard_onboarding_detailed_view_seen?
    dashboard_onboarding_current_version? && dashboard_onboarding_detailed_view_seen_at.present?
  end

  def dismiss_dashboard_onboarding!(at: Time.current)
    set_dashboard_onboarding_timestamp!(:dismissed_at, at: at)
  end

  def mark_dashboard_onboarding_details_seen!(at: Time.current)
    set_dashboard_onboarding_timestamp!(:detailed_view_seen_at, at: at)
  end

  def mark_dashboard_onboarding_exported!(at: Time.current)
    set_dashboard_onboarding_timestamp!(:data_exported_at, at: at)
  end

  def reset_dashboard_onboarding!(reset_progress: false)
    with_lock do
      reload
      state = normalized_dashboard_onboarding_state
      state["dismissed_at"] = nil
      state["detailed_view_seen_at"] = nil
      state["restarted_at"] = reset_progress ? Time.current.iso8601 : state["restarted_at"]
      state["data_exported_at"] = nil if reset_progress
      state["version"] = DASHBOARD_ONBOARDING_STATE_VERSION
      
      update!(onboarding_state: state)
    end
  end

  private

  def normalized_dashboard_onboarding_state(raw_state = self[:onboarding_state])
    default_dashboard_onboarding_state.merge(
      raw_state.to_h.stringify_keys.slice(*DASHBOARD_ONBOARDING_STATE_KEYS)
    )
  end

  def default_dashboard_onboarding_state
    {
      "dismissed_at" => nil,
      "detailed_view_seen_at" => nil,
      "demo_seeded_at" => nil,
      "restarted_at" => nil,
      "data_exported_at" => nil,
      "version" => DASHBOARD_ONBOARDING_STATE_VERSION
    }
  end

  def dashboard_onboarding_timestamp(key)
    raw_value = normalized_dashboard_onboarding_state[key.to_s]
    return if raw_value.blank?

    Time.zone.parse(raw_value)
  rescue ArgumentError, TypeError
    nil
  end

  def set_dashboard_onboarding_timestamp!(key, at: Time.current)
    with_lock do
      reload

      state = normalized_dashboard_onboarding_state
      existing_timestamp = dashboard_onboarding_timestamp_from_state(state, key)
      if existing_timestamp.present? && state["version"].to_i == DASHBOARD_ONBOARDING_STATE_VERSION
        return existing_timestamp
      end

      state[key.to_s] = at.iso8601
      state["version"] = DASHBOARD_ONBOARDING_STATE_VERSION

      update!(onboarding_state: state)
      at
    end
  end

  def dashboard_onboarding_timestamp_from_state(state, key)
    raw_value = state[key.to_s]
    return if raw_value.blank?

    Time.zone.parse(raw_value)
  rescue ArgumentError, TypeError
    nil
  end
end