class SearchesController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @page = [params[:page].to_i, 1].max
    @per_page = [params[:per_page].to_i, 5].max
    @recent_searches = Current.user.searches.ordered
    @return_to_room = last_room_visited

    if @query.present?
      @results = Searches::WorkspaceSearchService.new(user: Current.user, query: @query, page: @page, per_page: @per_page).call
      @has_more = @results.size == @per_page
    else
      @results = []
      @has_more = false
    end

    respond_to do |format|
      format.html
      format.json do
        render json: {
          query: @query,
          results: @results.map do |result|
            {
              id: result[:title].to_s.parameterize,
              type: result[:type].to_s,
              title: result[:title].to_s,
              snippet: result[:snippet].to_s,
              project_name: result[:project_name].to_s,
              created_at: result[:created_at]&.iso8601,
              url: result[:url].to_s
            }
          end
        }
      end
    end
  end

  def create
    Current.user.searches.record(query)
    redirect_to searches_url(q: query)
  end

  def clear
    Current.user.searches.destroy_all
    redirect_to searches_url
  end

  def ask
    query = params[:q].to_s.strip
    room = Searches::AskFromWService.new(user: Current.user, query: query).call
    redirect_to room_url(room)
  end

  private
    def query
      params[:q].to_s.strip
    end
end
