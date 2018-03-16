require 'ecdsa'

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

def get_transaction_id(transaction)
  tx_in_content = transaction.tx_ins
    .map { |tx_in| tx_in.tx_out_id.to_s + tx_in.tx_out_index }
    .reduce(:+)

  tx_out_content = transaction.tx_outs
    .map { |tx_out| tx_out.address.to_s + tx_out.amount }
    .reduce(:+)

  Digest::SHA256.hexdigest(tx_in_content + tx_out_content).to_s
end

def is_tx_in_valid?(tx_in, transaction, unspent_tx_outs)
  referenced_tx_out = unspent_tx_outs.find { |utxo| => utxo.tx_out_id == tx_in.tx_out_id && utxo.tx_out_index == tx_in.tx_out_index}
  unless referenced_tx_out
    pp 'referenced txOut not found: ' + tx_in.to_json
  end

  address = referenced_tx_out.address

  public_key = ECDSA::Format::PointOctetString.decode(public_key_string, [address].pack('H*'))
  ECDSA.valid_signature?(public_key, transaction.id, tx_in.signature)
end

def get_tx_in_amount(tx_in, unspent_tx_outs)
  find_unspent_tx_out(tx_in.tx_out_id, tx_in.tx_out_index, unspent_tx_outs).amount
end

def find_unspent_tx_out(transaction, index, unspent_tx_outs)
  unspent_tx_outs.find { |utxo| utxo.tx_out_id == transaction.id && utxo.tx_out_index == index }
end

def is_transaction_valid?(transaction, unspent_tx_outs)
  if get_transaction_id(transaction) != transaction.id
    pp 'invalid tx id: ' + transaction.id
    return false
  end

  has_valid_tx_ins = transaction.tx_ins
    .map { |tx_in| is_tx_in_valid?(tx_in, transaction, unspent_tx_outs) }
    .reduce(:&)

  unless has_valid_tx_ins
    pp 'some of the txIns are invalid in tx: ' + transaction.id
    return false
  end

  total_tx_in_values = transaction.tx_ins
    .map { |tx_in| get_tx_in_amount(tx_in, unspent_tx_outs) }
    .reduce(:+)

  total_tx_out_values = transaction.tx_outs
    .map { |tx_out| tx_out.amount }
    .reduce(:+)

  if total_tx_in_values != total_tx_out_values
    pp 'totalTxOutValues != totalTxInValues ' + transaction.id
    return false
  end

  true
end

def sign_tx_in(transaction, tx_in_index, private_key, unspent_tx_outs)
  tx_in = transaction.tx_ins[tx_in_index]

  data_to_sign = transaction.id
  referenced_unspent_tx_out = find_unspent_tx_out(tx_in.tx_out_id, tx_in.tx_out_index, unspent_tx_outs)

  unless referenced_unspent_tx_out
    pp 'could not find referenced txOut'
    # TODO
  end

  referenced_address = referenced_unspent_tx_out.address

  public_key = ECDSA::Group::Secp256k1.generator.multiply_by_scalar(private_key)
  public_key_string = ECDSA::Format::PointOctetString.encode(public_key, compression: true).unpack('H*')[0]

  unless public_key_string == referenced_address
    pp 'trying to sign an input with private key that does not match the address that is referenced in txIn'
  end

  signature = nil
  while signature.nil?
    temp_key = 1 + SecureRandom.random_number(group.order - 1)
    signature = ECDSA.sign(ECDSA::Group::Secp256k1, private_key, data_to_sign, temp_key)
  end

  ECDSA::Format::SignatureDerString.encode(signature).unpack('H*')[0]
end

def update_unspent_tx_outs(new_transactions, unspent_tx_outs)
  new_unspent_tx_outs = new_transactions
    .map { |t|
      t.tx_outs.each_with_index.map { |tx_out, index| UnspentTxOut.new(t.id, index, tx_out.address, tx_out.amount) }
    }
    .reduce(:+)

  consumed_tx_outs = new_transactions
    .map { |t| t.tx_ins }
    .reduce(+)
    .map { |tx_in| UnspentTxOut.new(tx_in.tx_out_id, tx_in.tx_out_index, '', 0) }

  unspent_tx_outs
      .select { |utxo| !find_unspent_tx_out(utxo.tx_out_id, utxo.tx_out_index, consumed_tx_outs) }
      + new_unspent_tx_outs
end


