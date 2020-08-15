Tumblr JSON Scraper
-------------------

A small script that saves a given Tumblr blog to JSON format.

## How To Use

These instructions assume that you have Ruby and Bundler installed and know a little about how to use them.

1) To use Tumblr API V2, you'll need to register an application at <https://www.tumblr.com/oauth/apps>.

2) Once you've done that, rename the `_env` file in this directory to `.env`.

3) In `.env`, change the `CONSUMER_KEY=` line to that app you just registered's "OAuth Consumer Key". Change the `CONSUMER_SECRET=` lines to your app's "secret key". (You can ignore the `OAUTH_TOKEN` and `OAUTH_TOKEN_SECRET` lines.)

4) By default, the script will save scraped blogs to:

    {your home directory}/Downloads/Tumblr

You can change this in `.env` by uncommenting the `OUTPUT_DIRECTORY=` line and entering the directory you want.

5) In the console, run the following command to install the dependencies:

```bash
bundle install
```

6) Finally, to scrape a blog, run the following command in the console:

```bash
bundle exec ruby scrape_blog.rb BLOG_NAME_GOES_HERE
```