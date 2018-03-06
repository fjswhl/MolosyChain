require 'digest'

class Block
  attr_reader :index,
              :previous_hash,
              :timestamp,
              :data,
              :hash

  def initialize(index, previous_hash, timestamp, data, hash)
    @index = index
    @previous_hash = previous_hash
    @timestamp = timestamp
    @data = data
    @hash = hash
  end

  def self.from_dic(dic)
    Block.new(dic['index'], dic['previous_hash'], dic['timestamp'], dic['data'], dic['hash'])
  end

  def self.genesis_block
    Block.new(0, "0", 1465154705, "my genesis block!!", "816534932c2b7154836da6afc367695e6337db8a921823784c14378abed4f7d7")
  end

  def self.calculate_hash(index, previous_hash, timestamp, data)
    Digest::SHA256.hexdigest(
        index.to_s +
            previous_hash.to_s +
            timestamp.to_s +
            data.to_s
    ).to_s
  end

  def to_json(*args)
    {
        :index => @index,
        :previous_hash => @previous_hash,
        :timestamp => @timestamp,
        :data => @data,
        :hash => @hash
    }.to_json(*args)
  end

  def block_hash
    Block.calculate_hash(@index, @previous_hash, @timestamp, @data)
  end

  def is_valid_next_block?(previous_block)
    if previous_block.index + 1 != @index
      pp 'invalid index'
      return false
    elsif previous_block.hash != @previous_hash
      pp 'invalid previoushash'
      return false
    elsif block_hash != @hash
      pp 'invalid hash: ' + block_hash + ' ' + @hash
      return false
    else
      return true
    end
  end
end