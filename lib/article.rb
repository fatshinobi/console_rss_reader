require './lib/db_model'

class Article < DbModel
  def self.count_for_channel(db, channel_id)
    db[:articles].count(by_channel_template(channel_id))
  end

  def self.by_channel(db, channel_id)
    db[:articles].find(by_channel_template(channel_id))
  end

  def self.by_channel_template(channel_id)
    {channel_id: BSON::ObjectId(channel_id), is_read: 0}
  end

  def self.mark_as_read(db, article_id)
    db[:articles].update_one({ _id: BSON::ObjectId(article_id) }, '$set' => { is_read: 1 })
  end

  def self.mark_as_read_for_channel(db, channel_id)
    db[:articles].update_many({ channel_id: BSON::ObjectId(channel_id), is_read: 0 }, '$set' => { is_read: 1 })
  end

  def self.remove_by_channel(db, channel_id)
    db[:articles].delete_many(channel_id: BSON::ObjectId(channel_id))
  end

  def initialize(params)
    @title = params[:title]
    @pub_date = params[:pub_date]
    @description = params[:description]
    @uri_link = params[:uri_link]
    @is_read = params[:is_read]
  end

  def save(db, channel_id)
    return if db[:articles].find({ uri_link: @uri_link }).first
    doc = { 
      _id: BSON::ObjectId.new,
      channel_id: channel_id,
    }.merge(prepare_document)

    db[:articles].insert_one doc
  end
end