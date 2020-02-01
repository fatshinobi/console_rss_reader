#!/usr/bin/env ruby

require 'rss'
require 'open-uri'
require 'cli/ui'
require 'byebug'
require 'mongo'

require './lib/channel'
require './lib/article'

Mongo::Logger.logger.level = ::Logger::FATAL
db_client = Mongo::Client.new([ '127.0.0.1:27017' ], :database => 'console_rss_reader')

def message_and_return(mess)
  puts mess
  false
end

def parse_channel(answer)
  command = answer.split(' ')
  return message_and_return('Must be url') if command.size != 2
  channel_url = command[1]
  return message_and_return('Url is not vald') unless (channel_url =~ URI::regexp)
  channel_url
end

def add_channel(url, db_client)
  chnl = Channel.new(url, db_client)
  chnl.download_channel
  chnl_id = chnl.save db_client
  puts "Channel was created with id=#{chnl_id}"
end

def show_channels(db_client)
  #CLI::UI::StdoutRouter.enable
  Channel.all(db_client).each do |chnl|
    CLI::UI::Frame.open("Channel #{chnl[:_id]}", color: :magenta ) do
      puts CLI::UI.fmt "{{green:#{chnl[:url]}}}"
      puts CLI::UI.fmt "#{chnl[:title]} {{yellow:{{*}}#{Article.count_for_channel(db_client, chnl[:_id])}}}"
    end
  end
end

def parse_channel_id(answer)
  parse_id answer, 'cahnnel'
end

def parse_article_id(answer)
  parse_id answer, 'article'
end

def parse_id(answer, id_type)
  command = answer.split(' ')
  return message_and_return("Must be #{id_type.downcase} id") if command.size != 2
  id_val = command[1]
  return message_and_return("#{id_type.capitalize} id is not vald") unless BSON::ObjectId.legal?(id_val)
  id_val
end

def show_articles(channel_id, db)
  CLI::UI::StdoutRouter.enable
  Article.by_channel(db, channel_id).each do |article|
    CLI::UI::Frame.open("Article #{article[:_id]}", color: :magenta ) do
      puts CLI::UI.fmt "(#{article[:pub_date].strftime('%F')}) {{green:#{article[:title]}}}"
      #+ CLI::UI.fmt "{{}"
      descr_value = article[:description] ? article[:description].gsub(/<\/?[^>]*>/, '').gsub(/\n\n+/, "\n").gsub(/^\n|\n$/, '') : ''
      puts descr_value
      puts article[:uri_link]
    end
  end
end

def mark_as_read(article_id, db)
  Article.mark_as_read(db, article_id)
end

def mark_articles_as_read(channel_id, db)
  Article.mark_as_read_for_channel(db, channel_id)
end

def delete_channel(channel_id, db)
  Article.remove_by_channel(db, channel_id)
  Channel.remove(db, channel_id)
end

def check_new_articles(db)
  Channel.all(db).each do |chnl_rec|
    chnl = Channel.new chnl_rec[:url], db
    chnl.download_channel
    chnl.articles.each { |article| article.save(db, chnl_rec[:_id]) }
  end
end

CLI::UI::StdoutRouter.enable

CLI::UI::Spinner.spin("New articles downloading") do
  check_new_articles db_client
end

loop do
  answer = CLI::UI.ask('c - channels | a(channel id) - articles | r(article id) - mark as read | ra(channel id) - mark all | ac(url) - add channel | d(channel id) - delete channel | q - quit')
  parse_answer = nil
  case
  when answer =~ /^ac|Ac|AC/
    add_channel(parse_answer, db_client) if (parse_answer = parse_channel(answer))
  when answer.downcase == 'c'
    show_channels(db_client)
  when answer =~ /^a|A/
    show_articles(parse_answer, db_client) if (parse_answer = parse_channel_id(answer))
  when answer =~ /^ra|Ra|RA/
    mark_articles_as_read(parse_answer, db_client) if (parse_answer = parse_channel_id(answer))
  when answer =~ /^r|R/
    mark_as_read(parse_answer, db_client) if (parse_answer = parse_article_id(answer))
  when answer =~ /^d|D/
    delete_channel(parse_answer, db_client) if (parse_answer = parse_channel_id(answer))
  when answer =~/^Q|q/
    db_client.close
    break
  else
    puts 'nop'
  end
end


