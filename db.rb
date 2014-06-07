require 'active_record'
require 'sqlite3'

ActiveRecord::Base.establish_connection(
    :adapter => 'sqlite3',
    :database => 'irc.db',
    :pool => 100
)

unless File.exist?('irc.db')
  ActiveRecord::Schema.define do
    create_table :logs do |table|
      table.column :chan, :string
      table.column :user, :string
      table.column :message, :string
      table.column :time, :string
    end
    create_table :commands do |table|
      table.column :command, :string
    end
    create_table :locations do |table|
      table.column :user, :string
      table.column :location, :string
    end
  end
end

class Log < ActiveRecord::Base
end

class Command < ActiveRecord::Base
end

class Location < ActiveRecord::Base
end