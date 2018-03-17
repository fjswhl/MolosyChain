require 'ecdsa'
require 'pp'
require_relative 'transaction'

PRIVATE_KEY_LOCATION = __dir__ + '/' + 'private_key'

def get_private_from_wallet
  File.read(PRIVATE_KEY_LOCATION).to_i
end

def get_public_from_wallet
  private_key = get_private_from_wallet
  get_public_key_from_private(private_key)
end

def get_public_key_from_private(private_key)
  public_key = ECDSA::Group::Secp256k1.generator.multiply_by_scalar(private_key)
  ECDSA::Format::PointOctetString.encode(public_key).unpack('H*')[0]
end

def generate_private_key
  private_key = 1 + SecureRandom.random_number(ECDSA::Group::Secp256k1.order - 1)
  private_key.to_s(16)
end

def init_wallet
  if File.exist?(PRIVATE_KEY_LOCATION)
    return
  end

  new_private_key = generate_private_key
  a = __dir__ + PRIVATE_KEY_LOCATION

  File.open(PRIVATE_KEY_LOCATION, 'w') do |file|
    file.write(new_private_key)
  end

  pp 'new wallet with private key created'
end

def get_balance(address, unspent_tx_outs)
  unspent_tx_outs
    .select { |utxo| utxo.address == address }
    .map { |utxo| utxo.amount }
    .reduce(:+)
end

def find_tx_outs_for_amount(amount, my_unspent_tx_outs)
  current_amount = 0
  included_unspent_tx_outs = []

  my_unspent_tx_outs.each do |utxo|
    included_unspent_tx_outs.push(utxo)
    current_amount = current_amount + utxo.amount
    if current_amount >= amount
      left_over_amount = current_amount - amount
      return [included_unspent_tx_outs, left_over_amount]
    end
  end

  throw Exception.new('not enough coins to send transacton')
end

def create_tx_outs(receiver_address, my_address, amount, left_over_amount)
  tx_out1 = TxOut.new(receiver_address, amount)
  if left_over_amount == 0
    return [tx_out1]
  else
    tx_out2 = TxOut.new(my_address, left_over_amount)
    return [tx_out1, tx_out2]
  end
end

def create_transaction(receiver_address, amount, private_key, unspent_tx_outs)
  my_address = get_public_key_from_private(private_key)
  my_unspent_tx_outs = unspent_tx_outs.select { |utxo| utxo.address == my_address }

  find_res = find_tx_outs_for_amount(amount, my_unspent_tx_outs)
  included_unspent_tx_outs = find_res[0]
  left_over_amount = find_res[1]

  unsigned_tx_ins = included_unspent_tx_outs.map do |utxo|
    tx_in = TxIn.new
    tx_in.tx_out_id = utxo.tx_out_id
    tx_in.tx_out_index = utxo.tx_out_index
    return tx_in
  end

  tx = Transaction.new
  tx.tx_ins = unsigned_tx_ins
  tx.tx_outs = create_tx_outs(receiver_address, my_address, amount, left_over_amount)
  tx.id = get_transaction_id(tx)

  tx.tx_ins = tx.tx_ins.each_with_index.map do |tx_in, index|
    tx_in.signature = sign_tx_in(tx, index, private_key, unspent_tx_outs)
    return tx_in
  end

  tx
end

init_wallet