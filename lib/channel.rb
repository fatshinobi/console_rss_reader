require './lib/db_model'

class Channel < DbModel
  attr_reader :articles

  RSS_FEED_FIELDS = {title: "channel.title", articles: 'items', article_title: 'item.title', article_date: 'pubDate', article_uri_link: 'guid', article_description: 'self.description', article_categories: 'self.categories'}
  ATOM_FEED_FIELDS = {title: "title.content", articles: 'entries', article_title: 'title.content', article_date: 'updated.content', article_description: 'nil', article_categories: 'category.label', article_uri_link: 'link.href'}

  def self.all(db)
    db[:channels].find
  end

  def initialize(url, db)
    @url = url
    @articles = []

    db_record = db[:channels].find({ url: @url }).first
    if db_record
      @title = db_record[:title]
    end
  end

  def save(db)
    doc = { 
      _id: BSON::ObjectId.new,
    }.merge(prepare_document([:@articles]))

    db[:channels].insert_one doc 

    articles.each { |article| article.save(db, doc[:_id]) }
    doc[:_id]
  end

  def self.remove(db, channel_id)
    db[:channels].delete_one(_id: BSON::ObjectId(channel_id))
  end

  def download_channel
    open(@url) do |rss|
      feed = RSS::Parser.parse(rss, false)
      feed.class == RSS::Atom::Feed ? download_atom_channel(feed) : download_rss_channel(feed)
    end
  end

  def download_atom_channel(feed)
    parse_channel feed, ATOM_FEED_FIELDS
  end

  def download_rss_channel(feed)
    parse_channel feed, RSS_FEED_FIELDS
  end

  def parse_channel(feed, fields_matching)
    @title ||= feed.instance_eval(fields_matching[:title])
    feed.instance_eval(fields_matching[:articles]).each do |item|
      
      categories = item.instance_eval(fields_matching[:article_categories])
      categories_val = categories.is_a?(Array) ? item.categories.map{|cat| cat.content}.join(', ') : categories
      
      item_url = item.instance_eval(fields_matching[:article_uri_link])
      url_value = item_url.is_a?(String) ? item_url : item_url.content

      description = item.instance_eval(fields_matching[:article_description])
      description = description[0..1024] if description

      book = Article.new(
        title: item.instance_eval(fields_matching[:article_title]),
        pub_date: item.instance_eval(fields_matching[:article_date]),
        description: description,
        uri_link: url_value,
        catagories: categories,
        is_read: 0
      )
      
      @articles << book
    end
  end
end