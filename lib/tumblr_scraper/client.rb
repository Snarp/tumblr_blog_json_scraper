require 'faraday'
require 'faraday_middleware'

module TumblrScraper
  class Client
    attr_reader   :parse_json
    attr_accessor :api_host, :api_path, :http_client, :opts

    def initialize(consumer_key:, 
                   consumer_secret:    nil, 
                   oauth_token:        nil, 
                   oauth_token_secret: nil, 
                   parse_json:         true, 
                   http_client:        Faraday::default_adapter, 
                   api_host:           "api.tumblr.com", 
                   api_path:           nil, 
                   **opts)
      @credentials = { 
        consumer_key:    consumer_key, 
        consumer_secret: consumer_secret, 
        token:           oauth_token, 
        token_secret:    oauth_token_secret 
      }.select {|k,v| v}
      @parse_json = parse_json
      @api_host,@http_client,@opts = api_host,http_client,opts
      @conn = config_conn(parse_json: @parse_json, credentials: @credentials, api_host: @api_host, **@opts)
    end



    # ------
    # GET METHODS - USER
    # ------

    def user_info(**args)
      get_body("v2/user/info", **args)
    end
    alias_method :info, :user_info

    # NOTE: As of 2020-05-09, :before_id is working!, but still undocumented.
    #       (:before and :after still are not.)
    def dashboard(limit: nil, offset: nil, before_id: nil, since_id: nil, 
                  reblog_info: nil, notes_info: nil, type: nil, npf: nil, 
                  **args)
      get_body('v2/user/dashboard', limit: limit, offset: offset, before_id: before_id,  since_id: since_id, reblog_info: reblog_info, notes_info: notes_info, npf: npf, **args)
    end

    def user_likes(limit: nil, offset: nil, before: nil, after: nil, **args)
      get_body('v2/user/likes', limit: limit, offset: offset, before: before, after: after, **args)
    end
    alias_method :likes, :user_likes

    def user_following(limit: nil, offset: nil, **args)
      get_body('v2/user/following', limit: limit, offset: offset, **args)
    end
    alias_method :following, :user_following



    # ------
    # GET METHODS - INDIVIDUAL POSTS
    # ------

    # Fetches a single post for editing.
    def get_post(blog_id, id:, post_format: 'npf', **args)
      get_body("v2/blog/#{full_blog_id(blog_id)}/posts/#{id}", post_format: post_format, **args)
    end

    # :mode values =>
    #   "all"               all notes
    #   "likes"             only likes
    #   "conversation"      only replies and reblogs with added text commentary, with the rest of the notes (likes, reblogs without commentary) in a rollup_notes field.
    #   "rollup"            only like and reblog notes for the post in the notes array.
    #   "reblogs_with_tags" only the reblog notes for the post, and each note object includes a tags array field (which may be empty).
    # 
    # locate next timestamp =
    #   - notes[:notes].last[:timestamp]
    #   - notes[:_links][:next][:query_params][:before_timestamp]
    # (As of 2020-08-15, there is no notes[:_links][:previous])
    def notes(blog_id, id:, before_timestamp: nil, mode: nil, **args)
      get_body("v2/blog/#{full_blog_id(blog_id)}/notes", id: id, before_timestamp: before_timestamp, mode: mode, **args)
    end



    # ------
    # GET METHODS - BLOGS
    # ------

    def blog_info(blog_id, **args)
      get_body("v2/blog/#{full_blog_id(blog_id)}/info")
    end

    # Working pagination opts (2020-05-09): :before_id, :before, :after
    def posts(blog_id, type: nil, reblog_info: true, limit: nil, offset: nil, 
              before: nil, after: nil, before_id: nil, **args)
      path  = "v2/blog/#{full_blog_id(blog_id)}/posts"
      path += "/#{type}" if type
      get_body(path, reblog_info: reblog_info, limit: limit, offset: offset, before: before, after: after, before_id: before_id, **args)
    end
    alias_method :blog, :posts

    def queue(blog_id, offset: nil, limit: nil, filter: nil, **args)
      get_body("v2/blog/#{full_blog_id(blog_id)}/posts/queue", offset: offset, limit: limit, filter: filter, **args)
    end
    alias_method :queued, :queue

    def drafts(blog, before_id: nil, filter: nil, **args)
      get_body("v2/blog/#{full_blog_id(blog)}/posts/draft", before_id: before_id, filter: filter, **args)
    end

    def submissions(blog, offset: nil, filter: nil, **args)
      get_body("v2/blog/#{full_blog_id(blog)}/posts/submission", offset: offset, filter: filter, **args)
    end

    def blog_likes(blog, limit: nil, offset: nil, before: nil, after: nil, 
                   **args)
      get_body("v2/blog/#{full_blog_id(blog)}/likes", limit: limit, offset: offset, before: before, after: after, **args)
    end

    def followers(blog, limit: nil, offset: nil, **args)
      get_body("v2/blog/#{full_blog_id(blog)}/followers", limit: limit, offset: offset, **args)
    end

    def blog_following(blog, limit: nil, offset: nil, **args)
      get_body("v2/blog/#{full_blog_id(blog)}/following", limit: limit, offset: offset, **args)
    end



    # ------
    # GET METHODS - TAGS
    # ------

    def tagged(ttag=nil, tag: nil, before: nil, limit: nil, filter: nil, 
               **args)
      get_body('v2/tagged', tag: (tag || ttag), before: before, limit: limit, filter: filter, **args)
    end
    alias_method :tag, :tagged



    # ------
    # GET METHODS - LOW-LEVEL
    # ------

    def get_body(path, raise_errors: true, **args)
      resp = get_response(path, **args.select {|k,v| v})
      if    resp.success? && @parse_json
        return resp.body[:response]
      elsif resp.success?
        return resp.body
      elsif raise_errors
        raise Faraday::ClientError.new("Error #{resp.status}: #{{path: path, args: args}}")
      else
        warn "Error #{resp.status}: #{{path: path, args: args}}"
        return nil
      end
    end

    def get_response(path, **args)
      conn.get(path, args)
    end



    # ------
    # CONNECTION CONFIG
    # ------

    def conn
      @conn || config_conn
    end
    def conn=(new_conn)
      @conn = new_conn
    end

    def parse_json=(val)
      if @parse_json!=val
        @parse_json=val
        config_conn
      end
      return val
    end

    def config_conn(credentials: @credentials, 
                    client:      @http_client, 
                    parse_json:  @parse_json, 
                    api_host:    @api_host, 
                    **options)
      options = @opts if options.empty?
      options = {
        :headers => {
          :accept     => 'application/json',
          :user_agent => 'tumblr_client/0.8.5'
        },
        :url => "https://#{api_host}/", 
      }.merge(options)

      data = { api_host: api_host, ignore_extra_keys: true }.merge(credentials)

      @conn = Faraday.new(options) do |conn|
        conn.request  :oauth, data
        conn.request  :multipart
        conn.request  :url_encoded
        conn.request  :retry, max: 5, interval: 0.05, 
                              interval_randomness: 0.5, backoff_factor: 2
        conn.response :json, content_type: /\bjson$/, parser_options: {:symbolize_names=>true}                         if parse_json
        conn.adapter  client
      end
    end


    private

      def full_blog_id(blog_id)
        if blog_id.include?('.') || blog_id.include?(':')
          return blog_id
        else
          return blog_id+".tumblr.com"
        end
      end

  end # class TumblrClient
end # module Tumblr