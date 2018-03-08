class TxOut
  attr_accessor :address,
                :amount

  def initialize(address, amount)
    @address = address
    @amount = amount
  end
end

class TxIn
  attr_accessor :tx_out_id,
                :tx_out_index,
                :signature
end

class Transaction
  attr_accessor :id,
                :tx_ins,
                :tx_outs
end

class UnspentTxOut
  attr_accessor :tx_out_id,
                :tx_out_index,
                :address,
                :amount

  def initialize(tx_out_id, tx_out_index, address, amount)
    @tx_out_id = tx_out_id
    @tx_out_index = tx_out_index
    @address = address
    @amount = amount
  end
end