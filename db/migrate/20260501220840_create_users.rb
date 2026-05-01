# SQLite: tipo uuid nativo não é dumpado em schema.rb (Rails 8.1).
# PK string 36 chars + SecureRandom.uuid no model = contrato UUID estável na API.
class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: false do |t|
      t.string :id, limit: 36, null: false, primary_key: true
      t.string :name, null: false
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :token

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :token, unique: true, where: "token IS NOT NULL"
  end
end
