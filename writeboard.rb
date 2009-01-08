require 'rubygems'
require 'hpricot'
require 'fileutils'

# Example of use

# wb = Basecamp::Writeboard.new(
#   :url        => 'http://bigcorp.updatelog.com/W1234567',
#   :username   => 'user',
#   :password   => 'pass',
#   :cookie_jar => '/tmp/foo',
#   :use_ssl    => true
# )
# 
# puts wb.contents

module Basecamp
  class Writeboard
    def initialize(options)
      raise ArgumentError, 'need a writeboard url'    unless options[:url]
      raise ArgumentError, 'need a basecamp username' unless options[:username]
      raise ArgumentError, 'need a basecamp password' unless options[:password]
      raise ArgumentError, 'need a cookies file'      unless options[:cookie_jar]
      
      @url            = options[:url]
      @username       = options[:username]
      @password       = options[:password]
      @cookie_jar     = options[:cookie_jar]
      @ssl            = options[:use_ssl] || false
      @domain         = @url.split(/\/+/)[1]
    end
    
    def contents
      text = fetch_contents
      clear_cookies
      text
    end
    
    private
  
    def fetch_contents
      # Prime the cookie jar: log in.
      basecamp_login      = `curl -s -c #{@cookie_jar} -b #{@cookie_jar} -d "user_name=#{@username}&password=#{@password}" -L http#{'s' if @ssl}://#{@domain}/login/authenticate`
  
      # Fetch the contents of the writeboard redirect page
      writeboard_redir    = `curl -s -c #{@cookie_jar} -b #{@cookie_jar} -L #{@url}`
  
      # Simulate the javascripted login to the writeboard site
      redir_form          = Hpricot(writeboard_redir).search('form').first
      writeboard_url      = redir_form['action'].gsub(/\/login$/, '')
      writeboard_author   = ENV['USER'] || 'Tim'
      writeboard_password = redir_form.search("input[@name='password']").first['value']
  
      writeboard_login    = `curl -s -c #{@cookie_jar} -b #{@cookie_jar} -d "author_name=#{writeboard_author}&password=#{writeboard_password}" -L #{redir_form['action']}`
  
      # Now we can get the contents of the writeboard's page, which contains a link to the text export
      writeboard_page     = Hpricot(`curl -s -c #{@cookie_jar} -b #{@cookie_jar} -L #{writeboard_url}`)
  
      export_link         = 'http://123.writeboard.com' + writeboard_page.search("a[@href*='?format=txt']").first['href']
  
      # Finally, grab and return the text export
      `curl -s -c #{@cookie_jar} -b #{@cookie_jar} #{export_link}`
    end
    
    def clear_cookies
      FileUtils.rm_f @cookie_jar
    end
  end
end