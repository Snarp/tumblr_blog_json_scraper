require_relative 'lib/tumblr_scraper'
require 'dotenv'
Dotenv.load

def credentials
  { 
    consumer_key:        ENV['CONSUMER_KEY'], 
    consumer_secret:     ENV['CONSUMER_SECRET'], 
    oauth_token:         ENV['OAUTH_TOKEN'], 
    oauth_token_secret:  ENV['OAUTH_TOKEN_SECRET'], 
  }
end

def output_dir
  if ENV['OUTPUT_DIRECTORY'] && ENV['OUTPUT_DIRECTORY']!=''
    return ENV['OUTPUT_DIRECTORY']
  else
    return File.join(Dir.home, 'Downloads', 'Tumblr')
  end
end

def scrape_blog(blog_name, output_dir=output_dir())
  blog_dir = File.join(output_dir, blog_name)
  scraper = TumblrScraper::BlogJsonScraper.new(**credentials)
  scraper.scrape_blog(blog_name, blog_dir)
end




if ARGV[0] && (''!=ARGV[0])
  scrape_blog(ARGV[0])
end