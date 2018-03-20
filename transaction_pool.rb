require_relative 'transaction'
require 'deep_clone'

$transaction_pool = []

def get_transaction_pool
  DeepClone.clone($transaction_pool)
end

def is_valid_tx_for_pool?(tx, transaction_pool)
  tx_pool_ins = transaction_pool
    .map { |tx| tx.tx_ins }
    .flatten(1)

  tx.tx_ins.each do |tx_in|
    ret = tx_pool_ins.find { |tx_pool_in| tx_pool_in.tx_out_index == tx_in.tx_out_index && tx_pool_in.tx_out_id == tx_in.tx_out_id }
    if ret
      pp 'txIn already found in the txPool'
      return false
    end
  end

  true
end

def add_to_transaction_pool(tx, unspent_tx_outs)
  unless is_transaction_valid?(tx, unspent_tx_outs)
    throw Exception.new('Trying to add invalid tx to pool')
  end

  unless is_valid_tx_for_pool?(tx, $transaction_pool)
    throw Exception.new('Trying to add invalid tx to pool')
  end

  pp 'adding to txPool: %s' + tx.to_json
  $transaction_pool.push(tx)
end

def has_tx_in?(tx_in, unspent_tx_outs)
  res = unspent_tx_outs.find do |utxo|
    utxo.tx_out_id == tx_in.tx_out_id && utxo.tx_out_index == tx_in.tx_out_index
  end

  res != nil
end

def update_transaction_pool(unspent_tx_outs)
  invalid_txs = []
  $transaction_pool.each do |tx|
    tx.tx_ins.each do |tx_in|
      unless has_tx_in?(tx_in, unspent_tx_outs)
        invalid_txs.push(tx)
        break
      end
    end
  end

  if invalid_txs.length > 0
    pp 'removing the following transactions from txPool: ' + invalid_txs.to_json
    invalid_txs.each { |tx| $transaction_pool.delete(tx) }
  end
end

