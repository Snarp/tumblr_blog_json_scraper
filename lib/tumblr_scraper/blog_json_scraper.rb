require 'fileutils'

module TumblrScraper
  class BlogJsonScraper
    attr_accessor :overwrite, :interval, :client

    def initialize(overwrite: false, interval: 0.0, **credentials)
      @overwrite,@interval=overwrite,interval
      @client = TumblrScraper::Client.new(parse_json: true, **credentials)
    end

    def scrape_blog(blog_id, 
                    dir, 
                    interval:    @interval, 
                    overwrite:   @overwrite, 
                    before_id:   nil, 
                    limit:       20, 
                    reblog_info: true, 
                    **args)
      if args[:offset] || args[:before]
        raise ArgumentError.new("Invalid pagination argument: #{args}")
      end
      @meta          = { blog: nil, scrape_start: Time.now }
      @info          = @client.blog_info(blog_id)
      blog_id        = @info[:blog][:uuid]
      blog_name      = @info[:blog][:name]
      @meta[:blog]   = { name: blog_name, uuid: blog_id, }

      puts "Preparing to scrape JSON: #{{blog_name: blog_name, blog_id: blog_id, dir: dir}}"

      FileUtils.mkdir_p(json_dir=File.join(dir, '_json'))
      File.write(File.join(dir,'blog_info.json'),JSON::pretty_generate(@info))
      File.write(File.join(dir,'scrape_info.json'),JSON::pretty_generate(@meta))

      output = scrape_blog_posts(blog_id, json_dir, interval: interval, overwrite: overwrite, before_id: before_id, limit: limit, reblog_info: reblog_info, **args)

      @meta[:scrape_end]    = Time.now
      @meta[:end_args]      = output[:args]
      @meta[:posts_fetched] = output[:posts_fetched]
      @meta[:total_posts]   = @info[:blog][:total_posts]

      File.write(File.join(dir,'scrape_info.json'),JSON::pretty_generate(@meta))
      return @meta
    end

    def scrape_blog_posts(blog_id, 
                          dir, 
                          interval:    @interval, 
                          overwrite:   @overwrite, 
                          before_id:   nil, 
                          limit:       20, 
                          reblog_info: true, 
                          **args)
      if args[:offset] || args[:before]
        raise ArgumentError.new("Invalid pagination argument: #{args}")
      end
      FileUtils.mkdir_p(dir)

      @args = { 
        before_id: before_id, limit: limit, reblog_info: reblog_info 
      }.merge(args)
      i = 0
      pinned_post = nil
      while @page=@client.posts(blog_id, **@args)
        break unless @posts=@page[:posts]
        # Pinned post currently (2020-08-15) appears in EVERY /posts API 
        # response; need to catch it the first page and then ignore.
        if !pinned_post
          if pinned_post = @posts.detect { |post| post[:is_pinned] }
            save_post_json(pinned_post, dir, overwrite: true)
          end
        end
        @posts.select! { |post| !post[:is_pinned] }

        total_posts  = @page[:total_posts]
        i           += @posts.count
        print "\r~#{(100.0*i / total_posts).round(2)}% (#{i} / #{total_posts}) => before_id: #{@args[:before_id]}       "

        duplicate_found = false
        @posts.each do |post|
          if !save_post_json(post, dir, overwrite: overwrite)
            duplicate_found = true
            break
          end
        end
        break if (duplicate_found && !overwrite) || @posts.count < limit
        sleep(interval)
        @args[:before_id] = @posts.last[:id]
      end

      return { posts_fetched: i, args: @args, }
    end

    def save_post_json(post, dir, overwrite: @overwrite)
      filename = File.join(dir, "#{post[:id]}.json")
      if overwrite || !File.exist?(filename)
        File.write(filename, JSON::generate(post))
        return filename
      else
        warn "File already exists: #{filename}"
        return nil
      end
    end

  end # class JsonScraper
end