require 'nokogiri'
require 'open-uri'
require 'erb'
require 'functions_framework'

def format_username_list(usernames)
  if usernames.size == 1
    format_username(usernames[0])
  else
    formatted_names = usernames.map { |n| format_username(n) }
    oxford_comma = usernames.size > 2 ? ', ' : ' '
    formatted_names[0..-2].join(', ') + oxford_comma + 'and ' + formatted_names[-1]
  end
end

def format_username(username)
  "<lj user=#{username} site=ao3.org/>"
end

FunctionsFramework.http 'parse' do |request|
  if request.options?
    # Allows GET requests from any origin with the Content-Type
    # header and caches preflight response for an 3600s
    headers = {
      'Access-Control-Allow-Origin' => '*',
      'Access-Control-Allow-Methods' => '*',
      'Access-Control-Allow-Headers' => 'Content-Type',
      'Access-Control-Max-Age' => '3600'
    }
    [204, headers, []]
  else
    # Set CORS headers for the main request
    headers = {
      'Access-Control-Allow-Origin' => '*'
    }

    params = JSON.parse(request.body.read)

    puts params
    text_source = params['text_source']
    text_url = params['text_url']
    text_html = if text_source.empty?
                  URI.open(text_url + '?view_adult=true')
                else
                  text_source
                end

    doc = Nokogiri::HTML(text_html)
    title = doc.css('.title.heading').text.strip
    fandoms = doc.css('.fandom.tags a.tag').map { |tag| tag.text }.join(', ')
    summary = doc.css('.summary .userstuff').inner_html.strip
    summary_without_p_tags = summary.gsub('<p>', '').gsub('</p>', '')

    writers = format_username_list(params['writers'].split(',').map { |w| w.strip })
    performers = format_username_list(params['performers'].split(',').map { |w| w.strip })

    audio_url = params['audio_url']
    title_section = if audio_url.empty?
                      "<a href='#{text_url}'>#{title}</a>"
                    else
                      "#{title} [<a href='#{text_url}'>text</a>, <a href='#{audio_url}'>audio</a>]"
                    end

    content = <<~EOF
      <strong>#{title_section}  (#{fandoms})</strong><br/>written by #{writers}, performed by #{performers}<br /><strong>Summary:</strong> #{summary_without_p_tags}
    EOF

    [200, headers, [content]]
  end
end
