require 'pp'
require 'csv'
require 'json'

class Speaker 
  attr_reader :name
  attr_reader :bio
  attr_reader :email, :twitter
  attr_reader :avatar_url
  
end

class Session  
  
  NON_SESSIONS = ["Setup", "Open Doors", "Lunch", "Cleanup", "End of Day"]
  
  attr_reader :speakers
  attr_reader :location
  attr_reader :begin, :end
  attr_reader :title, :abstract
end

class Location
  attr_reader :name
  
  def identifier
    return @name
  end
  
  def initialize(name)
    @name = name
  end
end

# speakers_csv = CSV.new(File.expand_path(ARGV[-2]), {headers: true})
sessions_csv = CSV.new(File.read(File.expand_path(ARGV[-1])), {headers: false})

locations_per_col = []
day_per_col = []
session_per_col = []
sessions_per_day_and_location = {}

sessions_csv.each_with_index do |row,index|
  

  if index == 0 # Day
    last_day = nil
    row.each_with_index do |day, index|
      if index > 1 && !day.nil? && day.size > 0
        last_day = day
      end

      day_per_col[index] = last_day
    end
    
  elsif index == 1 # Location
    last_location = nil
    row.each_with_index do |location, index|
      if index > 1 && !location.nil? && location.size > 0
        last_location = location
      end

      locations_per_col[index] = last_location
    end
  elsif !row[0].nil? && row[0] =~ / (AM|PM)/
    time = row[0]
    
    last_sessions = []
    row.each_with_index do |speaker_for_session, index|
      next unless locations_per_col.count > index
      next unless index > 1
      location = locations_per_col[index]
      day = day_per_col[index]

      if !speaker_for_session.nil? && speaker_for_session.size > 0 
        key = [day, location]
        sessions_per_day_and_location[key] ||= []
        sessions_per_day_and_location[key] << { day: day,
                                                time: time,
                                                location: location,
                                                speaker: speaker_for_session }
      end
      
      # puts "#{day}, #{time}, #{location}" #": #{speaker_for_session} as #{location}"
    end
    
  end
  
end



# pp day_per_col
# pp locations_per_col
pp sessions_per_day_and_location