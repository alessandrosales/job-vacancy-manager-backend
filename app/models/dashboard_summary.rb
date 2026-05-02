# frozen_string_literal: true

# Agrega contagens e listas para `GET /api/v1/dashboard` (gráficos + tabelas).
class DashboardSummary
  TABLE_LIMIT = 10

  def initialize(user)
    @user = user
  end

  def call
    {
      pie_by_status: pie_by_status,
      created_by_weekday: created_by_weekday,
      trend_by_week: trend_by_week,
      status_series: status_series,
      recent_opportunities: serialize_opportunities(recent_relation),
      top_opportunities: serialize_opportunities(top_relation),
      reference_lists: reference_lists
    }
  end

  private

  def opportunities_scope
    @user.opportunities.includes(:company, :role, :opportunity_status)
  end

  def pie_by_status
    counts = @user.opportunities.group(:status_id).count
    labels = @user.opportunity_statuses.index_by(&:id)
    counts.filter_map do |status_id, count|
      next if count.zero?

      st = labels[status_id]
      {
        status_id: status_id,
        label: st&.label || "Unknown",
        count: count
      }
    end.sort_by { |row| -row[:count] }
  end

  # Segunda a domingo da semana civil atual (Time.zone), contagens por `created_at`.
  def created_by_weekday
    week_start = Time.zone.now.beginning_of_week(:monday).to_date
    (0..6).map do |offset|
      day = week_start + offset
      {
        weekday: offset,
        label: day.strftime("%a"),
        count: @user.opportunities.where(created_at: day.all_day).count
      }
    end
  end

  # Quatro semanas encerrando na semana atual: oportunidades criadas no intervalo, por status.
  def trend_by_week
    today = Time.zone.today
    monday = today.beginning_of_week(:monday)
    week_starts = 4.times.map { |i| monday - (3 - i).weeks }

    week_starts.map do |start_date|
      range = start_date.beginning_of_day..(start_date + 6.days).end_of_day
      counts = @user.opportunities.where(created_at: range).group(:status_id).count
      end_d = start_date + 6.days
      {
        week_label: "#{start_date.strftime('%b %-d')} – #{end_d.strftime('%b %-d')}",
        counts_by_status_id: counts.transform_keys(&:to_s)
      }
    end
  end

  def status_series
    @user.opportunity_statuses.order(:position, :created_at).map do |s|
      { status_id: s.id, label: s.label }
    end
  end

  def recent_relation
    opportunities_scope.order(updated_at: :desc).limit(TABLE_LIMIT)
  end

  def top_relation
    opportunities_scope.order(interest_level: :desc, updated_at: :desc).limit(TABLE_LIMIT)
  end

  def serialize_opportunities(relation)
    relation.map { |opp| opportunity_payload(opp) }
  end

  def opportunity_payload(opp)
    opp.as_api_json.merge(
      "company_name" => opp.company.name,
      "role_name" => opp.role.name,
      "status_label" => opp.opportunity_status.label,
      "status_variant" => opp.opportunity_status.variant
    )
  end

  def reference_lists
    {
      companies: @user.companies.order(:name).map(&:as_api_json),
      roles: @user.roles.order(:name).map(&:as_api_json),
      opportunity_statuses: @user.opportunity_statuses.order(:position, :created_at).map(&:as_api_json)
    }
  end
end
